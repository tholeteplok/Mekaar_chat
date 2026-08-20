import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';

void main() {
  group('NotificationRoute encode/decode', () {
    test('roundtrip route message', () {
      const route = NotificationRoute(
        type: NotificationRouteType.message,
        roomId: 'room-1',
        chatName: 'Budi',
        isGuardian: true,
        otherUserId: 'user-2',
      );

      final decoded = NotificationRoute.fromPayload(route.encodePayload());

      expect(decoded, isNotNull);
      expect(decoded!.type, NotificationRouteType.message);
      expect(decoded.roomId, 'room-1');
      expect(decoded.chatName, 'Budi');
      expect(decoded.isGuardian, isTrue);
      expect(decoded.otherUserId, 'user-2');
    });

    test('roundtrip route call', () {
      const route = NotificationRoute(
        type: NotificationRouteType.call,
        roomId: 'room-9',
        callId: 'call-42',
        callerId: 'caller-7',
        callerName: 'Sari',
        callerAvatarUrl: 'https://example.com/a.png',
        callType: 'video',
      );

      final decoded = NotificationRoute.fromPayload(route.encodePayload());

      expect(decoded, isNotNull);
      expect(decoded!.type, NotificationRouteType.call);
      expect(decoded.callId, 'call-42');
      expect(decoded.callerId, 'caller-7');
      expect(decoded.callerName, 'Sari');
      expect(decoded.callerAvatarUrl, 'https://example.com/a.png');
      expect(decoded.callType, 'video');
    });

    test('roundtrip route sos', () {
      const route = NotificationRoute(
        type: NotificationRouteType.sos,
        sessionId: 'sos-123',
        userId: 'user-1',
        userName: 'Andi',
      );

      final decoded = NotificationRoute.fromPayload(route.encodePayload());

      expect(decoded, isNotNull);
      expect(decoded!.type, NotificationRouteType.sos);
      expect(decoded.sessionId, 'sos-123');
      expect(decoded.userId, 'user-1');
      expect(decoded.userName, 'Andi');
    });

    test('null fields dipertahankan (tidak menjadi string kosong)', () {
      const route = NotificationRoute(
        type: NotificationRouteType.message,
        roomId: 'room-1',
      );

      final decoded = NotificationRoute.fromPayload(route.encodePayload());

      expect(decoded, isNotNull);
      expect(decoded!.chatName, isNull);
      expect(decoded.otherUserId, isNull);
      expect(decoded.callId, isNull);
    });

    test('payload invalid / bukan JSON → null', () {
      expect(NotificationRoute.fromPayload(null), isNull);
      expect(NotificationRoute.fromPayload(''), isNull);
      expect(NotificationRoute.fromPayload('room-1'), isNull);
      expect(NotificationRoute.fromPayload('{invalid json'), isNull);
      expect(NotificationRoute.fromPayload('{"type":"unknown"}'), isNull);
      expect(NotificationRoute.fromPayload('42'), isNull);
    });
  });
}