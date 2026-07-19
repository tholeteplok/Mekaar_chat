import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import 'alarm_service.dart';
import '../../core/services/haptic_service.dart';

class NotificationService {
  static const int incomingCallNotificationId = 7001;
  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification Masking (blind spot #2): saat true, notifikasi di HP korban
  // disamarkan (teks benign) agar pelaku tidak curiga. Default aktif.
  static bool maskingEnabled = true;

  static Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _localNotificationsPlugin.initialize(initSettings);
      _logger.i("Notification Service Initialized (Flutter Local Notifications)");
    } catch (e) {
      _logger.w("Notification Service: Gagal inisialisasi native driver (fallback aktif): $e");
    }
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
    String? roomId,
  }) async {
    await AlarmService.playMessageSound();
    // Haptik ringan untuk pesan masuk — hormati toggle "Haptic Feedback".
    // Bukan intent .emergency agar tidak membocorkan status SOS ke korban.
    await HapticService.trigger(MekaarHapticIntent.success);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mekaar_message_channel',
        'Pesan MEKAAR',
        channelDescription: 'Saluran notifikasi pesan masuk',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
      ),
      iOS: DarwinNotificationDetails(presentSound: false),
    );
    await _localNotificationsPlugin.show(
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      details,
      payload: roomId,
    );
  }

  static Future<void> showNormalNotification({
    required String title,
    required String body,
  }) => showMessageNotification(title: title, body: body);

  static Future<void> showIncomingCallNotification({
    required String callerName,
    required String callType,
    String? payload,
  }) async {
    await AlarmService.startCallRingtone();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mekaar_call_channel',
        'Panggilan MEKAAR',
        channelDescription: 'Saluran panggilan suara dan video masuk',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        playSound: false,
      ),
      iOS: DarwinNotificationDetails(presentSound: false),
    );
    await _localNotificationsPlugin.show(
      incomingCallNotificationId,
      callType == 'video' ? 'Panggilan video masuk' : 'Panggilan masuk',
      callerName,
      details,
      payload: payload,
    );
  }

  static Future<void> cancelIncomingCallNotification() async {
    await AlarmService.stopCallRingtone();
    await _localNotificationsPlugin.cancel(incomingCallNotificationId);
  }

  // Menampilkan notifikasi darurat SOS
  static Future<void> showLocalSOSNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isMasked = prefs.getBool('is_notification_masked') ?? true;
    
    // Tentukan apakah perangkat ini adalah korban (pengirim SOS)
    final isVictim = data != null && data['role'] == 'victim';

    if (isMasked && isVictim) {
      // HP KORBAN: tampilkan notifikasi samaran (senyap)
      _logger.w("🚨 ALARM MASKED (HP KORBAN): menyamarkan notifikasi darurat.");
      await showMaskedVictimNotification();
      return;
    }

    // HP GUARDIAN: bunyikan alarm sirine bising & looping
    _logger.w("🚨 ALARM PUSH RECEIVED (GUARDIAN): $title - $body. Data: $data");
    await AlarmService.playSOSAlarm();

    const androidDetails = AndroidNotificationDetails(
      'mekaar_sos_channel',
      'Darurat SOS MEKAAR',
      channelDescription: 'Saluran prioritas tinggi untuk alarm SOS darurat',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // Suara looping keras dikontrol penuh lewat AlarmService
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotificationsPlugin.show(
      999, // ID statis untuk SOS agar menimpa notifikasi sebelumnya
      title,
      body,
      details,
    );
  }

  // Notifikasi penyamaran di HP KORBAN: teks benign agar pelaku tidak curiga.
  // (Blind spot #2 — jangan pernah tampilkan status SOS asli di layar korban.)
  static Future<void> showMaskedVictimNotification() async {
    _logger.i("System notification masked (benign OS-update style)");

    const androidDetails = AndroidNotificationDetails(
      'mekaar_masked_channel',
      'Sinkronisasi Sistem',
      channelDescription: 'Saluran untuk penyamaran notifikasi korban',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotificationsPlugin.show(
      888,
      maskedVictimTitle,
      maskedVictimBody,
      details,
    );
  }

  // Teks samaran untuk notifikasi korban (tidak mengandung kata SOS/Lokasi/Alarm).
  static const String maskedVictimTitle = 'Pembaruan Sistem Selesai';
  static const String maskedVictimBody = 'Perangkat Anda telah disinkronkan.';

  // Catat hasil pengiriman alert sebagai metadata insiden milik pemilik SOS.
  static Future<void> sendSOSNotification({
    required String guardianId,
    required String sessionId,
    required bool gps,
    required bool mic,
    required bool video,
  }) async {
    try {
      final client = SupabaseService().client;
      await client.rpc(
        'log_sos_event',
        params: {
          'target_session_id': sessionId,
          'target_event_type': 'guardian_alert_sent',
          'event_details': {
            'guardian_id': guardianId,
            'gps_enabled': gps,
            'mic_enabled': mic,
            'video_enabled': video,
          },
        },
      );
      _logger.i(
        "SOS alert dikirim ke Guardian $guardianId (session $sessionId)",
      );
    } catch (e) {
      _logger.e("Gagal mengirim SOS alert ke Guardian $guardianId: $e");
    }
  }
}
