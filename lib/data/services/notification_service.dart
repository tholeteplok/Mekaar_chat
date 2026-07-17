import 'package:logger/logger.dart';
import '../services/supabase_service.dart';

class NotificationService {
  static final Logger _logger = Logger();

  // Notification Masking (blind spot #2): saat true, notifikasi di HP korban
  // disamarkan (teks benign) agar pelaku tidak curiga. Default aktif.
  static bool maskingEnabled = true;

  static Future<void> initialize() async {
    _logger.i("Notification Service Initialized (In-App Fallback Mode)");
  }

  // Shows local notifications inside the app console/snackbars
  static Future<void> showLocalSOSNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    _logger.w("🚨 ALARM PUSH RECEIVED: $title - $body. Data: $data");
  }

  // Notifikasi penyamaran di HP KORBAN: teks benign agar pelaku tidak curiga.
  // (Blind spot #2 — jangan pernah tampilkan status SOS asli di layar korban.)
  static Future<void> showMaskedVictimNotification() async {
    _logger.i("System notification masked (benign OS-update style)");
  }

  // Teks samaran untuk notifikasi korban (tidak mengandung kata SOS/Lokasi/Alarm).
  static const String maskedVictimTitle = 'Pembaruan Sistem Selesai';
  static const String maskedVictimBody = 'Perangkat Anda telah disinkronkan.';

  // Kirim notifikasi darurat ke Guardian. Saat ini menggunakan fallback
  // in-app: menulis baris alert ke tabel security_logs milik guardian agar
  // tampil di log keamanan mereka, dan memancang pesan lewat Realtime.
  // Push FCM/APNs nyata membutuhkan Supabase Edge Function (lihat §6.6).
  static Future<void> sendSOSNotification({
    required String guardianId,
    required String sessionId,
    required bool gps,
    required bool mic,
    required bool video,
  }) async {
    try {
      final client = SupabaseService().client;
      await client.from('security_logs').insert({
        'user_id': guardianId,
        'event_type': 'sos_alert_received',
        'details': {
          'session_id': sessionId,
          'gps_enabled': gps,
          'mic_enabled': mic,
          'video_enabled': video,
        },
      });
      _logger.i(
        "SOS alert dikirim ke Guardian $guardianId (session $sessionId)",
      );
    } catch (e) {
      _logger.e("Gagal mengirim SOS alert ke Guardian $guardianId: $e");
    }
  }
}
