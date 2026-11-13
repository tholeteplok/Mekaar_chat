import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/device_lost_model.dart';
import 'package:mekaar_chat/data/services/alarm_service.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Lost & Guardian-Assisted Recovery Tests', () {
    test('DeviceLostState serializes and deserializes correctly', () {
      final state = DeviceLostState(
        isLocked: true,
        lockMessage: 'Ponsel tertinggal di taksi.',
        recoveryContact: '08123456789',
        lockedAt: DateTime.utc(2026, 11, 13, 10, 0, 0),
      );

      final json = state.toJson();
      expect(json['is_locked'], isTrue);
      expect(json['lock_message'], 'Ponsel tertinggal di taksi.');
      expect(json['recovery_contact'], '08123456789');
      expect(json['locked_at'], '2026-11-13T10:00:00.000Z');

      final fromJson = DeviceLostState.fromJson(json);
      expect(fromJson.isLocked, isTrue);
      expect(fromJson.lockMessage, 'Ponsel tertinggal di taksi.');
      expect(fromJson.recoveryContact, '08123456789');
      expect(fromJson.lockedAt, DateTime.utc(2026, 11, 13, 10, 0, 0));
    });

    test('AlarmService initial state and stopAlarm behaves safely', () async {
      expect(AlarmService.isSosAlarmPlaying, isFalse);
      expect(AlarmService.isCallRingtonePlaying, isFalse);
      expect(AlarmService.isPlaying, isFalse);

      // Memastikan stopAlarm tidak crash saat audio tidak sedang berputar
      await AlarmService.stopAlarm();
      expect(AlarmService.isPlaying, isFalse);
    });

    test('NotificationService device lost constants are properly defined', () {
      expect(NotificationService.deviceLostNotificationId, 8001);
      expect(NotificationService.actionDeviceLostCall, 'device_lost_call');
    });
  });
}
