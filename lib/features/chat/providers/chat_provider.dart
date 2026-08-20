import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:location/location.dart' as loc;
import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────
// Repository Provider
// ─────────────────────────────────────────
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ChatRepository(supabaseService);
});

// ─────────────────────────────────────────
// Active Room State
// ─────────────────────────────────────────
final activeRoomIdProvider = StateProvider<String?>((ref) => null);

// ─────────────────────────────────────────
// Chat Rooms List
// ─────────────────────────────────────────
class ChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final ChatRepository _chatRepository;

  ChatRoomsNotifier(this._chatRepository) : super(const AsyncValue.loading()) {
    refreshRooms();
  }

  Future<void> refreshRooms({bool forceLoading = false}) async {
    try {
      if (forceLoading || !state.hasValue) {
        state = const AsyncValue.loading();
      }
      final rooms = await _chatRepository.getRooms();
      state = AsyncValue.data(rooms);
    } catch (e, stack) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<String> getOrCreateRoom(
    String otherUserId,
    String type, {
    bool screenshotEnabled = true,
  }) async {
    final roomId = await _chatRepository.createRoom(
      otherUserId,
      type,
      screenshotProtectionEnabled: screenshotEnabled,
    );
    await refreshRooms();
    return roomId;
  }
}

final chatRoomsProvider =
    StateNotifierProvider<
      ChatRoomsNotifier,
      AsyncValue<List<Map<String, dynamic>>>
    >((ref) {
      final repo = ref.watch(chatRepositoryProvider);
      return ChatRoomsNotifier(repo);
    });

// ─────────────────────────────────────────
// Stream of messages in a room
// ─────────────────────────────────────────

/// Controller broadcast per-room untuk sinyal "Menyambung ulang…" (reconnecting).
/// Dipakai bersama oleh [chatMessagesProvider] (pengirim) dan
/// [chatReconnectingProvider] (penerima) agar tidak ada subscribe kedua.
final _chatReconnectControllerProvider =
    Provider.family<StreamController<bool>, String>((ref, roomId) {
  final controller = StreamController<bool>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  roomId,
) {
  final repo = ref.watch(chatRepositoryProvider);
  final reconnectController = ref.watch(_chatReconnectControllerProvider(roomId));
  return repo.streamMessages(roomId, onReconnectChange: (reconnecting) {
    if (!reconnectController.isClosed) {
      reconnectController.add(reconnecting);
    }
  });
});

/// Sinyal non-blocking bahwa stream pesan sedang mencoba menyambung ulang
/// setelah gangguan Realtime sesaat (retry+backoff berjalan di repository).
final chatReconnectingProvider = StreamProvider.family<bool, String>((ref, roomId) {
  final controller = ref.watch(_chatReconnectControllerProvider(roomId));
  return controller.stream;
});

// ─────────────────────────────────────────
// Read receipts: other participant's last_read_at
// ─────────────────────────────────────────
final otherParticipantLastReadProvider =
    FutureProvider.family<DateTime?, String>((ref, roomId) async {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.getOtherParticipantLastRead(roomId);
    });

// ─────────────────────────────────────────
// Typing indicator state (per room via Realtime Broadcast)
// ─────────────────────────────────────────
class TypingNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final String _roomId;
  RealtimeChannel? _channel;
  Timer? _debounceTimer;
  Timer? _hideTimer;

  TypingNotifier(this._ref, this._roomId) : super(false) {
    _subscribe();
  }

  void _subscribe() {
    try {
      final client = _ref.read(supabaseServiceProvider).client;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return;

      _channel = client.channel('room_typing:$_roomId');
      _channel?.onBroadcast(
        event: 'typing',
        callback: (payload) {
          final senderId = payload['sender_id'] as String?;
          final isTyping = payload['is_typing'] as bool? ?? false;

          // Abaikan sinyal dari diri sendiri (echo broadcast)
          if (senderId == null || senderId == currentUserId) return;

          if (mounted) {
            state = isTyping;
            if (isTyping) {
              _hideTimer?.cancel();
              _hideTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) state = false;
              });
            }
          }
        },
      );
      _channel?.subscribe();
    } catch (_) {}
  }

  /// Mengirim sinyal broadcast pengetikan ke peserta lain di room
  void setTyping(bool typing) {
    try {
      final client = _ref.read(supabaseServiceProvider).client;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId != null && _channel != null) {
        if (typing) {
          if (!(_debounceTimer?.isActive ?? false)) {
            _debounceTimer = Timer(const Duration(milliseconds: 2500), () {});
            _channel?.sendBroadcastMessage(
              event: 'typing',
              payload: {
                'sender_id': currentUserId,
                'is_typing': true,
              },
            );
          }
        } else {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            _channel?.sendBroadcastMessage(
              event: 'typing',
              payload: {
                'sender_id': currentUserId,
                'is_typing': false,
              },
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}

final typingStateProvider =
    StateNotifierProvider.family<TypingNotifier, bool, String>(
  (ref, roomId) => TypingNotifier(ref, roomId),
);

// ─────────────────────────────────────────
// Chat Actions (send, edit, react, delete, mark read)
// ─────────────────────────────────────────
class ChatActionsNotifier {
  final ChatRepository _chatRepository;
  final Ref _ref;

  ChatActionsNotifier(this._chatRepository, this._ref);

  Future<void> sendMessage(
    String roomId,
    String content, {
    String? mediaUrl,
    MessageType type = MessageType.text,
    bool isViewOnce = false,
    String? replyToId,
    int? autoDeleteHours,
    DateTime? scheduledWipeTargetAt,
  }) async {
    DateTime? autoDeleteAt;
    if (scheduledWipeTargetAt != null && scheduledWipeTargetAt.isAfter(DateTime.now())) {
      autoDeleteAt = scheduledWipeTargetAt;
    } else if (autoDeleteHours != null && autoDeleteHours > 0) {
      autoDeleteAt = DateTime.now().add(Duration(hours: autoDeleteHours));
    }

    await _chatRepository.sendMessage(
      roomId,
      content,
      mediaUrl: mediaUrl,
      type: type,
      isViewOnce: isViewOnce,
      replyToId: replyToId,
      autoDeleteAt: autoDeleteAt,
    );

    _chatRepository.updateLastSeen();
  }

  Future<void> markViewOnceOpened(String messageId) async {
    await _chatRepository.markViewOnceOpened(messageId);
  }

  Future<void> editMessage(
    String messageId,
    String newContent, {
    required bool isGuardianRoom,
  }) async {
    if (isGuardianRoom) {
      throw Exception('Tidak dapat mengedit pesan di Chat Guardian');
    }
    await _chatRepository.editMessage(messageId, newContent);
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    await _chatRepository.reactToMessage(messageId, emoji);
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    await _chatRepository.deleteMessageForEveryone(messageId);
  }

  Future<void> hideMessageForMe(String messageId, {String? roomId}) async {
    await _chatRepository.hideMessageForMe(messageId);
    if (roomId != null) {
      _ref.invalidate(chatMessagesProvider(roomId));
    }
  }

  Future<void> forwardMessage(Message message, String roomId) async {
    await _chatRepository.sendMessage(
      roomId,
      message.content,
      mediaUrl: message.mediaUrl,
      type: message.type,
    );
  }

  StreamSubscription<loc.LocationData>? _liveLocationSub;
  Timer? _liveLocationTimer;

  /// Bagikan lokasi live (sukarela, bukan SOS) selama [durationMinutes].
  /// Memperbarui satu pesan lokasi tiap interval sampai waktu habis.
  Future<String> shareLiveLocation(String roomId, int durationMinutes) async {
    // Cancel existing active live location sharing if any
    await stopLiveLocationShare();

    final loc = await LocationService.getCurrentLocation();
    if (loc == null || loc.latitude == null || loc.longitude == null) {
      throw Exception('Lokasi tidak tersedia');
    }

    final start = DateTime.now();
    final end = start.add(Duration(minutes: durationMinutes));

    String formatContent(double lat, double lng) {
      final remaining = end.difference(DateTime.now());
      final secs = remaining.inSeconds.clamp(0, 9999);
      return 'LIVE:$lat,$lng:$secs';
    }

    final message = await _chatRepository.sendMessage(
      roomId,
      formatContent(loc.latitude!, loc.longitude!),
      type: MessageType.location,
    );

    // Throttle: update paling sering setiap 10 detik untuk menghindari
    // overload database dan menghemat baterai.
    DateTime? lastLocUpdate;
    _liveLocationSub = LocationService.getLocationStream().listen((
      data,
    ) async {
      if (DateTime.now().isAfter(end)) {
        await stopLiveLocationShare();
        return;
      }
      // Throttle check
      final now = DateTime.now();
      if (lastLocUpdate != null &&
          now.difference(lastLocUpdate!).inSeconds < 10) {
        return;
      }
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat != null && lng != null) {
        try {
          await _chatRepository.updateMessageContent(message.id, formatContent(lat, lng));
          lastLocUpdate = now;
        } catch (_) {}
      }
    });

    // Hentikan share saat waktu habis.
    _liveLocationTimer = Timer(Duration(minutes: durationMinutes), () {
      stopLiveLocationShare();
    });

    return message.id;
  }

  /// Membatalkan langganan lokasi live secara eksplisit
  Future<void> stopLiveLocationShare() async {
    await _liveLocationSub?.cancel();
    _liveLocationSub = null;
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
  }

  Future<void> markRoomRead(String roomId) async {
    await _chatRepository.markRoomRead(roomId);
    _ref.invalidate(otherParticipantLastReadProvider(roomId));
  }

  Future<void> updateLastSeen() async {
    await _chatRepository.updateLastSeen();
  }

  bool canForward(
    Message message, {
    bool forwardingProtectionActive = false,
  }) {
    return _chatRepository.canForwardMessage(
      message,
      forwardingProtectionActive: forwardingProtectionActive,
    );
  }

  bool canEdit(Message message, {required bool isGuardianRoom}) {
    return _chatRepository.canEditMessage(
      message,
      isGuardianRoom: isGuardianRoom,
    );
  }

  Future<void> clearChatHistory(String roomId) async {
    await _chatRepository.clearChatHistory(roomId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> deleteChat(String roomId) async {
    await _chatRepository.deleteChat(roomId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }
}

final chatActionsProvider = Provider<ChatActionsNotifier>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final notifier = ChatActionsNotifier(repo, ref);
  ref.onDispose(() {
    notifier.stopLiveLocationShare();
  });
  return notifier;
});

final contactsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  final currentUserId = supabase.currentUserId;
  if (currentUserId == null) return [];

  final resp = await supabase.client
      .from('public_profiles')
      .select('id, username, full_name, display_name, avatar_url')
      .neq('id', currentUserId);

  return (resp as List).cast<Map<String, dynamic>>();
});
