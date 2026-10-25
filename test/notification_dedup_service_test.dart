import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/notification_dedup_service.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationDedupService.reset();
  });

  group('NotificationDedupService Tests', () {
    test('isDuplicate mengembalikan false untuk pesan yang belum pernah dinotifikasi', () {
      expect(NotificationDedupService.isDuplicate('msg_123'), isFalse);
    });

    test('markNotified menandai pesan dan isDuplicate mengembalikan true', () {
      NotificationDedupService.markNotified('msg_123');
      expect(NotificationDedupService.isDuplicate('msg_123'), isTrue);
    });

    test('Dua pesan dengan id berbeda tidak saling mempengaruhi deduplikasi', () {
      NotificationDedupService.markNotified('msg_1');
      expect(NotificationDedupService.isDuplicate('msg_1'), isTrue);
      expect(NotificationDedupService.isDuplicate('msg_2'), isFalse);
    });

    test('reset() membersihkan seluruh rekaman deduplikasi', () {
      NotificationDedupService.markNotified('msg_1');
      NotificationDedupService.markNotified('msg_2');
      expect(NotificationDedupService.isDuplicate('msg_1'), isTrue);

      NotificationDedupService.reset();
      expect(NotificationDedupService.isDuplicate('msg_1'), isFalse);
      expect(NotificationDedupService.isDuplicate('msg_2'), isFalse);
    });
  });

  group('Deterministic Notification ID Tests', () {
    test('getMessageNotificationId menghasilkan integer yang konsisten untuk roomId yang sama', () {
      const roomId = 'room_abc_123';
      final id1 = NotificationService.getMessageNotificationId(roomId);
      final id2 = NotificationService.getMessageNotificationId(roomId);

      expect(id1, equals(id2));
      expect(id1, greaterThan(0));
    });

    test('getMessageNotificationId menghasilkan ID berbeda untuk roomId berbeda', () {
      final idA = NotificationService.getMessageNotificationId('room_alice');
      final idB = NotificationService.getMessageNotificationId('room_bob');

      expect(idA, isNot(equals(idB)));
    });

    test('getMessageNotificationId fallback ke route.roomId jika parameter roomId kosong', () {
      final route = NotificationRoute(
        type: NotificationRouteType.message,
        roomId: 'room_fallback_999',
      );
      final idFromParam = NotificationService.getMessageNotificationId('room_fallback_999');
      final idFromRoute = NotificationService.getMessageNotificationId(null, route);

      expect(idFromRoute, equals(idFromParam));
    });

    test('getMessageNotificationId selalu berada dalam rentang positif 31-bit', () {
      final ids = [
        NotificationService.getMessageNotificationId('room_1'),
        NotificationService.getMessageNotificationId('room_random_very_long_uuid_999999'),
        NotificationService.getMessageNotificationId(null),
      ];

      for (final id in ids) {
        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(1 << 31));
      }
    });
  });
}
