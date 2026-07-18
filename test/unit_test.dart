import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/models/security_log_model.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';

void main() {
  group('Mekaar Data Models Unit Tests', () {
    test('Profile Model serialization & deserialization', () {
      final json = {
        'id': 'user-123',
        'username': 'john_doe',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
        'pin_hash': 'hashed_pin_value',
        'created_at': '2026-07-13T12:00:00Z',
        'updated_at': '2026-07-13T12:00:00Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.username, 'john_doe');
      expect(profile.email, 'john@example.com');
      expect(profile.fullName, 'John Doe');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.pinHash, 'hashed_pin_value');

      final serialized = profile.toJson();
      expect(serialized['id'], 'user-123');
      expect(serialized['username'], 'john_doe');
    });

    test('Message Model handling types & view-once flags', () {
      final now = DateTime.now();
      final json = {
        'id': 'msg-001',
        'room_id': 'chat-100',
        'sender_id': 'user-123',
        'content': 'Halo, ini lokasi saya',
        'media_url': 'https://example.com/media.jpg',
        'msg_type': 'location',
        'is_view_once': true,
        'is_deleted': false,
        'reply_to_id': 'msg-000',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'auto_delete_at': now.add(const Duration(hours: 24)).toIso8601String(),
      };

      final message = Message.fromJson(json);

      expect(message.id, 'msg-001');
      expect(message.type, MessageType.location);
      expect(message.isViewOnce, isTrue);
      expect(message.isDeleted, isFalse);
      expect(message.replyToId, 'msg-000');

      // Test copyWith
      final updated = message.copyWith(isDeleted: true);
      expect(updated.isDeleted, isTrue);
      expect(updated.id, 'msg-001');
    });

    test('Guardian Model active duration checks', () {
      final now = DateTime.now();
      final json = {
        'id': 'relation-001',
        'owner_id': 'user-123',
        'guardian_id': 'user-456',
        'status': 'active',
        'permissions': {'gps': true, 'mic': false},
        'storage_option': 'local',
        // Add 2 hours buffer to guarantee .inDays difference is exactly 20
        'expires_at': now
            .add(const Duration(days: 20, hours: 2))
            .toIso8601String(),
        'created_at': now.subtract(const Duration(days: 10)).toIso8601String(),
        'updated_at': now.subtract(const Duration(days: 10)).toIso8601String(),
        'guardian_profile': {
          'username': 'jane_doe',
          'full_name': 'Jane Doe',
          'email': 'jane@example.com',
          'avatar_url': '',
        },
      };

      final guardian = Guardian.fromJson(json);

      expect(guardian.id, 'relation-001');
      expect(guardian.name, 'Jane Doe');
      expect(guardian.email, 'jane@example.com');
      expect(guardian.permissions['gps'], isTrue);
      expect(guardian.permissions['mic'], isFalse);

      // Verify 30-day expiration math (10 days elapsed -> 20 days remaining)
      expect(guardian.isExpired, isFalse);
      expect(guardian.daysRemaining, 20);
    });

    test('SOSSession Model initialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'sos-session-111',
        'user_id': 'user-123',
        'status': 'active',
        'gps_enabled': true,
        'mic_enabled': true,
        'video_enabled': false,
        'started_at': now.toIso8601String(),
        'ended_at': null,
        'ended_reason': null,
        'created_at': now.toIso8601String(),
      };

      final session = SOSSession.fromJson(json);

      expect(session.id, 'sos-session-111');
      expect(session.status, 'active');
      expect(session.gpsEnabled, isTrue);
      expect(session.micEnabled, isTrue);
      expect(session.videoEnabled, isFalse);
      expect(session.endedReason, isNull);
    });

    test('SecurityLog Model initialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'log-999',
        'user_id': 'user-123',
        'sos_session_id': 'session-456',
        'event_type': 'sos_started',
        'details': {'reason': 'panic_button'},
        'created_at': now.toIso8601String(),
      };

      final log = SecurityLog.fromJson(json);

      expect(log.id, 'log-999');
      expect(log.sosSessionId, 'session-456');
      expect(log.eventType, 'sos_started');
      expect(log.details?['reason'], 'panic_button');
    });
  });

  group('Mekaar Security Logic Unit Tests', () {
    test('SHA-256 PIN Hashing accuracy check', () {
      const pin = '123456';
      final bytes = utf8.encode(pin);
      final hash = sha256.convert(bytes).toString();

      // SHA-256 hash value of "123456" is a known constant
      expect(
        hash,
        '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
      );
    });
  });

  group('PIN Lock Preference Unit Tests', () {
    test('memuat preferensi OFF yang sudah tersimpan', () async {
      SharedPreferences.setMockInitialValues({
        PinLockEnabledNotifier.preferenceKey: false,
      });
      final notifier = PinLockEnabledNotifier();

      await notifier.initialized;

      expect(notifier.state, isFalse);
      notifier.dispose();
    });

    test('toggle menyimpan dan memancarkan nilai baru', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = PinLockEnabledNotifier();
      await notifier.initialized;

      await notifier.toggle(false);
      final prefs = await SharedPreferences.getInstance();

      expect(notifier.state, isFalse);
      expect(prefs.getBool(PinLockEnabledNotifier.preferenceKey), isFalse);
      notifier.dispose();
    });
  });
}
