import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  roomId,
) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.streamMessages(roomId);
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
            _debounceTimer = Timer(const Duration(milliseconds: 1500), () {});
            _channel?.sendBroadcastMessage(
              event: 'typing',
              payload: {
                'sender_id': currentUserId,
                'is_typing': true,
              },
            );
          }
        } else {
          _channel?.sendBroadcastMessage(
            event: 'typing',
            payload: {
              'sender_id': currentUserId,
              'is_typing': false,
            },
          );
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideTimer?.cancel();
    _channel?.unsubscribe();
    _channel = null;
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
  }) async {
    DateTime? autoDeleteAt;
    if (autoDeleteHours != null && autoDeleteHours > 0) {
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
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
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
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    await _chatRepository.reactToMessage(messageId, emoji);
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    await _chatRepository.deleteMessageForEveryone(messageId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> hideMessageForMe(String messageId) async {
    await _chatRepository.hideMessageForMe(messageId);
    // Kita tidak merefresh rooms di sini karena hideMessageForMe hanya menyembunyikan lokal
    // dan stream akan memperbaruinya di chat screen secara otomatis saat listener baru (jika direstart).
    // Tapi untuk memastikan screen update seketika, caller di UI harus menggunakan provider atau refresh lokal.
  }

  Future<void> forwardMessage(Message message, String roomId) async {
    await _chatRepository.sendMessage(
      roomId,
      message.content,
      mediaUrl: message.mediaUrl,
      type: message.type,
    );
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  /// Bagikan lokasi live (sukarela, bukan SOS) selama [durationMinutes].
  /// Memperbarui satu pesan lokasi tiap interval sampai waktu habis.
  Future<String> shareLiveLocation(String roomId, int durationMinutes) async {
    final loc = await LocationService.getCurrentLocation();
    if (loc == null || loc.latitude == null || loc.longitude == null) {
      throw Exception('Lokasi tidak tersedia');
    }

    final start = DateTime.now();
    final end = start.add(Duration(minutes: durationMinutes));

    String formatContent() {
      final remaining = end.difference(DateTime.now());
      final secs = remaining.inSeconds.clamp(0, 9999);
      return 'LIVE:${loc.latitude},${loc.longitude}:$secs';
    }

    final message = await _chatRepository.sendMessage(
      roomId,
      formatContent(),
      type: MessageType.location,
    );

    final subscription = LocationService.getLocationStream().listen((
      data,
    ) async {
      if (DateTime.now().isAfter(end)) return;
      try {
        await _chatRepository.updateMessageContent(message.id, formatContent());
      } catch (_) {}
    });

    // Hentikan share saat waktu habis.
    Timer(Duration(minutes: durationMinutes), () {
      subscription.cancel();
    });

    return message.id;
  }

  Future<void> markRoomRead(String roomId) async {
    await _chatRepository.markRoomRead(roomId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
    _ref.invalidate(otherParticipantLastReadProvider(roomId));
  }

  Future<void> updateLastSeen() async {
    await _chatRepository.updateLastSeen();
  }

  bool canForward(Message message) {
    return _chatRepository.canForwardMessage(message);
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
  return ChatActionsNotifier(repo, ref);
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
