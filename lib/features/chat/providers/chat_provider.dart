import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:location/location.dart' as loc;
import '../../../data/models/call_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
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
    _initLocalFirst();
  }

  /// Inisialisasi local-first: tampilkan snapshot SQLite lokal seketika (0 ms)
  /// lalu lakukan sinkronisasi data remote di latar belakang secara hening (stale-while-revalidate).
  Future<void> _initLocalFirst() async {
    try {
      final cached = await _chatRepository.getCachedRooms();
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }
    } catch (_) {}
    await refreshRooms(forceLoading: !state.hasValue);
  }

  /// Memuat snapshot daftar chat rooms dari cache SQLite lokal secara instan (0-5 ms, zero network)
  /// dan secara opsional memicu sinkronisasi data remote di latar belakang (stale-while-revalidate).
  Future<void> reloadFromLocalCache({bool syncRemoteInBackground = true}) async {
    try {
      final cached = await _chatRepository.getCachedRooms();
      state = AsyncValue.data(cached);
    } catch (_) {}

    if (syncRemoteInBackground) {
      unawaited(refreshRooms(forceLoading: false));
    }
  }

  Future<void> refreshRooms({bool forceLoading = false}) async {
    try {
      if (forceLoading || !state.hasValue) {
        state = const AsyncValue.loading();
      }
      final rooms = await _chatRepository.getRooms();
      state = AsyncValue.data(rooms);

      // Migrasi transparan legacy: petakan hiddenRoomIds ke hiddenContactUserIds jika ada
      final roomToUserIdMap = <String, String>{};
      for (final r in rooms) {
        final rId = r['id'] as String?;
        final uId = r['otherUserId'] as String?;
        if (rId != null && uId != null && uId.isNotEmpty) {
          roomToUserIdMap[rId] = uId;
        }
      }
      if (roomToUserIdMap.isNotEmpty) {
        unawaited(PrivateContactRepository().migrateLegacyHiddenRoomsToContacts(roomToUserIdMap));
      }
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

  /// Memutasi daftar room di memori secara lokal & instan (0 ms) saat pesan baru masuk atau terkirim.
  /// Memindahkan room terkait ke urutan paling atas (index 0), memperbarui cuplikan teks,
  /// timestamp, dan menambah unread count jika pengirim adalah pihak lawan dan user tidak
  /// sedang berada di dalam room tersebut.
  void updateLastMessageLocally({
    required String roomId,
    required String previewText,
    required DateTime timestamp,
    required bool isFromOtherUser,
    required bool isCurrentlyInRoom,
  }) {
    final currentList = state.value;
    if (currentList == null) return;

    final index = currentList.indexWhere((r) => r['id'] == roomId);
    if (index == -1) {
      // Room baru yang belum ada di daftar lokal: muat dari backend
      refreshRooms();
      return;
    }

    final existingRoom = currentList[index];
    final currentUnread = (existingRoom['unreadCount'] as num?)?.toInt() ?? 0;
    final newUnread = (isFromOtherUser && !isCurrentlyInRoom)
        ? currentUnread + 1
        : currentUnread;

    final updatedRoom = Map<String, dynamic>.from(existingRoom);
    updatedRoom['lastMessage'] = previewText;
    updatedRoom['timestamp'] = timestamp;
    updatedRoom['unreadCount'] = newUnread;

    final newList = List<Map<String, dynamic>>.from(currentList);
    newList.removeAt(index);
    newList.insert(0, updatedRoom);

    state = AsyncValue.data(newList);
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
  final reconnectController = ref.watch(
    _chatReconnectControllerProvider(roomId),
  );
  return repo.streamMessages(
    roomId,
    onReconnectChange: (reconnecting) {
      if (!reconnectController.isClosed) {
        reconnectController.add(reconnecting);
      }
    },
  );
});

/// Sinyal non-blocking bahwa stream pesan sedang mencoba menyambung ulang
/// setelah gangguan Realtime sesaat (retry+backoff berjalan di repository).
final chatReconnectingProvider = StreamProvider.family<bool, String>((
  ref,
  roomId,
) {
  final controller = ref.watch(_chatReconnectControllerProvider(roomId));
  return controller.stream;
});

/// Stream riwayat panggilan pada room tertentu secara realtime
final chatCallsProvider = StreamProvider.family<List<CallModel>, String>((
  ref,
  roomId,
) {
  final repo = ref.watch(callRepositoryProvider);
  return repo.streamCalls(roomId);
});

// ─────────────────────────────────────────
// Optimistic Pending Messages (per room)
// ─────────────────────────────────────────
class PendingMessagesNotifier extends StateNotifier<List<Message>> {
  PendingMessagesNotifier() : super(const []);

  void addPending(Message message) {
    state = [...state, message];
  }

  void removePending(String tempId) {
    state = state.where((m) => m.id != tempId).toList();
  }

  void clearPending() {
    state = const [];
  }
}

final pendingMessagesProvider =
    StateNotifierProvider.family<
      PendingMessagesNotifier,
      List<Message>,
      String
    >((ref, roomId) => PendingMessagesNotifier());

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
  Timer? _subscribeDebounceTimer;
  Timer? _debounceTimer;
  Timer? _hideTimer;

  TypingNotifier(this._ref, this._roomId) : super(false) {
    // P2: Jeda langganan 300 ms agar perpindahan cepat antar-room tidak
    // membuat dangling WebSocket handshake atau lonjakan koneksi ke Supabase
    _subscribeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _subscribe();
      }
    });
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
              payload: {'sender_id': currentUserId, 'is_typing': true},
            );
          }
        } else {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            _channel?.sendBroadcastMessage(
              event: 'typing',
              payload: {'sender_id': currentUserId, 'is_typing': false},
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscribeDebounceTimer?.cancel();
    _debounceTimer?.cancel();
    _hideTimer?.cancel();
    try {
      _channel?.unsubscribe();
    } catch (_) {}
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

  Future<Message> sendMessage(
    String roomId,
    String content, {
    String? mediaUrl,
    MessageType type = MessageType.text,
    bool isViewOnce = false,
    String? replyToId,
    int? autoDeleteHours,
    DateTime? scheduledWipeTargetAt,
    bool isGroup = false,
  }) async {
    DateTime? autoDeleteAt;
    if (scheduledWipeTargetAt != null &&
        scheduledWipeTargetAt.isAfter(DateTime.now())) {
      autoDeleteAt = scheduledWipeTargetAt;
    } else if (autoDeleteHours != null && autoDeleteHours > 0) {
      autoDeleteAt = DateTime.now().add(Duration(hours: autoDeleteHours));
    }

    final sentMessage = await _chatRepository.sendMessage(
      roomId,
      content,
      mediaUrl: mediaUrl,
      type: type,
      isViewOnce: isViewOnce,
      replyToId: replyToId,
      autoDeleteAt: autoDeleteAt,
      isGroup: isGroup,
    );

    _chatRepository.updateLastSeen();
    return sentMessage;
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

  Future<void> deleteMessageForEveryone(String messageId, {String? roomId}) async {
    await _chatRepository.deleteMessageForEveryone(messageId, roomId: roomId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> hideMessageForMe(String messageId, {String? roomId}) async {
    await _chatRepository.hideMessageForMe(messageId, roomId: roomId);
    if (roomId != null) {
      _ref.invalidate(chatMessagesProvider(roomId));
    }
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
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
    _liveLocationSub = LocationService.getLocationStream().listen((data) async {
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
          await _chatRepository.updateMessageContent(
            message.id,
            formatContent(lat, lng),
          );
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
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> updateLastSeen() async {
    await _chatRepository.updateLastSeen();
  }

  bool canForward(Message message, {bool forwardingProtectionActive = false}) {
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
    _ref.invalidate(chatCallsProvider(roomId));
    _ref.invalidate(chatMessagesProvider(roomId));
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> deleteChat(String roomId) async {
    await _chatRepository.deleteChat(roomId);
    _ref.invalidate(chatCallsProvider(roomId));
    _ref.invalidate(chatMessagesProvider(roomId));
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

class PaginatedContactsState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String searchQuery;
  final int page;

  const PaginatedContactsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.searchQuery = '',
    this.page = 0,
  });

  PaginatedContactsState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? searchQuery,
    int? page,
  }) {
    return PaginatedContactsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
    );
  }
}

class PaginatedContactsNotifier extends StateNotifier<PaginatedContactsState> {
  final Ref _ref;
  static const int pageSize = 25;

  PaginatedContactsNotifier(this._ref) : super(const PaginatedContactsState()) {
    loadInitial();
  }

  Future<void> loadInitial({String? query}) async {
    final q = query ?? state.searchQuery;
    state = state.copyWith(isLoading: true, searchQuery: q, page: 0, hasMore: true);

    try {
      final supabase = _ref.read(supabaseServiceProvider);
      final currentUserId = supabase.currentUserId;
      if (currentUserId == null) {
        state = state.copyWith(isLoading: false, items: [], hasMore: false);
        return;
      }

      var queryBuilder = supabase.client
          .from('public_profiles')
          .select('id, username, full_name, display_name, avatar_url')
          .neq('id', currentUserId);

      if (q.trim().isNotEmpty) {
        final filterTerm = '%${q.trim()}%';
        queryBuilder = queryBuilder.or(
          'username.ilike.$filterTerm,full_name.ilike.$filterTerm,display_name.ilike.$filterTerm',
        );
      }

      final resp = await queryBuilder
          .order('created_at', ascending: false)
          .range(0, pageSize - 1);

      final list = (resp as List).cast<Map<String, dynamic>>();
      state = state.copyWith(
        items: list,
        isLoading: false,
        hasMore: list.length >= pageSize,
        page: 1,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final supabase = _ref.read(supabaseServiceProvider);
      final currentUserId = supabase.currentUserId;
      if (currentUserId == null) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final from = state.page * pageSize;
      final to = from + pageSize - 1;

      var queryBuilder = supabase.client
          .from('public_profiles')
          .select('id, username, full_name, display_name, avatar_url')
          .neq('id', currentUserId);

      if (state.searchQuery.trim().isNotEmpty) {
        final filterTerm = '%${state.searchQuery.trim()}%';
        queryBuilder = queryBuilder.or(
          'username.ilike.$filterTerm,full_name.ilike.$filterTerm,display_name.ilike.$filterTerm',
        );
      }

      final resp = await queryBuilder
          .order('created_at', ascending: false)
          .range(from, to);

      final list = (resp as List).cast<Map<String, dynamic>>();
      final combined = [...state.items, ...list];

      state = state.copyWith(
        items: combined,
        isLoadingMore: false,
        hasMore: list.length >= pageSize,
        page: state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void search(String query) {
    loadInitial(query: query);
  }
}

final paginatedContactsProvider =
    StateNotifierProvider<PaginatedContactsNotifier, PaginatedContactsState>((ref) {
  return PaginatedContactsNotifier(ref);
});

final contactsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final paginatedState = ref.watch(paginatedContactsProvider);
  if (paginatedState.items.isNotEmpty) {
    return paginatedState.items;
  }

  final supabase = ref.watch(supabaseServiceProvider);
  final currentUserId = supabase.currentUserId;
  if (currentUserId == null) return [];

  final resp = await supabase.client
      .from('public_profiles')
      .select('id, username, full_name, display_name, avatar_url')
      .neq('id', currentUserId)
      .limit(50);

  return (resp as List).cast<Map<String, dynamic>>();
});
