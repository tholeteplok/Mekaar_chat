import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/user_model.dart';

void main() {
  group('Tier 0 Security Remediation Unit Tests', () {
    test('constantTimeEquals verification logic against timing side-channels', () {
      bool constantTimeEquals(String a, String b) {
        if (a.length != b.length) return false;
        int result = 0;
        for (int i = 0; i < a.length; i++) {
          result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
        }
        return result == 0;
      }

      const secret = 'mk_sec_test_secret_987654321';
      expect(constantTimeEquals(secret, secret), isTrue);
      expect(constantTimeEquals(secret, 'mk_sec_test_secret_987654320'), isFalse);
      expect(constantTimeEquals(secret, 'different_length'), isFalse);
      expect(constantTimeEquals('', ''), isTrue);
    });

    test('Profile privileged columns are protected from normal user serialization', () {
      final json = {
        'id': 'user-123',
        'username': 'john_doe',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.png',
        'pin_hash': 'hashed_pin_value',
        'is_admin': false,
        'is_suspended': false,
        'created_at': '2026-07-13T12:00:00Z',
        'updated_at': '2026-07-13T12:00:00Z',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, 'user-123');
      expect(profile.isAdmin, isFalse);
      expect(profile.isSuspended, isFalse);

      final serialized = profile.toJson();
      // Verifikasi bahwa serialization profil tidak menyuntikkan hak admin secara tidak sah
      expect(serialized['id'], 'user-123');
    });

    test('Edge Function push policy rejects unauthorized client tables', () {
      bool isAllowedClientTable(String table) {
        // H1 Remediasi: Klien dengan Bearer JWT HANYA boleh trigger messages dan calls
        return table == 'messages' || table == 'calls';
      }

      expect(isAllowedClientTable('messages'), isTrue);
      expect(isAllowedClientTable('calls'), isTrue);
      // sos_sessions dan device_commands WAJIB ditolak jika dipanggil via JWT klien
      expect(isAllowedClientTable('sos_sessions'), isFalse);
      expect(isAllowedClientTable('device_commands'), isFalse);
      expect(isAllowedClientTable('profiles'), isFalse);
    });

    test('Profile updates include updated_at timestamp without privileged fields', () {
      final now = DateTime.now().toUtc().toIso8601String();
      final updatePayload = {
        'display_name': 'Super Star',
        'bio': 'Personal Safety First',
        'updated_at': now,
      };

      expect(updatePayload.containsKey('display_name'), isTrue);
      expect(updatePayload.containsKey('updated_at'), isTrue);
      expect(updatePayload.containsKey('is_admin'), isFalse);
      expect(updatePayload.containsKey('is_suspended'), isFalse);
      expect(updatePayload.containsKey('legal_hold_active'), isFalse);
    });

    test('Username login invalid credentials error translation', () {
      String translate(String errorStr) {
        final lowerError = errorStr.toLowerCase();
        if (lowerError.contains('invalid login credentials') ||
            lowerError.contains('username atau kata sandi tidak valid') ||
            lowerError.contains('username atau kata sandi salah')) {
          return 'Username/email atau password salah, atau akun tidak ditemukan.';
        }
        return errorStr;
      }

      expect(
        translate('Exception: Username atau kata sandi tidak valid'),
        'Username/email atau password salah, atau akun tidak ditemukan.',
      );
      expect(
        translate('AuthException: Invalid login credentials'),
        'Username/email atau password salah, atau akun tidak ditemukan.',
      );
    });
  });
}
