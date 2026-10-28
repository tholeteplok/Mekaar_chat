import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/message_preview_resolver.dart';
import '../services/supabase_service.dart';
import '../models/message_model.dart';
import '../models/room_participant_preferences.dart';
import '../services/e2ee_service.dart';
import '../services/local_message_database.dart';
import '../services/aegis_shredder_service.dart';
import 'reconnect_policy.dart';

class ChatRepository {
  final SupabaseService _supabaseService;

  /// Cache in-memory untuk pesan terdekripsi per pesan (id -> decryptedContent).
  /// Menghindari dekripsi kriptografis berulang terhadap ratusan pesan setiap kali
  /// Realtime stream memancarkan batch pembaruan.
  final Map<String, String> _decryptedContentCache = {};

  /// Registry stream controller dan message pool per room yang sedang aktif di layar.
  /// Memungkinkan eviksi optimistik 0ms saat pesan dihapus oleh pengguna.
  final Map<String, StreamController<List<Message>>> _activeRoomControllers = {};
  final Map<String, Map<String, Message>> _activeRoomMessagePools = {};

  @visibleForTesting
  Map<String, StreamController<List<Message>>> get activeRoomControllers =>
      _activeRoomControllers;

  @visibleForTesting
  Map<String, Map<String, Message>> get activeRoomMessagePools =>
      _activeRoomMessagePools;

  ChatRepository(this._supabaseService);

  /// Eviksi lokal seketika (0ms optimistic deletion) dari memori RAM, database lokal, dan UI stream.
  void evictMessageLocally(String roomId, String messageId) {
    _decryptedContentCache.remove(messageId);
    unawaited(LocalMessageDatabase.instance.deleteMessage(messageId));

    final pool = _activeRoomMessagePools[roomId];
    final controller = _activeRoomControllers[roomId];

    if (pool != null && pool.containsKey(messageId)) {
      pool.remove(messageId);
      if (controller != null && !controller.isClosed) {
        final sorted = pool.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        controller.add(sorted);
      }
    }
  }

  Future<Set<String>> _getHiddenMessageIds(String userId) async {
    try {
      final hiddenData = await _supabaseService.client
          .from('hidden_messages')
          .select('message_id')
          .eq('profile_id', userId)
          .timeout(const Duration(seconds: 4));

      return (hiddenData as List)
          .map((row) => row['message_id'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Mengambil snapshot obrolan lokal dari SQLCipher untuk transisi instan 0ms
  Future<List<Map<String, dynamic>>> getCachedRooms() async {
    return LocalMessageDatabase.instance.getCachedRooms();
  }

  // Get active chat rooms for current user
  Future<List<Map<String, dynamic>>> getRooms() async {
    // Zero-Leak Decoy: Jangan sentuh Supabase jika dalam mode Decoy/Duress
    if (LocalMessageDatabase.instance.isDecoy) {
      return LocalMessageDatabase.instance.getDecoyRooms();
    }

    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    final hiddenMsgIds = await _getHiddenMessageIds(userId);

    // 1. Coba panggil RPC Postgres get_user_inbox() (1 round-trip HTTP ~150-250ms)
    try {
      final rpcResult = await _supabaseService.client.rpc('get_user_inbox');
      if (rpcResult is List) {
        final parsedRooms = await _parseInboxRpcResult(rpcResult, userId, hiddenMsgIds);
        unawaited(LocalMessageDatabase.instance.saveRoomsCache(parsedRooms));
        return parsedRooms;
      }
    } catch (_) {
      // Graceful fallback ke legacy N+1 query jika migrasi RPC belum diaplikasikan di database
    }

    return _getRoomsLegacy(userId, hiddenMsgIds);
  }

  Future<List<Map<String, dynamic>>> _parseInboxRpcResult(
    List<dynamic> rpcList,
    String userId,
    Set<String> hiddenMsgIds,
  ) async {
    final List<Map<String, dynamic>> roomsList = [];

    for (final item in rpcList) {
      if (item is! Map<String, dynamic>) continue;

      final roomId = item['id'] as String? ?? '';
      if (roomId.isEmpty) continue;

      final unreadCount = item['unreadCount'] as int? ?? 0;
      final lastMsgRaw = item['lastMessage'] as Map<String, dynamic>?;

      String lastMessageText = 'Mulai percakapan...';
      DateTime? lastMessageTime;

      if (item['timestamp'] != null) {
        lastMessageTime = DateTime.tryParse(item['timestamp'].toString())?.toLocal();
      }

      if (lastMsgRaw != null) {
        final msgId = (lastMsgRaw['id'] ?? lastMsgRaw['message_id']) as String?;
        if (msgId != null && !hiddenMsgIds.contains(msgId)) {
          Message? localMsg;
          try {
            localMsg = await LocalMessageDatabase.instance.getLastActiveMessageForRoom(
              roomId,
              hiddenIds: hiddenMsgIds,
            );
          } catch (_) {}

          final bool isUnreadFromOther = unreadCount > 0 &&
              (lastMsgRaw['senderId'] ?? lastMsgRaw['sender_id']) != userId;

          final contentSource = (localMsg != null && localMsg.id == msgId)
              ? localMsg
              : Message(
                  id: msgId,
                  roomId: roomId,
                  senderId: (lastMsgRaw['senderId'] ?? lastMsgRaw['sender_id'] ?? '') as String,
                  content: (lastMsgRaw['content'] ?? '') as String,
                  type: MessageType.values.firstWhere(
                    (e) => e.name == (lastMsgRaw['msgType'] ?? lastMsgRaw['msg_type'] ?? 'text'),
                    orElse: () => MessageType.text,
                  ),
                  createdAt: lastMessageTime ?? DateTime.now(),
                  updatedAt: lastMessageTime ?? DateTime.now(),
                  isEncrypted: (lastMsgRaw['isEncrypted'] == true || lastMsgRaw['is_encrypted'] == 1),
                );

          if (contentSource.isEncrypted &&
              contentSource.content.isNotEmpty &&
              contentSource != localMsg) {
            lastMessageText = isUnreadFromOther ? 'Pesan baru' : '••••••••';
          } else {
            lastMessageText = MessagePreviewResolver.formatChatListPreview(
              type: contentSource.type,
              content: contentSource.content,
              isUnreadFromOther: isUnreadFromOther,
            );
          }
        }
      }

      roomsList.add({
        'id': roomId,
        'name': item['name'] as String? ?? 'User',
        'avatar': item['avatar'] as String? ?? 'U',
        'avatarUrl': item['avatarUrl'] as String?,
        'lastMessage': lastMessageText,
        'timestamp': lastMessageTime,
        'unreadCount': unreadCount,
        'isGuardian': item['isGuardian'] as bool? ?? false,
        'isGroup': item['isGroup'] as bool? ?? false,
        'memberCount': item['memberCount'] as int? ?? 0,
        'otherUserId': item['otherUserId'] as String? ?? userId,
        'otherUsername': '',
        'otherEmail': '',
        'isMuted': item['isMuted'] as bool? ?? false,
        'isArchived': item['isArchived'] as bool? ?? false,
      });
    }

    roomsList.sort((a, b) {
      final aTime = a['timestamp'] as DateTime?;
      final bTime = b['timestamp'] as DateTime?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return roomsList;
  }

  Future<List<Map<String, dynamic>>> _getRoomsLegacy(
    String userId,
    Set<String> hiddenMsgIds,
  ) async {

    // Get rooms the current user participates in, filtering out deleted rooms
    final roomsResponse = await _supabaseService.client
        .from('room_participants')
        .select('room_id, is_muted, is_archived, chat_rooms(id, room_type)')
        .eq('profile_id', userId)
        .isFilter('deleted_at', null);

    final roomFutures = (roomsResponse as List).map((row) async {
      final roomId = row['room_id'] as String;
      final roomData = row['chat_rooms'] as Map<String, dynamic>?;
      if (roomData == null) return null;
      final roomType = roomData['room_type'] as String;
      final bool isGroup = (roomType == 'group');

      String chatName = 'Saved Messages';
      String chatAvatar = '';
      String? avatarUrl;
      String otherUserId = userId;
      bool isGuardian = (roomType == 'guardian');
      Map<String, dynamic>? profile;
      int memberCount = 0;

      if (isGroup) {
        chatName = (roomData['name'] as String?)?.isNotEmpty == true
            ? roomData['name'] as String
            : 'Grup Mekaar';
        avatarUrl = roomData['avatar_url'] as String?;
        chatAvatar = chatName.isNotEmpty ? chatName[0].toUpperCase() : 'G';

        try {
          final membersResp = await _supabaseService.client
              .from('room_participants')
              .select('profile_id')
              .eq('room_id', roomId)
              .isFilter('deleted_at', null);
          memberCount = (membersResp as List).length;
        } catch (_) {}
      } else {
        // Get other participant profile_id
        final otherParticipant = await _supabaseService.client
            .from('room_participants')
            .select('profile_id')
            .eq('room_id', roomId)
            .neq('profile_id', userId)
            .maybeSingle();

        if (otherParticipant != null) {
          otherUserId = otherParticipant['profile_id'] as String;
          try {
            final profileResponse = await _supabaseService.client
                .from('public_profiles')
                .select('id, username, full_name, display_name, avatar_url')
                .eq('id', otherUserId)
                .maybeSingle();
            if (profileResponse != null) {
              profile = profileResponse;
              chatName =
                  (profile['display_name'] as String?)?.isNotEmpty == true
                  ? profile['display_name'] as String
                  : profile['full_name'] as String? ??
                        profile['username'] as String? ??
                        'User';
              chatAvatar = chatName.isNotEmpty ? chatName[0] : 'U';
              avatarUrl = profile['avatar_url'] as String?;
            }
          } catch (_) {}
        }
      }

      // Check if history was cleared for this user
      DateTime? historyClearedAt;
      try {
        final myParticipant = await _supabaseService.client
            .from('room_participants')
            .select('history_cleared_at')
            .eq('room_id', roomId)
            .eq('profile_id', userId)
            .maybeSingle();
        if (myParticipant != null &&
            myParticipant['history_cleared_at'] != null) {
          historyClearedAt = DateTime.parse(
            myParticipant['history_cleared_at'] as String,
          );
          final now = DateTime.now().toUtc();
          if (historyClearedAt.isAfter(now)) {
            historyClearedAt = now;
          }
        }
      } catch (_) {}

      // Count unread messages (messages after our last_read_at, NOT sent by us, and after history_cleared_at)
      int unreadCount = 0;
      try {
        final myParticipant = await _supabaseService.client
            .from('room_participants')
            .select('last_read_at, history_cleared_at')
            .eq('room_id', roomId)
            .eq('profile_id', userId)
            .maybeSingle();
        final myLastRead = myParticipant?['last_read_at'] as String?;
        final myHistoryCleared =
            myParticipant?['history_cleared_at'] as String?;
        if (myLastRead != null) {
          var unreadQuery = _supabaseService.client
              .from('messages')
              .select('id')
              .eq('room_id', roomId)
              .neq('sender_id', userId)
              .gt('created_at', myLastRead)
              .eq('is_deleted', false);

          if (myHistoryCleared != null) {
            unreadQuery = unreadQuery.gt('created_at', myHistoryCleared);
          }

          final unreadResp = await unreadQuery.count(CountOption.exact);
          unreadCount = unreadResp.count;
        }
      } catch (_) {}

      // Ambil pesan aktif (belum dihapus) terakhir setelah history_cleared_at
      var lastMsgQuery = _supabaseService.client
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .eq('is_deleted', false)
          .eq('is_silent_deleted', false);

      if (historyClearedAt != null) {
        lastMsgQuery = lastMsgQuery.gt(
          'created_at',
          historyClearedAt.toIso8601String(),
        );
      }

      final lastMsgResponseList = await lastMsgQuery
          .order('created_at', ascending: false)
          .limit(10);

      Map<String, dynamic>? activeRemoteMsgJson;
      for (final row in lastMsgResponseList) {
        final id = row['id'] as String?;
        if (id != null && !hiddenMsgIds.contains(id)) {
          activeRemoteMsgJson = row;
          break;
        }
      }

      String lastMessageText = 'Mulai percakapan...';
      DateTime? lastMessageTime;

      // Cek apakah pesan aktif terakhir sudah terdekripsi di database lokal (0ms, direct indexed query)
      Message? localLastMsg;
      try {
        localLastMsg =
            await LocalMessageDatabase.instance.getLastActiveMessageForRoom(
          roomId,
          hiddenIds: hiddenMsgIds,
        );
      } catch (_) {}

      // Tentukan pesan aktif paling mutakhir antara lokal dan remote
      Message? chosenMsg;
      if (localLastMsg != null && activeRemoteMsgJson != null) {
        final remoteTime = DateTime.tryParse(
          activeRemoteMsgJson['created_at'] as String? ?? '',
        );
        if (remoteTime != null && remoteTime.isAfter(localLastMsg.createdAt)) {
          chosenMsg = Message.fromJson(activeRemoteMsgJson);
        } else {
          chosenMsg = localLastMsg;
        }
      } else if (localLastMsg != null) {
        chosenMsg = localLastMsg;
      } else if (activeRemoteMsgJson != null) {
        chosenMsg = Message.fromJson(activeRemoteMsgJson);
      }

      if (chosenMsg != null) {
        final bool isUnreadFromOther =
            unreadCount > 0 && chosenMsg.senderId != userId;
        lastMessageTime = chosenMsg.createdAt;

        // Gunakan pesan lokal yang sudah terdekripsi jika ID-nya cocok
        final contentSource =
            (localLastMsg != null && localLastMsg.id == chosenMsg.id)
                ? localLastMsg
                : chosenMsg;

        if (contentSource.isEncrypted &&
            contentSource.content.isNotEmpty &&
            contentSource != localLastMsg) {
          lastMessageText = isUnreadFromOther ? 'Pesan baru' : '••••••••';
        } else {
          lastMessageText = MessagePreviewResolver.formatChatListPreview(
            type: contentSource.type,
            content: contentSource.content,
            isUnreadFromOther: isUnreadFromOther,
          );
        }
      }

      return {
        'id': roomId,
        'name': chatName,
        'avatar': chatAvatar,
        'avatarUrl': avatarUrl,
        'lastMessage': lastMessageText,
        'timestamp': lastMessageTime,
        'unreadCount': unreadCount,
        'isGuardian': isGuardian,
        'isGroup': isGroup,
        'memberCount': memberCount,
        'otherUserId': otherUserId,
        'otherUsername': profile?['username'] ?? '',
        'otherEmail': profile?['email'] ?? '',
        'isMuted': row['is_muted'] as bool? ?? false,
        'isArchived': row['is_archived'] as bool? ?? false,
      };
    });

    final results = await Future.wait(roomFutures);
    final roomsList = results.whereType<Map<String, dynamic>>().toList();

    // Sort by last message time, placing rooms with no messages at the bottom
    roomsList.sort((a, b) {
      final aTime = a['timestamp'] as DateTime?;
      final bTime = b['timestamp'] as DateTime?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    unawaited(LocalMessageDatabase.instance.saveRoomsCache(roomsList));
    return roomsList;
  }

  // Create normal or guardian chat room atomically via RPC.
  Future<String> createRoom(
    String otherUserId,
    String type, {
    bool screenshotProtectionEnabled = true,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    try {
      final response = await _supabaseService.client.rpc(
        'get_or_create_direct_room',
        params: {
          'other_user_id': otherUserId,
          'requested_room_type': type,
          'p_screenshot_protection': screenshotProtectionEnabled,
        },
      );
      if (response is String && response.isNotEmpty) return response;
    } catch (_) {
      // Fallback keeps local MVP usable before the additive migration is applied.
    }

    return _createRoomFallback(
      otherUserId,
      type,
      screenshotProtectionEnabled: screenshotProtectionEnabled,
    );
  }

  Future<String> _createRoomFallback(
    String otherUserId,
    String type, {
    bool screenshotProtectionEnabled = true,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    if (userId == otherUserId) {
      throw Exception('Cannot create room with yourself');
    }

    final checkQuery = await _supabaseService.client
        .from('room_participants')
        .select('room_id, chat_rooms!inner(room_type)')
        .eq('profile_id', userId)
        .eq('chat_rooms.room_type', type);

    final roomIds = (checkQuery as List)
        .map((r) => r['room_id'] as String?)
        .whereType<String>()
        .toList();

    if (roomIds.isNotEmpty) {
      final existingMatch = await _supabaseService.client
          .from('room_participants')
          .select('room_id')
          .inFilter('room_id', roomIds)
          .eq('profile_id', otherUserId)
          .maybeSingle();

      if (existingMatch != null) {
        final matchedRoomId = existingMatch['room_id'] as String;
        // Restore for current user if deleted — NEVER clear history_cleared_at!
        await _supabaseService.client
            .from('room_participants')
            .update({'deleted_at': null})
            .eq('room_id', matchedRoomId)
            .eq('profile_id', userId);
        return matchedRoomId;
      }
    }

    final roomResponse = await _supabaseService.client
        .from('chat_rooms')
        .insert({'room_type': type})
        .select()
        .single();
    final roomId = roomResponse['id'] as String;

    await _supabaseService.client.from('room_participants').insert([
      {
        'room_id': roomId,
        'profile_id': userId,
        'screenshot_protection_enabled': screenshotProtectionEnabled,
      },
      {
        'room_id': roomId,
        'profile_id': otherUserId,
        'screenshot_protection_enabled': true, // Recipient defaults to true
      },
    ]);

    return roomId;
  }

  // Stream messages in a specific room, respecting history_cleared_at
  Stream<List<Message>> streamMessages(
    String roomId, {
    void Function(bool reconnecting)? onReconnectChange,
  }) {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return const Stream.empty();

    final controller = StreamController<List<Message>>();
    StreamSubscription? streamSubscription;
    Timer? retryTimer;
    Timer? reconnectDebounceTimer;
    var retryAttempt = 0;
    bool hasEmittedData = false;
    final Map<String, Message> messagePool = {};

    _activeRoomControllers[roomId] = controller;
    _activeRoomMessagePools[roomId] = messagePool;

    const reconnectPolicy = ReconnectPolicy();

    // Helper untuk memancarkan cache dari SQLite lokal seketika
    Future<void> emitLocalCache({
      DateTime? historyCleared,
      Set<String>? hiddenIds,
    }) async {
      try {
        final localMsgs =
            await LocalMessageDatabase.instance.getMessagesForRoom(roomId);
        if (localMsgs.isNotEmpty && !controller.isClosed) {
          final now = DateTime.now().toUtc();
          final validLocal = localMsgs.where((m) {
            if (historyCleared != null &&
                !m.createdAt.isAfter(historyCleared)) {
              return false;
            }
            if (m.isSilentDeleted ||
                (hiddenIds != null && hiddenIds.contains(m.id))) {
              return false;
            }
            if (m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(now)) {
              return false;
            }
            return true;
          }).toList();

          for (final lm in validLocal) {
            _decryptedContentCache[lm.id] = lm.content;
            messagePool[lm.id] = lm;
          }
          if (validLocal.isNotEmpty && !controller.isClosed) {
            hasEmittedData = true;
            final sorted = messagePool.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            controller.add(sorted);
          }
        }
      } catch (_) {}
    }

    Future<void> initStream() async {
      // 0ms Offline-First: Render riwayat dari SQLite lokal seketika tanpa menunggu query jaringan
      await emitLocalCache();

      // Zero-Leak Decoy: Jangan jalankan query jaringan atau streaming Supabase
      if (LocalMessageDatabase.instance.isDecoy) {
        return;
      }

      // Guard: jangan lanjutkan jika stream sudah di-cancel
      if (controller.isClosed) return;

      DateTime? historyClearedAt;
      try {
        final p = await _supabaseService.client
            .from('room_participants')
            .select('history_cleared_at')
            .eq('room_id', roomId)
            .eq('profile_id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (p != null && p['history_cleared_at'] != null) {
          historyClearedAt = DateTime.parse(p['history_cleared_at'] as String);
          final now = DateTime.now().toUtc();
          if (historyClearedAt.isAfter(now)) {
            historyClearedAt = now;
          }
        }
      } catch (_) {}

      Set<String> hiddenMsgIds = {};
      try {
        final hiddenData = await _supabaseService.client
            .from('hidden_messages')
            .select('message_id')
            .eq('profile_id', userId)
            .timeout(const Duration(seconds: 4));

        for (var row in hiddenData) {
          hiddenMsgIds.add(row['message_id'] as String);
        }
      } catch (_) {}

      // Perbarui tampilan cache lokal jika filter jaringan berhasil didapatkan
      if (historyClearedAt != null || hiddenMsgIds.isNotEmpty) {
        await emitLocalCache(
          historyCleared: historyClearedAt,
          hiddenIds: hiddenMsgIds,
        );
      }

      // Guard: jangan subscribe jika stream sudah di-cancel (race condition)
      if (controller.isClosed) return;

      List<Map<String, dynamic>>? pendingBatch;
      bool isProcessing = false;

      Future<void> processBatch(List<Map<String, dynamic>> maps) async {
        try {
          final now = DateTime.now().toUtc();
          final rawMsgs = maps.map((map) => Message.fromJson(map)).toList();

          // Eviksi pesan yang di-silent delete, disembunyikan, atau kedaluwarsa dari messagePool
          for (final m in rawMsgs) {
            final isExpired =
                m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(now);
            final isHidden = hiddenMsgIds.contains(m.id);
            final isHistoryCleared = historyClearedAt != null &&
                !m.createdAt.isAfter(historyClearedAt);

            if (m.isSilentDeleted || isHidden || isExpired || isHistoryCleared) {
              messagePool.remove(m.id);
              _decryptedContentCache.remove(m.id);
              unawaited(LocalMessageDatabase.instance.deleteMessage(m.id));
            }
          }

          var msgs = rawMsgs.where((m) {
            if (historyClearedAt != null &&
                !m.createdAt.isAfter(historyClearedAt)) {
              return false;
            }
            if (m.isSilentDeleted || hiddenMsgIds.contains(m.id)) return false;
            if (m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(now)) {
              return false;
            }
            return true;
          }).toList();

          final decryptedMsgs = await Future.wait(
            msgs.map((m) async {
              if (m.isEncrypted && m.content.isNotEmpty && !m.isDeleted) {
                // 1. Cek cache in-memory RAM
                final cached = _decryptedContentCache[m.id];
                if (cached != null) {
                  return m.copyWith(content: cached);
                }

                // 2. Cek database lokal SQLite
                final localMsg =
                    await LocalMessageDatabase.instance.getMessage(m.id);
                if (localMsg != null && localMsg.content.isNotEmpty) {
                  _decryptedContentCache[m.id] = localMsg.content;
                  return m.copyWith(content: localMsg.content);
                }

                // 3. Dekripsi kriptografis (pertama kali pesan diterima)
                try {
                  final plain = await E2eeService.instance.decryptForRoom(
                    roomId,
                    m.content,
                  );
                  // Batasi kapasitas cache dengan safe pruning (hapus 500 entri terlama, bukan .clear() total)
                  if (_decryptedContentCache.length > 2000) {
                    final keysToRemove =
                        _decryptedContentCache.keys.take(500).toList();
                    for (final k in keysToRemove) {
                      _decryptedContentCache.remove(k);
                    }
                  }
                  _decryptedContentCache[m.id] = plain;
                  final decrypted = m.copyWith(content: plain);

                  // Simpan ke SQLite (baik teks biasa maupun undecryptableText)
                  // agar tidak perlu diproses ulang berulang kali
                  unawaited(
                    LocalMessageDatabase.instance.saveMessage(decrypted),
                  );
                  return decrypted;
                } catch (_) {
                  final failed =
                      m.copyWith(content: E2eeService.undecryptableText);
                  _decryptedContentCache[m.id] = E2eeService.undecryptableText;
                  unawaited(
                    LocalMessageDatabase.instance.saveMessage(failed),
                  );
                  return failed;
                }
              }

              // Untuk pesan non-enkripsi / teks biasa / system
              unawaited(LocalMessageDatabase.instance.saveMessage(m));
              return m;
            }),
          );

          for (final dm in decryptedMsgs) {
            messagePool[dm.id] = dm;
          }

          if (!controller.isClosed) {
            hasEmittedData = true;
            final sorted = messagePool.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            controller.add(sorted);
          }
        } finally {
          isProcessing = false;
          if (pendingBatch != null) {
            final nextBatch = pendingBatch!;
            pendingBatch = null;
            isProcessing = true;
            processBatch(nextBatch);
          }
        }
      }

      late Future<void> Function() subscribe;

      void handleStreamError(dynamic err) {
        if (controller.isClosed) return;

        // Debounce status reconnecting / offline (2.5s) agar fluktuasi mikro socket
        // tidak langsung memunculkan banner "Mode Offline" di layar obrolan pengguna.
        if (reconnectDebounceTimer == null || !reconnectDebounceTimer!.isActive) {
          reconnectDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
            if (!controller.isClosed) {
              onReconnectChange?.call(true);
            }
          });
        }

        // Coba subscribe ulang dengan backoff
        if (retryAttempt < reconnectPolicy.maxAttempts) {
          retryAttempt++;
          final delay = reconnectPolicy.delayForAttempt(retryAttempt);
          retryTimer?.cancel();
          retryTimer = Timer(delay, () {
            if (!controller.isClosed) {
              subscribe();
            }
          });
        } else {
          // Jika data lokal sudah pernah dipancarkan ke controller,
          // JANGAN lemparkan controller.addError(err) karena akan merusak
          // tampilan obrolan lokal pengguna dan menggantinya dengan error screen.
          // Cukup pertahankan mode reconnecting/offline dan coba lagi berkala.
          if (hasEmittedData) {
            retryTimer?.cancel();
            retryTimer = Timer(const Duration(seconds: 15), () {
              if (!controller.isClosed) {
                subscribe();
              }
            });
          } else {
            reconnectDebounceTimer?.cancel();
            onReconnectChange?.call(false);
            controller.addError(err);
          }
        }
      }

      subscribe = () async {
        // Cancel subscription lama sebelum subscribe ulang
        await streamSubscription?.cancel();
        streamSubscription = null;

        try {
          // P1: Local-First Active Window — batasi stream ke 100 pesan terbaru
          // agar Supabase Realtime tidak mengirim ribuan baris data pada setiap mutasi
          streamSubscription = _supabaseService.client
              .from('messages')
              .stream(primaryKey: ['id'])
              .eq('room_id', roomId)
              .order('created_at', ascending: false)
              .limit(100)
              .listen(
                (maps) {
                  reconnectDebounceTimer?.cancel();
                  if (retryAttempt > 0) {
                    retryAttempt = 0;
                  }
                  onReconnectChange?.call(false);
                  if (isProcessing) {
                    pendingBatch = maps;
                    return;
                  }
                  isProcessing = true;
                  processBatch(maps);
                },
                onError: (err) {
                  handleStreamError(err);
                },
              );
        } catch (e) {
          handleStreamError(e);
        }
      };

      await subscribe();
    }

    controller.onCancel = () {
      reconnectDebounceTimer?.cancel();
      retryTimer?.cancel();
      streamSubscription?.cancel();
      if (_activeRoomControllers[roomId] == controller) {
        _activeRoomControllers.remove(roomId);
        _activeRoomMessagePools.remove(roomId);
      }
    };

    initStream();
    return controller.stream;
  }

  // Send message
  Future<Message> sendMessage(
    String roomId,
    String content, {
    String? mediaUrl,
    MessageType type = MessageType.text,
    bool isViewOnce = false,
    String? replyToId,
    DateTime? autoDeleteAt,
    bool isGroup = false,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Zero-Leak Decoy: Simpan pesan hanya di database lokal decoy tanpa kirim ke Supabase
    if (LocalMessageDatabase.instance.isDecoy) {
      final now = DateTime.now();
      final decoyMsg = Message(
        id: 'msg_decoy_${now.millisecondsSinceEpoch}',
        roomId: roomId,
        senderId: userId,
        content: content,
        mediaUrl: mediaUrl,
        type: type,
        isViewOnce: isViewOnce,
        createdAt: now,
        updatedAt: now,
      );
      unawaited(LocalMessageDatabase.instance.saveMessage(decoyMsg));

      final activePool = _activeRoomMessagePools[roomId];
      final activeCtrl = _activeRoomControllers[roomId];
      if (activePool != null) {
        activePool[decoyMsg.id] = decoyMsg;
        if (activeCtrl != null && !activeCtrl.isClosed) {
          final sorted = activePool.values.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          activeCtrl.add(sorted);
        }
      }
      return decoyMsg;
    }

    // Enkripsi E2EE wajib untuk seluruh obrolan 1:1 (Fail-Closed Murni).
    // Tidak ada toleransi fallback plaintext pada chat privat 1:1 demi mencegah
    // serangan Downgrade Attack dan kebocoran data di server Supabase.
    var finalContent = content;
    var isEncrypted = false;
    if (content.isNotEmpty && !isGroup) {
      String? envelope;
      try {
        envelope = await E2eeService.instance.encryptForRoom(roomId, content);
      } on E2eeUnavailableException catch (e) {
        throw Exception(
          'Gagal mengenkripsi pesan, pesan tidak dikirim. Coba lagi. ($e)',
        );
      }
      if (envelope == null) {
        throw Exception(
          'Kunci enkripsi penerima belum aktif. Pesan ditahan demi keamanan (Fail-Closed).',
        );
      }
      finalContent = envelope;
      isEncrypted = true;
    }

    final data = {
      'room_id': roomId,
      'sender_id': userId,
      'content': finalContent,
      'media_url': mediaUrl,
      'msg_type': type.name,
      'is_view_once': isViewOnce,
      'reply_to_id': replyToId,
      'auto_delete_at': autoDeleteAt?.toUtc().toIso8601String(),
      'is_encrypted': isEncrypted,
    };

    final response = await _supabaseService.client
        .from('messages')
        .insert(data)
        .select()
        .single();

    final sentMsg = Message.fromJson(response);
    final plaintextMsg = sentMsg.copyWith(content: content);
    _decryptedContentCache[sentMsg.id] = content;
    unawaited(LocalMessageDatabase.instance.saveMessage(plaintextMsg));

    // 0ms Instant Local Emit: mutasi RAM dan pancarkan ke UI stream seketika
    final activePool = _activeRoomMessagePools[roomId];
    final activeCtrl = _activeRoomControllers[roomId];
    if (activePool != null) {
      activePool[sentMsg.id] = plaintextMsg;
      if (activeCtrl != null && !activeCtrl.isClosed) {
        final sorted = activePool.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        activeCtrl.add(sorted);
      }
    }

    // Note: Push notification untuk pesan baru sudah ditangani secara otomatis
    // dan andal oleh database webhook trigger notify_push_webhook via pg_net
    // ke Edge Function send-push-notification. Pemanggilan client fallback
    // dinonaktifkan untuk mencegah notifikasi ganda (BUG-03).

    return plaintextMsg;
  }

  /// Menandai pesan media sekali lihat (View Once) sebagai sudah dibuka di database Supabase
  Future<void> markViewOnceOpened(String messageId) async {
    try {
      await _supabaseService.client.rpc(
        'mark_view_once_opened',
        params: {'target_message_id': messageId},
      );
    } catch (e) {
      // Log error — jika gagal, pesan view-once mungkin bisa dibuka berkali-kali
      // ignore: avoid_print
      print('[ChatRepository] markViewOnceOpened gagal: $e');
    }
  }

  // Advanced delete: deletes silently if unread in general chat, otherwise leaves tombstone
  Future<void> deleteMessageForEveryone(String messageId, {String? roomId}) async {
    if (roomId != null) {
      evictMessageLocally(roomId, messageId);
    } else {
      _decryptedContentCache.remove(messageId);
      unawaited(LocalMessageDatabase.instance.deleteMessage(messageId));
    }
    try {
      // Try the new advanced RPC first
      await _supabaseService.client.rpc(
        'delete_message_for_everyone',
        params: {'msg_uuid': messageId},
      );
      return;
    } catch (_) {}

    // Fallback if migration 31 hasn't run yet, try older soft_delete_message
    try {
      await _supabaseService.client.rpc(
        'soft_delete_message',
        params: {'message_uuid': messageId},
      );
      return;
    } catch (_) {}

    // Legacy fallback
    await _supabaseService.client
        .from('messages')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  // Local delete: hides message for the current user only (like WhatsApp)
  Future<void> hideMessageForMe(String messageId, {String? roomId}) async {
    if (roomId != null) {
      evictMessageLocally(roomId, messageId);
    } else {
      _decryptedContentCache.remove(messageId);
      unawaited(LocalMessageDatabase.instance.deleteMessage(messageId));
    }
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    try {
      await _supabaseService.client.rpc(
        'hide_message_for_me',
        params: {'msg_uuid': messageId},
      );
    } catch (_) {
      try {
        await _supabaseService.client.from('hidden_messages').upsert({
          'profile_id': userId,
          'message_id': messageId,
        }, onConflict: 'profile_id,message_id');
      } catch (_) {}
    }
  }

  // Perbarui konten pesan lokasi live (berbagi lokasi sukarela, bukan SOS).
  Future<void> updateMessageContent(String messageId, String content) async {
    final contentToStore = await _reencryptIfNeeded(messageId, content);
    await _supabaseService.client
        .from('messages')
        .update({
          'content': contentToStore,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  // Bila pesan asal terenkripsi, konten baru harus dienkripsi ulang
  // dengan kunci room yang sama sebelum ditulis ke server. Fail-closed:
  // bila re-enkripsi gagal karena sebab sementara, lempar error alih-alih
  // menyimpan plaintext ke pesan yang seharusnya terenkripsi.
  Future<String> _reencryptIfNeeded(String messageId, String newContent) async {
    Map<String, dynamic>? row;
    try {
      row = await _supabaseService.client
          .from('messages')
          .select('room_id, is_encrypted')
          .eq('id', messageId)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal memeriksa status enkripsi pesan: $e');
    }

    if (row == null || row['is_encrypted'] != true) return newContent;

    try {
      final envelope = await E2eeService.instance.encryptForRoom(
        row['room_id'] as String,
        newContent,
      );
      // envelope == null berarti lawan dipastikan sudah tidak punya kunci
      // publik lagi (kasus langka) — pertahankan sebagai plaintext eksplisit
      // hanya dalam kondisi itu.
      return envelope ?? newContent;
    } on E2eeUnavailableException catch (e) {
      throw Exception('Gagal mengenkripsi ulang pesan, coba lagi. ($e)');
    }
  }

  Future<void> markRoomRead(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId != null) {
      try {
        // Clear deleted_at marker when entering/interacting with room again
        await _supabaseService.client
            .from('room_participants')
            .update({'deleted_at': null})
            .eq('room_id', roomId)
            .eq('profile_id', userId);
      } catch (_) {}
    }

    try {
      await _supabaseService.client.rpc(
        'mark_room_read',
        params: {'room_uuid': roomId},
      );
    } catch (_) {
      if (userId == null) return;
      await _supabaseService.client
          .from('room_participants')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('room_id', roomId)
          .eq('profile_id', userId);
    }
  }

  // Search user profile by username through a limited public RPC.
  Future<Map<String, dynamic>?> searchProfile(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return null;

    try {
      final response = await _supabaseService.client.rpc(
        'search_public_profiles',
        params: {'search_query': cleanQuery},
      );
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool canForwardMessage(
    Message message, {
    bool forwardingProtectionActive = false,
  }) {
    if (message.type == MessageType.location ||
        message.type == MessageType.system) {
      return false;
    }
    if (forwardingProtectionActive) return false;
    return true;
  }

  /// Batas waktu maksimum untuk mengedit pesan (30 menit setelah dikirim).
  static const Duration maxEditWindow = Duration(minutes: 30);

  /// Guard: pesan di chat guardian TIDAK BOLEH diedit untuk menjaga integritas bukti hukum.
  /// Pesan yang melebihi batas waktu [maxEditWindow] juga tidak dapat diedit.
  /// Gunakan ini sebelum menampilkan opsi edit di UI.
  bool canEditMessage(
    Message message, {
    required bool isGuardianRoom,
    DateTime? now,
  }) {
    if (isGuardianRoom) return false;
    if (message.isDeleted) return false;
    if (message.type != MessageType.text) return false;
    final currentTime = now ?? DateTime.now().toUtc();
    if (currentTime.difference(message.createdAt.toUtc()) > maxEditWindow) {
      return false;
    }
    return true;
  }

  /// Kembalikan alasan pembatasan edit yang dapat dibaca manusia, atau null jika diizinkan.
  /// Digunakan oleh UI untuk menampilkan pesan edukasi yang transparan kepada pengguna.
  String? getEditRestrictionReason(
    Message message, {
    required bool isGuardianRoom,
    DateTime? now,
  }) {
    if (isGuardianRoom) {
      return 'Pesan di ruang Guardian tidak dapat diedit demi integritas bukti hukum.';
    }
    if (message.isDeleted) {
      return 'Pesan yang sudah dihapus tidak dapat diedit.';
    }
    if (message.type != MessageType.text) {
      return 'Hanya pesan teks yang dapat diedit.';
    }
    final currentTime = now ?? DateTime.now().toUtc();
    if (currentTime.difference(message.createdAt.toUtc()) > maxEditWindow) {
      return 'Batas waktu edit pesan (30 menit) telah berakhir.';
    }
    return null;
  }

  /// Edit isi teks pesan. Hanya pengirim di chat non-guardian yang boleh.
  /// Menerapkan pembaruan lokal instan (0ms optimistic) ke memori, SQLite,
  /// dan message pool sebelum transmisi ke Supabase.
  Future<void> editMessage(String messageId, String newContent) async {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    // 1. Pembaruan optimistik instan ke cache memori & message pool aktif
    _decryptedContentCache[messageId] = newContent;
    for (final pool in _activeRoomMessagePools.values) {
      final existing = pool[messageId];
      if (existing != null) {
        pool[messageId] = existing.copyWith(
          content: newContent,
          editedAt: now,
        );
      }
    }
    // Emit segera ke stream UI agar bubble berubah tanpa menunggu jaringan
    for (final entry in _activeRoomControllers.entries) {
      final pool = _activeRoomMessagePools[entry.key];
      if (pool != null && pool.containsKey(messageId) && !entry.value.isClosed) {
        final sorted = pool.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        entry.value.add(sorted);
      }
    }

    // 2. Simpan ke SQLite lokal agar tersedia offline
    for (final pool in _activeRoomMessagePools.values) {
      final updated = pool[messageId];
      if (updated != null) {
        unawaited(LocalMessageDatabase.instance.saveMessage(updated));
        break;
      }
    }

    // 3. Re-enkripsi & kirim ke Supabase
    final contentToStore = await _reencryptIfNeeded(messageId, newContent);
    await _supabaseService.client
        .from('messages')
        .update({
          'content': contentToStore,
          'edited_at': nowIso,
          'updated_at': nowIso,
        })
        .eq('id', messageId);
  }

  /// Toggle emoji reaction. Uses RPC for atomic add/remove.
  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      await _supabaseService.client.rpc(
        'toggle_reaction',
        params: {'message_uuid': messageId, 'emoji_key': emoji},
      );
    } catch (_) {
      // Fallback: client-side optimistic update skipped, reaction will sync on next stream event
    }
  }

  /// Returns the last_read_at of the OTHER participant in a 1-on-1 room.
  /// Used to compute read receipt status for sent messages.
  Future<DateTime?> getOtherParticipantLastRead(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;
    try {
      final response = await _supabaseService.client
          .from('room_participants')
          .select('last_read_at')
          .eq('room_id', roomId)
          .neq('profile_id', userId)
          .maybeSingle();
      if (response != null && response['last_read_at'] != null) {
        return DateTime.parse(response['last_read_at'] as String);
      }
    } catch (_) {}
    return null;
  }

  /// Count unread messages in a room for the current user.
  Future<int> getUnreadCount(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return 0;
    try {
      final participantData = await _supabaseService.client
          .from('room_participants')
          .select('last_read_at')
          .eq('room_id', roomId)
          .eq('profile_id', userId)
          .maybeSingle();
      if (participantData == null) return 0;
      final lastReadAt = participantData['last_read_at'] as String?;
      if (lastReadAt == null) return 0;

      final response = await _supabaseService.client
          .from('messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender_id', userId)
          .gt('created_at', lastReadAt)
          .eq('is_deleted', false)
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      return 0;
    }
  }

  /// Update the current user's last_seen_at via RPC.
  Future<void> updateLastSeen() async {
    // Zero-Network Decoy: Jangan sentuh Supabase jika dalam mode Decoy/Duress
    if (LocalMessageDatabase.instance.isDecoy) return;
    try {
      await _supabaseService.client.rpc('update_last_seen');
    } catch (_) {}
  }

  /// Hard-delete messages that have passed their auto_delete_at timestamp.
  /// Memvalidasi database lokal, backend Supabase, dan memori RAM _activeRoomMessagePools
  /// secara sinkron sehingga pesan yang kedaluwarsa langsung lenyap dari layar (0ms).
  Future<int> purgeExpiredMessages({String? targetRoomId}) async {
    final now = DateTime.now().toUtc();
    final roomsToCheck = targetRoomId != null
        ? [targetRoomId]
        : _activeRoomMessagePools.keys.toList();

    for (final rId in roomsToCheck) {
      final pool = _activeRoomMessagePools[rId];
      final controller = _activeRoomControllers[rId];
      if (pool != null && pool.isNotEmpty) {
        final expiredIds = pool.values
            .where((m) => m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(now))
            .map((m) => m.id)
            .toList();

        if (expiredIds.isNotEmpty) {
          for (final id in expiredIds) {
            pool.remove(id);
            _decryptedContentCache.remove(id);
            unawaited(LocalMessageDatabase.instance.deleteMessage(id));
          }
          if (controller != null && !controller.isClosed) {
            final sorted = pool.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            controller.add(sorted);
          }
        }
      }
    }

    unawaited(LocalMessageDatabase.instance.purgeExpiredMessages());
    try {
      final response = await _supabaseService.client.rpc(
        'purge_expired_messages',
      );
      return (response as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Fetch a public profile by id (for display in block list, etc).
  Future<Map<String, dynamic>?> searchProfileById(String profileId) async {
    try {
      final response = await _supabaseService.client
          .from('public_profiles')
          .select('id, username, full_name, display_name, avatar_url')
          .eq('id', profileId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Get the last_seen_at of another user, honoring their last_seen_privacy
  /// setting via the `get_last_seen_for` RPC. Returns null when hidden.
  Future<DateTime?> getLastSeen(String profileId) async {
    // Zero-Network Decoy: Jangan sentuh Supabase jika dalam mode Decoy/Duress
    if (LocalMessageDatabase.instance.isDecoy || profileId == 'mekaar_official') return null;
    try {
      final response = await _supabaseService.client.rpc(
        'get_last_seen_for',
        params: {'target_id': profileId},
      );
      if (response != null) {
        return DateTime.parse(response as String);
      }
    } catch (_) {}
    return null;
  }

  /// Clear Chat History for current user in a room
  Future<void> clearChatHistory(String roomId) async {
    unawaited(LocalMessageDatabase.instance.deleteRoomMessages(roomId));
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabaseService.client
          .from('room_participants')
          .update({'history_cleared_at': nowIso})
          .eq('room_id', roomId)
          .eq('profile_id', userId);
    } catch (_) {}

    // Double-Lock Protection: Eksekusi batch hide di sisi server via RPC
    try {
      await _supabaseService.client.rpc(
        'hide_all_room_messages',
        params: {'p_room_id': roomId},
      );
    } catch (_) {}

    try {
      await _supabaseService.client.rpc(
        'hide_all_room_calls',
        params: {'p_room_id': roomId},
      );
    } catch (_) {}
  }

  /// Soft delete Chat Room for current user (hides from list)
  Future<void> deleteChat(String roomId) async {
    unawaited(LocalMessageDatabase.instance.deleteRoomMessages(roomId));
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabaseService.client
          .from('room_participants')
          .update({'deleted_at': nowIso, 'history_cleared_at': nowIso})
          .eq('room_id', roomId)
          .eq('profile_id', userId);
    } catch (_) {}

    // Double-Lock Protection: Eksekusi batch hide di sisi server via RPC
    try {
      await _supabaseService.client.rpc(
        'hide_all_room_messages',
        params: {'p_room_id': roomId},
      );
    } catch (_) {}

    try {
      await _supabaseService.client.rpc(
        'hide_all_room_calls',
        params: {'p_room_id': roomId},
      );
    } catch (_) {}
  }

  /// Ambil pengaturan privasi per-room untuk current user.
  Future<RoomParticipantPreferences?> getRoomPreferences(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;
    try {
      final row = await _supabaseService.client
          .from('room_participants')
          .select(
            'room_id, is_muted, muted_until, disappearing_override_hours, is_archived',
          )
          .eq('room_id', roomId)
          .eq('profile_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return RoomParticipantPreferences.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Toggle mute notifikasi untuk room.
  ///
  /// SENGAJA tidak menelan error di sini (beda dari beberapa method lain
  /// di file ini yang best-effort) -- kegagalan RPC pengaturan seperti ini
  /// HARUS terlihat oleh pengguna/UI, bukan tampak "berhasil" padahal
  /// diam-diam tidak tersimpan ke database. Ini persis pola yang membuat
  /// bug RPC search_path (lihat migrations/40_fix_room_participant_rpcs_
  /// search_path.sql) tidak terdeteksi sekian lama.
  Future<void> updateRoomMute(String roomId, bool muted) async {
    await _supabaseService.client.rpc(
      'toggle_room_mute',
      params: {'p_room_id': roomId, 'p_muted': muted},
    );
  }

  /// Set pesan menghilang level ruangan (tersinkronisasi untuk semua peserta).
  /// Memanggil RPC `set_room_disappearing_hours`.
  Future<void> updateRoomDisappearingHours(String roomId, int hours) async {
    await _supabaseService.client.rpc(
      'set_room_disappearing_hours',
      params: {'p_room_id': roomId, 'p_hours': hours},
    );
  }

  /// Ambil setelan pesan menghilang level ruangan (dalam jam).
  Future<int> getRoomDisappearingHours(String roomId) async {
    try {
      final room = await _supabaseService.client
          .from('chat_rooms')
          .select('disappearing_hours')
          .eq('id', roomId)
          .maybeSingle();
      return (room?['disappearing_hours'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Set pembersihan terjadwal level ruangan (One-Shot atau Daily).
  /// Memanggil RPC `set_room_scheduled_wipe`.
  Future<void> setRoomScheduledWipe({
    required String roomId,
    required String mode, // 'off' | 'one_shot' | 'daily'
    String? timeString, // e.g. '14:00:00'
    DateTime? targetAtUtc,
  }) async {
    await _supabaseService.client.rpc(
      'set_room_scheduled_wipe',
      params: {
        'p_room_id': roomId,
        'p_time': timeString,
        'p_mode': mode,
        'p_target_at': targetAtUtc?.toIso8601String(),
      },
    );
  }

  /// Ambil setelan pembersihan terjadwal level ruangan.
  Future<Map<String, dynamic>?> getRoomScheduledWipe(String roomId) async {
    try {
      final room = await _supabaseService.client
          .from('chat_rooms')
          .select(
            'scheduled_wipe_time, scheduled_wipe_mode, scheduled_wipe_target_at, disappearing_hours',
          )
          .eq('id', roomId)
          .maybeSingle();
      return room;
    } catch (_) {
      return null;
    }
  }

  /// Eksekusi pembersihan riwayat chat sekarang (manual / timer terpicu).
  /// Memanggil RPC `execute_room_scheduled_wipe`.
  Future<int> executeRoomScheduledWipe(String roomId) async {
    // 0ms Instant Local Memory Eviction: Kosongkan pool RAM dan pancarkan list kosong seketika
    final pool = _activeRoomMessagePools[roomId];
    final controller = _activeRoomControllers[roomId];
    if (pool != null) {
      for (final msgId in pool.keys) {
        _decryptedContentCache.remove(msgId);
      }
      pool.clear();
      if (controller != null && !controller.isClosed) {
        controller.add(const []);
      }
    }

    unawaited(LocalMessageDatabase.instance.deleteRoomMessages(roomId));
    try {
      final result = await _supabaseService.client.rpc(
        'execute_room_scheduled_wipe',
        params: {'p_room_id': roomId},
      );
      return (result as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Set status Burn on Exit (Hapus pesan saat keluar layar obrolan).
  Future<void> setRoomBurnOnExit(String roomId, bool enabled) async {
    await _supabaseService.client.rpc(
      'set_room_burn_on_exit',
      params: {'p_room_id': roomId, 'p_enabled': enabled},
    );
  }

  /// Dapatkan status Burn on Exit untuk sebuah room.
  Future<bool> getRoomBurnOnExit(String roomId) async {
    try {
      final room = await _supabaseService.client
          .from('chat_rooms')
          .select('burn_on_exit')
          .eq('id', roomId)
          .maybeSingle();
      return (room?['burn_on_exit'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Eksekusi penghapusan pesan saat keluar room (Burn on Exit).
  /// Menghapus jejak lokal (memori, SQLite, file cache OS) dan riwayat di server.
  Future<void> executeRoomBurnOnExit(String roomId) async {
    // 1. Bersihkan cache in-memory dan pool room agar gelembung pesan tidak tersisa di RAM
    _decryptedContentCache.clear();
    final pool = _activeRoomMessagePools[roomId];
    final controller = _activeRoomControllers[roomId];
    if (pool != null) {
      pool.clear();
      if (controller != null && !controller.isClosed) {
        controller.add(const []);
      }
    }

    // 2. Bersihkan baris pesan dari database lokal SQLCipher
    unawaited(LocalMessageDatabase.instance.deleteRoomMessages(roomId));

    // 3. Bersihkan file media/audio sementara di cache OS
    unawaited(_cleanupTemporaryCache());

    // 4. Perintahkan backend Supabase untuk menghapus pesan di server
    try {
      await _supabaseService.client.rpc(
        'execute_room_burn_on_exit',
        params: {'p_room_id': roomId},
      );
    } catch (_) {}
  }

  /// Membersihkan file temporer gambar dan audio rekaman agar tidak meninggalkan jejak forensik.
  Future<void> _cleanupTemporaryCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await AegisShredderService.instance.shredDirectoryContents(tempDir.path);
      }
    } catch (_) {}
  }

  /// Set pesan menghilang override untuk satu room (backward compatibility).
  Future<void> updateRoomDisappearingOverride(String roomId, int? hours) async {
    await updateRoomDisappearingHours(roomId, hours ?? 0);
  }

  /// Arsipkan room (sembunyikan dari daftar utama).
  Future<void> archiveRoom(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    await _supabaseService.client
        .from('room_participants')
        .update({'is_archived': true})
        .eq('room_id', roomId)
        .eq('profile_id', userId);
  }

  /// Batalkan arsip room.
  Future<void> unarchiveRoom(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    await _supabaseService.client
        .from('room_participants')
        .update({'is_archived': false})
        .eq('room_id', roomId)
        .eq('profile_id', userId);
  }

  /// Membuat room obrolan grup baru.
  Future<String> createGroupRoom({
    required String name,
    String? avatarUrl,
    String? description,
    required List<String> participantIds,
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    try {
      final response = await _supabaseService.client.rpc(
        'create_group_room',
        params: {
          'p_name': name,
          'p_avatar_url': avatarUrl,
          'p_description': description,
          'p_participant_ids': participantIds,
        },
      );
      if (response is String && response.isNotEmpty) {
        return response;
      }
    } catch (_) {
      // Fallback pembuatan manual jika RPC belum dijalankan
    }

    final roomResp = await _supabaseService.client
        .from('chat_rooms')
        .insert({
          'room_type': 'group',
          'name': name,
          'avatar_url': avatarUrl,
          'description': description,
          'created_by': userId,
        })
        .select()
        .single();
    final roomId = roomResp['id'] as String;

    final participantsToInsert = <Map<String, dynamic>>[
      {
        'room_id': roomId,
        'profile_id': userId,
        'role': 'owner',
        'screenshot_protection_enabled': true,
      },
    ];

    for (final pid in participantIds) {
      if (pid != userId) {
        participantsToInsert.add({
          'room_id': roomId,
          'profile_id': pid,
          'role': 'member',
          'invited_by': userId,
          'screenshot_protection_enabled': true,
        });
      }
    }

    await _supabaseService.client
        .from('room_participants')
        .insert(participantsToInsert);

    return roomId;
  }

  /// Mendapatkan detail informasi & peserta grup.
  Future<Map<String, dynamic>?> getGroupDetails(String roomId) async {
    try {
      final roomResp = await _supabaseService.client
          .from('chat_rooms')
          .select('id, name, avatar_url, description, created_by, created_at')
          .eq('id', roomId)
          .maybeSingle();

      if (roomResp == null) return null;

      final participantsResp = await _supabaseService.client
          .from('room_participants')
          .select(
            'profile_id, role, joined_at, public_profiles(id, username, full_name, display_name, avatar_url)',
          )
          .eq('room_id', roomId)
          .isFilter('deleted_at', null);

      return {'room': roomResp, 'participants': participantsResp};
    } catch (_) {
      return null;
    }
  }

  /// Menambahkan anggota baru ke grup.
  Future<void> addGroupParticipants(
    String roomId,
    List<String> profileIds,
  ) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final toInsert = profileIds
        .map(
          (pid) => {
            'room_id': roomId,
            'profile_id': pid,
            'role': 'member',
            'invited_by': userId,
          },
        )
        .toList();

    await _supabaseService.client.from('room_participants').upsert(toInsert);
  }

  /// Mengeluarkan anggota dari grup (Owner/Admin).
  Future<void> removeGroupParticipant(String roomId, String profileId) async {
    await _supabaseService.client
        .from('room_participants')
        .delete()
        .eq('room_id', roomId)
        .eq('profile_id', profileId);
  }

  /// Keluar dari grup.
  Future<void> leaveGroup(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    await _supabaseService.client
        .from('room_participants')
        .delete()
        .eq('room_id', roomId)
        .eq('profile_id', userId);
  }
}
