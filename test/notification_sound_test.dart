import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/models/notification_preferences.dart';
import 'package:mekaar_chat/data/repositories/notification_preferences_repository.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Sistem Notifikasi & Penyamaran (Masking)', () {
    test('Nilai default masking adalah pembaruan sistem yang disamarkan', () {
      expect(NotificationService.maskedVictimTitle, 'Pembaruan Sistem Selesai');
      expect(NotificationService.maskedVictimBody, 'Perangkat Anda telah disinkronkan.');
    });

    test('Membaca SharedPreferences untuk status masking', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_notification_masked', false);
      
      final isMasked = prefs.getBool('is_notification_masked') ?? true;
      expect(isMasked, isFalse);
    });

    test('Membaca SharedPreferences untuk nada dering kustom', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Set nada kustom
      await prefs.setString(NotificationPreferences.legacyNormalSoundKey, NotificationPreferences.alternateMessageSound);
      await prefs.setString(NotificationPreferences.sosSoundKey, NotificationPreferences.alternateSosSound);

      // Ambil nada kustom
      final normalSound = prefs.getString(NotificationPreferences.legacyNormalSoundKey) ?? NotificationPreferences.defaultMessageSound;
      final sosSound = prefs.getString(NotificationPreferences.sosSoundKey) ?? NotificationPreferences.defaultSosSound;

      expect(normalSound, NotificationPreferences.alternateMessageSound);
      expect(sosSound, NotificationPreferences.alternateSosSound);
    });

    test('Mengambil nada dering default saat preferensi belum diatur', () async {
      final prefs = await SharedPreferences.getInstance();
      
      final normalSound = prefs.getString(NotificationPreferences.legacyNormalSoundKey) ?? NotificationPreferences.defaultMessageSound;
      final sosSound = prefs.getString(NotificationPreferences.sosSoundKey) ?? NotificationPreferences.defaultSosSound;

      expect(normalSound, NotificationPreferences.defaultMessageSound);
      expect(sosSound, NotificationPreferences.defaultSosSound);
    });

    test('Migrasi otomatis preferensi file audio lama (.mp3) ke format baru (.wav)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(NotificationPreferences.messageSoundKey, 'sounds/normal_chime.mp3');
      await prefs.setString(NotificationPreferences.callSoundKey, 'sounds/normal_playful.mp3');
      await prefs.setString(NotificationPreferences.sosSoundKey, 'sounds/sos_siren.mp3');

      final repo = NotificationPreferencesRepository();
      final loaded = await repo.load();

      expect(loaded.messageSound, NotificationPreferences.defaultMessageSound);
      expect(loaded.callSound, NotificationPreferences.defaultCallSound);
      expect(loaded.sosSound, NotificationPreferences.defaultSosSound);
    });

    test('Membaca dan menyimpan SharedPreferences untuk perizinan alarm Guardian', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Default harus true jika belum diatur
      final defaultValue = prefs.getBool('allow_guardian_alarm') ?? true;
      expect(defaultValue, isTrue);

      // Set ke false
      await prefs.setBool('allow_guardian_alarm', false);
      final updatedValue = prefs.getBool('allow_guardian_alarm') ?? true;
      expect(updatedValue, isFalse);
    });
  });
}
