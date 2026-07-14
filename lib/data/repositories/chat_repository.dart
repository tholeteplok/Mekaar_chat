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
      final roomData = row['chat_rooms'] as Map<String, dynamic>;
      final roomType = roomData['room_type'] as String;

      // Get other participant profile
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

      if (otherParticipant != null) {
        final profile = otherParticipant['profiles'] as Map<String, dynamic>;
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
        'unreadCount': 0, // Mock for now, can be updated later
        'isGuardian': isGuardian,
        'otherUserId': otherUserId,
        'otherUsername': otherParticipant != null ? (otherParticipant['profiles'] as Map<String, dynamic>)['username'] : '',
        'otherEmail': otherParticipant != null ? (otherParticipant['profiles'] as Map<String, dynamic>)['email'] : '',
      });
    }

    // Sort by last message time
    roomsList.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    return roomsList;
  }

  // Create normal or guardian chat room
  Future<String> createRoom(String otherUserId, String type) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Check if room already exists
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
      if (checkOther != null) {
        return roomId;
      }
    }

    // Create new room
    final roomResponse = await _supabaseService.client
        .from('chat_rooms')
        .insert({'room_type': type})
        .select()
        .single();
    final roomId = roomResponse['id'] as String;

    // Add participants
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

  // Soft-delete a message (sets is_deleted = true)
  Future<void> deleteMessage(String messageId) async {
    await _supabaseService.client
        .from('messages')
        .update({'is_deleted': true})
        .eq('id', messageId);
  }

  // Restrict forward for SOS location or system log messages
  bool canForwardMessage(Message message) {
    if (message.type == MessageType.location || message.type == MessageType.system) {
      return false;
    }
    return true;
  }
}
