import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/models/blocked_user_model.dart';
import 'package:mekaar_chat/core/utils/totp.dart';

void main() {
  group('LastSeenPrivacy', () {
    test('fromValue memetakan nilai DB dengan benar', () {
      expect(LastSeenPrivacy.fromValue('everyone'),
          LastSeenPrivacy.everyone);
      expect(LastSeenPrivacy.fromValue('contacts'),
          LastSeenPrivacy.contacts);
      expect(LastSeenPrivacy.fromValue('nobody'), LastSeenPrivacy.nobody);
    });

    test('fromValue default ke everyone saat null/tidak dikenal', () {
      expect(LastSeenPrivacy.fromValue(null), LastSeenPrivacy.everyone);
      expect(LastSeenPrivacy.fromValue('aneh'), LastSeenPrivacy.everyone);
    });

    test('label tersedia untuk UI', () {
      expect(LastSeenPrivacy.everyone.label, 'Semua orang');
      expect(LastSeenPrivacy.contacts.label, 'Kontak saya');
      expect(LastSeenPrivacy.nobody.label, 'Tidak ada');
    });
  });

  group('Profile privasi', () {
    final baseJson = {
      'id': 'u1',
      'username': 'anna',
      'email': 'anna@mekaar.id',
      'pin_hash': '',
      'full_name': 'Anna',
      'avatar_url': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-02T00:00:00.000Z',
    };

    test('fromJson membaca last_seen_privacy & read_receipts', () {
      final json = {
        ...baseJson,
        'last_seen_privacy': 'contacts',
        'read_receipts_enabled': false,
      };
      final profile = Profile.fromJson(json);
      expect(profile.lastSeenPrivacy, LastSeenPrivacy.contacts);
      expect(profile.readReceiptsEnabled, isFalse);
    });

    test('default saat field tidak ada', () {
      final profile = Profile.fromJson(baseJson);
      expect(profile.lastSeenPrivacy, LastSeenPrivacy.everyone);
      expect(profile.readReceiptsEnabled, isTrue);
    });

    test('toJson menyertakan field privasi', () {
      final profile = Profile.fromJson({...baseJson, 'last_seen_privacy': 'nobody'});
      final json = profile.toJson();
      expect(json['last_seen_privacy'], 'nobody');
      expect(json['read_receipts_enabled'], isTrue);
    });

    test('copyWith mengganti preferensi', () {
      final profile = Profile.fromJson(baseJson);
      final updated = profile.copyWith(readReceiptsEnabled: false);
      expect(updated.readReceiptsEnabled, isFalse);
      expect(updated.lastSeenPrivacy, LastSeenPrivacy.everyone);
    });
  });

  group('BlockedUser', () {
    test('fromJson & toJson', () {
      final json = {
        'blocker_id': 'u1',
        'blocked_id': 'u2',
        'created_at': '2024-01-01T00:00:00.000Z',
      };
      final blocked = BlockedUser.fromJson(json);
      expect(blocked.blockerId, 'u1');
      expect(blocked.blockedId, 'u2');
      final out = blocked.toJson();
      expect(out['blocker_id'], 'u1');
      expect(out['blocked_id'], 'u2');
    });
  });

  group('Profile auto-delete default', () {
    final baseJson = {
      'id': 'u1',
      'username': 'anna',
      'email': 'anna@mekaar.id',
      'pin_hash': '',
      'full_name': 'Anna',
      'avatar_url': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-02T00:00:00.000Z',
    };

    test('default 0 (mati) saat field tidak ada', () {
      final profile = Profile.fromJson(baseJson);
      expect(profile.autoDeleteDefaultHours, 0);
    });

    test('membaca & menulis auto_delete_default_hours', () {
      final profile =
          Profile.fromJson({...baseJson, 'auto_delete_default_hours': 24});
      expect(profile.autoDeleteDefaultHours, 24);
      expect(profile.toJson()['auto_delete_default_hours'], 24);
    });

    test('copyWith mengganti nilai', () {
      final profile = Profile.fromJson(baseJson);
      final updated = profile.copyWith(autoDeleteDefaultHours: 168);
      expect(updated.autoDeleteDefaultHours, 168);
    });
  });

  group('Profile 2FA fields', () {
    final baseJson = {
      'id': 'u1',
      'username': 'anna',
      'email': 'anna@mekaar.id',
      'pin_hash': '',
      'full_name': 'Anna',
      'avatar_url': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-02T00:00:00.000Z',
    };

    test('default 2FA mati saat field tidak ada', () {
      final profile = Profile.fromJson(baseJson);
      expect(profile.twoFaEnabled, isFalse);
      expect(profile.twoFaSecret, isNull);
    });

    test('membaca two_fa_enabled & secret', () {
      final profile = Profile.fromJson({
        ...baseJson,
        'two_fa_enabled': true,
        'two_fa_secret': 'JBSWY3DPEHPK3PXP',
      });
      expect(profile.twoFaEnabled, isTrue);
      expect(profile.twoFaSecret, 'JBSWY3DPEHPK3PXP');
    });
  });

  group('TotpUtil', () {
    test('secret base32 valid & panjang 16', () {
      final secret = TotpUtil.generateSecret();
      expect(secret.length, 16);
      expect(secret, matches(RegExp(r'^[A-Z2-7]+$')));
    });

    test('currentCode terverifikasi oleh verify', () {
      final secret = TotpUtil.generateSecret();
      final code = TotpUtil.currentCode(secret);
      expect(code.length, 6);
      expect(TotpUtil.verify(secret, code), isTrue);
    });

    test('kode salah gagal verifikasi', () {
      final secret = TotpUtil.generateSecret();
      expect(TotpUtil.verify(secret, '000000'), isFalse);
    });

    test('otpAuthUri berisi secret & issuer', () {
      final uri = TotpUtil.otpAuthUri('anna@mekaar.id', 'JBSWY3DPEHPK3PXP');
      expect(uri, contains('JBSWY3DPEHPK3PXP'));
      expect(uri, contains('MEKAAR'));
    });
  });
}

