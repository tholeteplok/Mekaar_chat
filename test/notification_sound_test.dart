import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      await prefs.setString('ringtone_normal_key', 'sounds/normal_playful.mp3');
      await prefs.setString('ringtone_sos_key', 'sounds/sos_klaxon.mp3');

      // Ambil nada kustom
      final normalSound = prefs.getString('ringtone_normal_key') ?? 'sounds/normal_chime.mp3';
      final sosSound = prefs.getString('ringtone_sos_key') ?? 'sounds/sos_siren.mp3';

      expect(normalSound, 'sounds/normal_playful.mp3');
      expect(sosSound, 'sounds/sos_klaxon.mp3');
    });

    test('Mengambil nada dering default saat preferensi belum diatur', () async {
      final prefs = await SharedPreferences.getInstance();
      
      final normalSound = prefs.getString('ringtone_normal_key') ?? 'sounds/normal_chime.mp3';
      final sosSound = prefs.getString('ringtone_sos_key') ?? 'sounds/sos_siren.mp3';

      expect(normalSound, 'sounds/normal_chime.mp3');
      expect(sosSound, 'sounds/sos_siren.mp3');
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
