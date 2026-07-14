import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../auth/providers/auth_provider.dart';

// Repository Provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ChatRepository(supabaseService);
});

// Active Room State Provider
final activeRoomIdProvider = StateProvider<String?>((ref) => null);

// Chat Rooms List State Notifier
class ChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final ChatRepository _chatRepository;

  ChatRoomsNotifier(this._chatRepository) : super(const AsyncValue.loading()) {
    refreshRooms();
  }

  Future<void> refreshRooms() async {
    try {
      state = const AsyncValue.loading();
      final rooms = await _chatRepository.getRooms();
      state = AsyncValue.data(rooms);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<String> getOrCreateRoom(String otherUserId, String type) async {
    final roomId = await _chatRepository.createRoom(otherUserId, type);
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

// Stream of messages in a room
final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  roomId,
) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.streamMessages(roomId);
});

// Messages Notifier for actions
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
    int? autoDeleteHours, // 24 hours, 7 days, 30 days
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

    // Refresh rooms list to update last message preview
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> deleteMessage(String messageId) async {
    await _chatRepository.softDeleteMessage(messageId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> markRoomRead(String roomId) async {
    await _chatRepository.markRoomRead(roomId);
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  bool canForward(Message message) {
    return _chatRepository.canForwardMessage(message);
  }
}

final chatActionsProvider = Provider<ChatActionsNotifier>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatActionsNotifier(repo, ref);
});
