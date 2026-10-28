import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/call_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/forwarding_protection_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/forwarding_protection_provider.dart';

class FakeForwardingProtectionRepository extends Fake
    implements ForwardingProtectionRepository {
  bool effectiveProtection = false;

  @override
  Future<RoomForwardingProtection> getRoomState(String roomId) async {
    return RoomForwardingProtection(
      effective: effectiveProtection,
      callerEnabled: effectiveProtection,
      protectorCount: effectiveProtection ? 1 : 0,
      participantCount: 2,
      lastChange: null,
    );
  }
}

class FakeChatRepository extends Fake implements ChatRepository {
  int disappearingHoursToReturn = 0;
  String? lastSentRoomId;
  String? lastSentContent;
  DateTime? lastSentAutoDeleteAt;
  int sendMessageCallCount = 0;

  @override
  bool canForwardMessage(
    Message message, {
    bool forwardingProtectionActive = false,
  }) {
    if (forwardingProtectionActive) return false;
    if (message.type == MessageType.location ||
        message.type == MessageType.system) {
      return false;
    }
    return true;
  }

  @override
  Future<int> getRoomDisappearingHours(String roomId) async {
    return disappearingHoursToReturn;
  }

  @override
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
    sendMessageCallCount++;
    lastSentRoomId = roomId;
    lastSentContent = content;
    lastSentAutoDeleteAt = autoDeleteAt;

    return Message(
      id: 'sent_msg_1',
      roomId: roomId,
      senderId: 'user_1',
      content: content,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      autoDeleteAt: autoDeleteAt,
    );
  }

  @override
  Future<void> updateLastSeen() async {}
}

class FakeCallRepository extends Fake implements CallRepository {}

void main() {
  group('Forwarding Protection & Disappearing Inheritance Unit Tests', () {
    late FakeForwardingProtectionRepository fakeForwardingRepo;
    late FakeChatRepository fakeChatRepo;
    late ProviderContainer container;

    setUp(() {
      fakeForwardingRepo = FakeForwardingProtectionRepository();
      fakeChatRepo = FakeChatRepository();

      container = ProviderContainer(
        overrides: [
          forwardingProtectionRepositoryProvider
              .overrideWithValue(fakeForwardingRepo),
          chatRepositoryProvider.overrideWithValue(fakeChatRepo),
          callRepositoryProvider.overrideWithValue(FakeCallRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    final testMsg = Message(
      id: 'source_msg_1',
      roomId: 'room_source_100',
      senderId: 'other_user',
      content: 'Rahasia Negara',
      type: MessageType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('forwardMessage menolak penerusan jika ruang asal mengaktifkan proteksi penerusan', () async {
      fakeForwardingRepo.effectiveProtection = true;
      final notifier = container.read(chatActionsProvider);

      expect(
        () => notifier.forwardMessage(testMsg, 'room_target_200'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('dilindungi dari penerusan'),
          ),
        ),
      );

      expect(fakeChatRepo.sendMessageCallCount, equals(0));
    });

    test('forwardMessage berhasil dan mewarisi autoDeleteHours dari ruangan tujuan jika proteksi mati', () async {
      fakeForwardingRepo.effectiveProtection = false;
      fakeChatRepo.disappearingHoursToReturn = 24; // Ruangan tujuan diset 24 Jam
      final notifier = container.read(chatActionsProvider);

      await notifier.forwardMessage(testMsg, 'room_target_200');

      expect(fakeChatRepo.sendMessageCallCount, equals(1));
      expect(fakeChatRepo.lastSentRoomId, equals('room_target_200'));
      expect(fakeChatRepo.lastSentContent, equals('Rahasia Negara'));
      expect(fakeChatRepo.lastSentAutoDeleteAt, isNotNull);

      // Verifikasi auto-delete dihitung kira-kira 24 jam ke depan
      final now = DateTime.now();
      final diff = fakeChatRepo.lastSentAutoDeleteAt!.difference(now).inHours;
      expect(diff, inInclusiveRange(23, 24));
    });

    test('forwardMessage menolak pesan bertipe lokasi atau sistem', () async {
      fakeForwardingRepo.effectiveProtection = false;
      final notifier = container.read(chatActionsProvider);

      final locMsg = Message(
        id: 'loc_msg_1',
        roomId: 'room_source_100',
        senderId: 'other_user',
        content: '-6.2,106.8',
        type: MessageType.location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => notifier.forwardMessage(locMsg, 'room_target_200'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('tidak dapat diteruskan'),
          ),
        ),
      );
      expect(fakeChatRepo.sendMessageCallCount, equals(0));
    });
  });
}
