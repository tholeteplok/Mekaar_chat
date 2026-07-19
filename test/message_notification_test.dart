import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/data/models/notification_preferences.dart';

void main() {
  group('MessageNotificationListener.shouldNotify', () {
    const me = 'user-me';
    const other = 'user-other';
    const roomA = 'room-a';
    const roomB = 'room-b';

    test('memicu notif untuk pesan dari orang lain di room lain', () {
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: me,
          senderId: other,
          roomId: roomB,
          activeRoomId: roomA,
          isDeleted: false,
        ),
        isTrue,
      );
    });

    test('abaikan pesan sendiri (echo broadcast)', () {
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: me,
          senderId: me,
          roomId: roomA,
          activeRoomId: null,
          isDeleted: false,
        ),
        isFalse,
      );
    });

    test('abaikan pesan saat user sedang membuka room tersebut', () {
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: me,
          senderId: other,
          roomId: roomA,
          activeRoomId: roomA,
          isDeleted: false,
        ),
        isFalse,
      );
    });

    test('abaikan pesan yang di-soft-delete', () {
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: me,
          senderId: other,
          roomId: roomB,
          activeRoomId: roomA,
          isDeleted: true,
        ),
        isFalse,
      );
    });
  });

  group('NotificationPreferences default & toggle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default suara & haptik aktif', () {
      const prefs = NotificationPreferences();
      expect(prefs.messageSound, NotificationPreferences.defaultMessageSound);
      expect(prefs.callSound, NotificationPreferences.defaultCallSound);
      expect(prefs.sosSound, NotificationPreferences.defaultSosSound);
      expect(prefs.messageSoundEnabled, isTrue);
      expect(prefs.callSoundEnabled, isTrue);
      expect(prefs.hapticsEnabled, isTrue);
    });

    test('copyWith mematikan haptik & suara panggilan', () {
      final updated = const NotificationPreferences().copyWith(
        hapticsEnabled: false,
        callSoundEnabled: false,
      );
      expect(updated.hapticsEnabled, isFalse);
      expect(updated.callSoundEnabled, isFalse);
      // Lainnya tetap default
      expect(updated.messageSoundEnabled, isTrue);
      expect(updated.messageSound, NotificationPreferences.defaultMessageSound);
    });

    test('key konstan sesuai kontrak SharedPreferences', () {
      expect(NotificationPreferences.hapticsEnabledKey, 'haptics_enabled');
      expect(NotificationPreferences.messageSoundEnabledKey,
          'message_sound_enabled');
      expect(NotificationPreferences.callSoundEnabledKey, 'call_sound_enabled');
    });
  });
}
