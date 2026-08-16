import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/message_model.dart';
import '../models/room_participant_preferences.dart';
import '../services/e2ee_service.dart';

class ChatRepository {
  final SupabaseService _supabaseService;

  ChatRepository(this._supabaseService);

  // Get active chat rooms for current user
  Future<List<Map<String, dynamic>>> getRooms() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

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
              chatName = (profile['display_name'] as String?)?.isNotEmpty == true
                  ? profile['display_name'] as String
                  : profile['full_name'] as String? ?? profile['username'] as String? ?? 'User';
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
        if (myParticipant != null && myParticipant['history_cleared_at'] != null) {
          historyClearedAt = DateTime.parse(myParticipant['history_cleared_at'] as String);
          final now = DateTime.now().toUtc();
          if (historyClearedAt.isAfter(now)) {
            historyClearedAt = now;
          }
        }
      } catch (_) {}

      // Get last message in the room after history_cleared_at
      var lastMsgQuery = _supabaseService.client
          .from('messages')
          .select()
          .eq('room_id', roomId);
      
      if (historyClearedAt != null) {
        lastMsgQuery = lastMsgQuery.gt('created_at', historyClearedAt.toIso8601String());
      }

      final lastMsgResponse = await lastMsgQuery
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String lastMessageText = 'Mulai percakapan...';
      DateTime lastMessageTime = DateTime.now();

      if (lastMsgResponse != null) {
        final lastMsg = Message.fromJson(lastMsgResponse);
        if (lastMsg.isDeleted) {
          lastMessageText = 'Pesan telah dihapus';
        } else if (lastMsg.isEncrypted && lastMsg.content.isNotEmpty) {
          // Tampilkan label aman tanpa membebani isolate utama dengan puluhan dekripsi paralel
          lastMessageText = '🔒 Pesan terenkripsi';
        } else if (lastMsg.type == MessageType.image) {
          lastMessageText = '📷 Foto';
        } else if (lastMsg.type == MessageType.voice) {
          lastMessageText = '🎤 Pesan Suara';
        } else if (lastMsg.type == MessageType.location) {
          lastMessageText = '📍 Lokasi';
        } else if (lastMsg.type == MessageType.system) {
          lastMessageText = lastMsg.content;
        } else {
          lastMessageText = lastMsg.content;
        }
        lastMessageTime = lastMsg.createdAt;
      }

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
        final myHistoryCleared = myParticipant?['history_cleared_at'] as String?;
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

    // Sort by last message time
    roomsList.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
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
    if (userId == otherUserId) throw Exception('Cannot create room with yourself');

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
  Stream<List<Message>> streamMessages(String roomId) {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return const Stream.empty();

    final controller = StreamController<List<Message>>();
    StreamSubscription? streamSubscription;

    Future<void> initStream() async {
      DateTime? historyClearedAt;
      try {
        final p = await _supabaseService.client
            .from('room_participants')
            .select('history_cleared_at')
            .eq('room_id', roomId)
            .eq('profile_id', userId)
            .maybeSingle();
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
            .eq('profile_id', userId);
        
        for (var row in hiddenData) {
          hiddenMsgIds.add(row['message_id'] as String);
        }
      } catch (_) {}

      // Guard: jangan subscribe jika stream sudah di-cancel (race condition)
      if (controller.isClosed) return;

      List<Map<String, dynamic>>? pendingBatch;
      bool isProcessing = false;

      Future<void> processBatch(List<Map<String, dynamic>> maps) async {
        try {
          var msgs = maps.map((map) => Message.fromJson(map)).toList();
          if (historyClearedAt != null) {
            msgs = msgs.where((m) => m.createdAt.isAfter(historyClearedAt!)).toList();
          }

          // Filter out silent_deleted, hidden (dari cache in-memory), dan expired messages
          final now = DateTime.now().toUtc();
          msgs = msgs.where((m) {
            if (m.isSilentDeleted || hiddenMsgIds.contains(m.id)) return false;
            if (m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(now)) return false;
            return true;
          }).toList();

          final decryptedMsgs = await Future.wait(msgs.map((m) async {
            if (m.isEncrypted && m.content.isNotEmpty && !m.isDeleted) {
              try {
                final plain = await E2eeService.instance.decryptForRoom(roomId, m.content);
                return m.copyWith(content: plain);
              } catch (_) {
                return m.copyWith(content: E2eeService.undecryptableText);
              }
            }
            return m;
          }));

          if (!controller.isClosed) {
            controller.add(decryptedMsgs);
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

      // Start stream listening ONLY after historyClearedAt is retrieved (fixes race condition)
      streamSubscription = _supabaseService.client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .listen((maps) {
            if (isProcessing) {
              pendingBatch = maps;
              return;
            }
            isProcessing = true;
            processBatch(maps);
          }, onError: (err) {
            if (!controller.isClosed) {
              controller.addError(err);
            }
          });
    }

    controller.onCancel = () {
      streamSubscription?.cancel();
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
  }) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Enkripsi E2EE bila lawan room sudah punya kunci publik;
    // fallback plaintext (is_encrypted=false) HANYA untuk akun lama yang
    // memang belum punya kunci publik E2EE (dipastikan oleh E2eeService).
    // Kegagalan sementara (jaringan/server/kripto) TIDAK dianggap fallback —
    // pengiriman dibatalkan (fail-closed) agar pesan tidak pernah diam-diam
    // terkirim sebagai plaintext akibat error transient.
    var finalContent = content;
    var isEncrypted = false;
    if (content.isNotEmpty) {
      String? envelope;
      try {
        envelope = await E2eeService.instance.encryptForRoom(roomId, content);
      } on E2eeUnavailableException catch (e) {
        throw Exception(
          'Gagal mengenkripsi pesan, pesan tidak dikirim. Coba lagi. ($e)',
        );
      }
      if (envelope != null) {
        finalContent = envelope;
        isEncrypted = true;
      }
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

    return Message.fromJson(response);
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
  Future<void> deleteMessageForEveryone(String messageId) async {
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
  Future<void> hideMessageForMe(String messageId) async {
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

  /// Guard: pesan di chat guardian TIDAK BOLEH diedit untuk menjaga integritas bukti hukum.
  /// Chat normal boleh diedit. Gunakan ini sebelum menampilkan opsi edit di UI.
  bool canEditMessage(Message message, {required bool isGuardianRoom}) {
    if (isGuardianRoom) return false;
    if (message.isDeleted) return false;
    if (message.type != MessageType.text) return false;
    return true;
  }

  /// Edit isi teks pesan. Hanya pengirim di chat non-guardian yang boleh.
  Future<void> editMessage(String messageId, String newContent) async {
    final contentToStore = await _reencryptIfNeeded(messageId, newContent);
    await _supabaseService.client
        .from('messages')
        .update({
          'content': contentToStore,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    try {
      await _supabaseService.client.rpc('update_last_seen');
    } catch (_) {}
  }

  /// Hard-delete messages that have passed their auto_delete_at timestamp.
  /// Best-effort: called from client on chat open. The Supabase cron job
  /// (migration 17) performs the authoritative periodic purge.
  Future<int> purgeExpiredMessages() async {
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
  }

  /// Soft delete Chat Room for current user (hides from list)
  Future<void> deleteChat(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabaseService.client
          .from('room_participants')
          .update({
            'deleted_at': nowIso,
            'history_cleared_at': nowIso,
          })
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
  }

  /// Ambil pengaturan privasi per-room untuk current user.
  Future<RoomParticipantPreferences?> getRoomPreferences(String roomId) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;
    try {
      final row = await _supabaseService.client
          .from('room_participants')
          .select('room_id, is_muted, muted_until, disappearing_override_hours, is_archived')
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
      params: {
        'p_room_id': roomId,
        'p_enabled': enabled,
      },
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
  Future<void> executeRoomBurnOnExit(String roomId) async {
    try {
      await _supabaseService.client.rpc(
        'execute_room_burn_on_exit',
        params: {'p_room_id': roomId},
      );
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
      }
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
          .select('profile_id, role, joined_at, public_profiles(id, username, full_name, display_name, avatar_url)')
          .eq('room_id', roomId)
          .isFilter('deleted_at', null);

      return {
        'room': roomResp,
        'participants': participantsResp,
      };
    } catch (_) {
      return null;
    }
  }

  /// Menambahkan anggota baru ke grup.
  Future<void> addGroupParticipants(String roomId, List<String> profileIds) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final toInsert = profileIds.map((pid) => {
      'room_id': roomId,
      'profile_id': pid,
      'role': 'member',
      'invited_by': userId,
    }).toList();

    await _supabaseService.client
        .from('room_participants')
        .upsert(toInsert);
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


