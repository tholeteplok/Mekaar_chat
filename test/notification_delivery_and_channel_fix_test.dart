import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Channel Migration Constants Tests', () {
    test('NotificationService menggunakan ID channel v2 untuk menghindari OS channel cache', () {
      expect(NotificationService.messageChannelId, equals('mekaar_message_channel_v2'));
      expect(NotificationService.legacyMessageChannelId, equals('mekaar_message_channel'));
    });
  });

  group('MessageNotificationListener.shouldNotify Room Silencing Tests', () {
    const currentUserId = 'user_me';
    const peerUserId = 'user_peer';
    const currentRoomId = 'room_123';
    const otherRoomId = 'room_456';

    test('shouldNotify mengizinkan notifikasi jika activeRoomId bernilai null (berada di luar chat)', () {
      final should = MessageNotificationListener.shouldNotify(
        currentUserId: currentUserId,
        senderId: peerUserId,
        roomId: currentRoomId,
        activeRoomId: null, // Berada di tab Pesan / Kontak / dsb
        isDeleted: false,
      );
      expect(should, isTrue);
    });

    test('shouldNotify mengizinkan notifikasi jika activeRoomId berbeda dengan room pesan masuk', () {
      final should = MessageNotificationListener.shouldNotify(
        currentUserId: currentUserId,
        senderId: peerUserId,
        roomId: currentRoomId,
        activeRoomId: otherRoomId, // Sedang di chat lain
        isDeleted: false,
      );
      expect(should, isTrue);
    });

    test('shouldNotify meredam notifikasi jika user sedang aktif di room yang sama', () {
      final should = MessageNotificationListener.shouldNotify(
        currentUserId: currentUserId,
        senderId: peerUserId,
        roomId: currentRoomId,
        activeRoomId: currentRoomId, // Sedang membuka obrolan ini
        isDeleted: false,
      );
      expect(should, isFalse);
    });

    test('shouldNotify meredam echo pesan diri sendiri', () {
      final should = MessageNotificationListener.shouldNotify(
        currentUserId: currentUserId,
        senderId: currentUserId,
        roomId: currentRoomId,
        activeRoomId: null,
        isDeleted: false,
      );
      expect(should, isFalse);
    });

    test('shouldNotify meredam pesan yang telah dihapus', () {
      final should = MessageNotificationListener.shouldNotify(
        currentUserId: currentUserId,
        senderId: peerUserId,
        roomId: currentRoomId,
        activeRoomId: null,
        isDeleted: true,
      );
      expect(should, isFalse);
    });
  });

  group('activeRoomIdProvider State Management Tests', () {
    test('activeRoomIdProvider mengelola siklus hidup buka dan tutup obrolan', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default: tidak ada room aktif
      expect(container.read(activeRoomIdProvider), isNull);

      // User membuka room A
      container.read(activeRoomIdProvider.notifier).state = 'room_A';
      expect(container.read(activeRoomIdProvider), equals('room_A'));

      // User berpindah ke layar anak / pop kembali
      container.read(activeRoomIdProvider.notifier).state = null;
      expect(container.read(activeRoomIdProvider), isNull);
    });
  });
}
