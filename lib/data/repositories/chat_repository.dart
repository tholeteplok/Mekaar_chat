import '../models/message_model.dart';
import '../services/supabase_service.dart';

class ChatRepository {
  final SupabaseService _supabaseService;

  ChatRepository(this._supabaseService);

  // Get active chat rooms for current user
  Future<List<Map<String, dynamic>>> getRooms() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return [];

    // Get rooms the current user participates in
    final roomsResponse = await _supabaseService.client
        .from('room_participants')
        .select('room_id, chat_rooms(id, room_type)')
        .eq('profile_id', userId);

    final List<Map<String, dynamic>> roomsList = [];

    for (final row in roomsResponse) {
      final roomId = row['room_id'] as String;
      final roomData = row['chat_rooms'] as Map<String, dynamic>?;
      if (roomData == null) continue;
      final roomType = roomData['room_type'] as String;

      // Get other participant profile. Select only public fields; never request pin_hash.
      final otherParticipant = await _supabaseService.client
          .from('room_participants')
          .select('profile_id, profiles(id, username, full_name, email, avatar_url)')
          .eq('room_id', roomId)
          .neq('profile_id', userId)
          .maybeSingle();

      String chatName = 'Saved Messages';
      String chatAvatar = '';
      String otherUserId = userId;
      bool isGuardian = (roomType == 'guardian');
      Map<String, dynamic>? profile;

      if (otherParticipant != null && otherParticipant['profiles'] != null) {
        profile = otherParticipant['profiles'] as Map<String, dynamic>;
        chatName = profile['full_name'] as String? ?? profile['username'] as String? ?? 'User';
        chatAvatar = chatName.isNotEmpty ? chatName[0] : 'U';
        otherUserId = profile['id'] as String;
      }

      // Get last message in the room
      final lastMsgResponse = await _supabaseService.client
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String lastMessageText = 'Mulai percakapan...';
      DateTime lastMessageTime = DateTime.now();

      if (lastMsgResponse != null) {
        final lastMsg = Message.fromJson(lastMsgResponse);
        if (lastMsg.isDeleted) {
          lastMessageText = 'Pesan telah dihapus';
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

      roomsList.add({
        'id': roomId,
        'name': chatName,
        'avatar': chatAvatar,
        'lastMessage': lastMessageText,
        'timestamp': lastMessageTime,
        'unreadCount': 0,
        'isGuardian': isGuardian,
        'otherUserId': otherUserId,
        'otherUsername': profile?['username'] ?? '',
        'otherEmail': profile?['email'] ?? '',
      });
    }

    // Sort by last message time
    roomsList.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    return roomsList;
  }

  // Create normal or guardian chat room atomically via RPC.
  Future<String> createRoom(String otherUserId, String type) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    try {
      final response = await _supabaseService.client.rpc(
        'get_or_create_direct_room',
        params: {
          'other_user_id': otherUserId,
          'requested_room_type': type,
        },
      );
      if (response is String && response.isNotEmpty) return response;
    } catch (_) {
      // Fallback keeps local MVP usable before the additive migration is applied.
    }

    return _createRoomFallback(otherUserId, type);
  }

  Future<String> _createRoomFallback(String otherUserId, String type) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    if (userId == otherUserId) throw Exception('Cannot create room with yourself');

    final checkQuery = await _supabaseService.client
        .from('room_participants')
        .select('room_id, chat_rooms!inner(room_type)')
        .eq('profile_id', userId)
        .eq('chat_rooms.room_type', type);

    for (final row in checkQuery) {
      final roomId = row['room_id'] as String;
      final checkOther = await _supabaseService.client
          .from('room_participants')
          .select()
          .eq('room_id', roomId)
          .eq('profile_id', otherUserId)
          .maybeSingle();
      if (checkOther != null) return roomId;
    }

    final roomResponse = await _supabaseService.client
        .from('chat_rooms')
        .insert({'room_type': type})
        .select()
        .single();
    final roomId = roomResponse['id'] as String;

    await _supabaseService.client.from('room_participants').insert([
      {'room_id': roomId, 'profile_id': userId},
      {'room_id': roomId, 'profile_id': otherUserId},
    ]);

    return roomId;
  }

  // Stream messages in a specific room
  Stream<List<Message>> streamMessages(String roomId) {
    return _supabaseService.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) => maps.map((map) => Message.fromJson(map)).toList());
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

    final data = {
      'room_id': roomId,
      'sender_id': userId,
      'content': content,
      'media_url': mediaUrl,
      'msg_type': type.name,
      'is_view_once': isViewOnce,
      'reply_to_id': replyToId,
      'auto_delete_at': autoDeleteAt?.toIso8601String(),
    };

    final response = await _supabaseService.client
        .from('messages')
        .insert(data)
        .select()
        .single();

    return Message.fromJson(response);
  }

  // Soft-delete a message through RPC so guardian rooms keep an evidence snapshot.
  Future<void> softDeleteMessage(String messageId) async {
    try {
      await _supabaseService.client.rpc(
        'soft_delete_message',
        params: {'message_uuid': messageId},
      );
      return;
    } catch (_) {
      // Fallback for dev DBs before 05_security_hardening.sql is applied.
    }

    await _supabaseService.client
        .from('messages')
        .update({
          'is_deleted': true,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) => softDeleteMessage(messageId);

  Future<void> markRoomRead(String roomId) async {
    try {
      await _supabaseService.client.rpc(
        'mark_room_read',
        params: {'room_uuid': roomId},
      );
    } catch (_) {
      final userId = _supabaseService.currentUserId;
      if (userId == null) return;
      await _supabaseService.client
          .from('room_participants')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('room_id', roomId)
          .eq('profile_id', userId);
    }
  }

  // Search user profile by username or email through a limited public RPC.
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
      // Fallback keeps local MVP usable before the additive migration is applied.
    }

    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('id, username, full_name, email, avatar_url')
          .or('username.eq.$cleanQuery,email.eq.$cleanQuery')
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  bool canForwardMessage(Message message) {
    if (message.type == MessageType.location || message.type == MessageType.system) {
      return false;
    }
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
}
