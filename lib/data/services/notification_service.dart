import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import '../services/supabase_service.dart';
import 'alarm_service.dart';
import '../../core/services/haptic_service.dart';

/// Jenis navigasi yang dihasilkan dari tap notifikasi.
enum NotificationRouteType { message, call, sos }

/// Payload terstruktur untuk navigasi saat notifikasi diketuk.
///
/// Dikodekan sebagai JSON di field `payload` local notification maupun data
/// FCM sehingga tap selalu membuka layar yang tepat (chat, panggilan masuk,
/// atau viewer SOS) — bukan hanya membaca roomId.
class NotificationRoute {
  final NotificationRouteType type;

  // Message
  final String? roomId;
  final String? chatName;
  final String? chatAvatarUrl;
  final bool isGuardian;
  final String? otherUserId;

  // Call
  final String? callId;
  final String? callerId;
  final String? callerName;
  final String? callerAvatarUrl;
  final String? callType;

  // SOS
  final String? sessionId;
  final String? userId;
  final String? userName;

  const NotificationRoute({
    required this.type,
    this.roomId,
    this.chatName,
    this.chatAvatarUrl,
    this.isGuardian = false,
    this.otherUserId,
    this.callId,
    this.callerId,
    this.callerName,
    this.callerAvatarUrl,
    this.callType,
    this.sessionId,
    this.userId,
    this.userName,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'roomId': roomId,
        'chatName': chatName,
        'chatAvatarUrl': chatAvatarUrl,
        'isGuardian': isGuardian,
        'otherUserId': otherUserId,
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatarUrl': callerAvatarUrl,
        'callType': callType,
        'sessionId': sessionId,
        'userId': userId,
        'userName': userName,
      };

  String encodePayload() => jsonEncode(toJson());

  static NotificationRoute? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final typeName = decoded['type'] as String?;
      NotificationRouteType? type;
      for (final t in NotificationRouteType.values) {
        if (t.name == typeName) {
          type = t;
          break;
        }
      }
      if (type == null) return null;
      return NotificationRoute(
        type: type,
        roomId: decoded['roomId'] as String?,
        chatName: decoded['chatName'] as String?,
        chatAvatarUrl: decoded['chatAvatarUrl'] as String?,
        isGuardian: decoded['isGuardian'] == true,
        otherUserId: decoded['otherUserId'] as String?,
        callId: decoded['callId'] as String?,
        callerId: decoded['callerId'] as String?,
        callerName: decoded['callerName'] as String?,
        callerAvatarUrl: decoded['callerAvatarUrl'] as String?,
        callType: decoded['callType'] as String?,
        sessionId: decoded['sessionId'] as String?,
        userId: decoded['userId'] as String?,
        userName: decoded['userName'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class NotificationService {
  static const int incomingCallNotificationId = 7001;
  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification Masking (blind spot #2): saat true, notifikasi di HP korban
  // disamarkan (teks benign) agar pelaku tidak curiga. Default aktif.
  static bool maskingEnabled = true;

  /// Callback untuk navigasi saat user mengetuk local notification.
  /// Menerima [NotificationRoute] terstruktur (message/call/sos).
  static Function(NotificationRoute route)? _onNotificationTap;

  /// Callback navigasi khusus notifikasi konfirmasi kedatangan Auto
  /// Check-In (buka TripArrivalConfirmScreen).
  static Function(String tripId)? _onTripNotificationTap;

  /// Callback saat pengguna menekan action button LANGSUNG di notification
  /// tray ("Sudah Sampai"/"Tunda 15 Menit") tanpa membuka app.
  static Function(String tripId, {required bool arrived, int? snoozeMinutes})?
      _onTripAction;

  /// Prefix payload untuk membedakan notifikasi trip dari notifikasi chat biasa.
  static const String _tripPayloadPrefix = 'trip:';

  static Future<void> initialize({
    Function(NotificationRoute route)? onNotificationTap,
    Function(String tripId)? onTripNotificationTap,
    Function(String tripId, {required bool arrived, int? snoozeMinutes})?
        onTripAction,
  }) async {
    _onNotificationTap = onNotificationTap;
    _onTripNotificationTap = onTripNotificationTap;
    _onTripAction = onTripAction;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      _logger.i("Notification Service Initialized (Flutter Local Notifications)");
    } catch (e) {
      _logger.w("Notification Service: Gagal inisialisasi native driver (fallback aktif): $e");
    }
  }

  /// Handler saat user mengetuk local notification ATAU menekan action button.
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (payload.startsWith(_tripPayloadPrefix)) {
      final tripId = payload.substring(_tripPayloadPrefix.length);

      switch (response.actionId) {
        case 'trip_confirm_arrived':
          _logger.i("Trip action: konfirmasi tiba, tripId: $tripId");
          _onTripAction?.call(tripId, arrived: true);
          return;
        case 'trip_snooze_15':
          _logger.i("Trip action: tunda 15 menit, tripId: $tripId");
          _onTripAction?.call(tripId, arrived: false, snoozeMinutes: 15);
          return;
      }

      _logger.i("Local notification tapped, tripId: $tripId");
      _onTripNotificationTap?.call(tripId);
      return;
    }

    _logger.i("Local notification tapped, roomId: $payload");

    // Coba decode payload terstruktur terlebih dahulu.
    final route = NotificationRoute.fromPayload(payload);
    if (route != null) {
      _logger.i("Local notification tapped → ${route.type}");
      _onNotificationTap?.call(route);
      return;
    }

    // Fallback legacy: payload adalah roomId pesan chat.
    _onNotificationTap?.call(
      NotificationRoute(type: NotificationRouteType.message, roomId: payload),
    );
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
    String? roomId,
    NotificationRoute? route,
  }) async {
    AlarmService.playMessageSound();
    await HapticService.trigger(MekaarHapticIntent.success);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mekaar_message_channel',
        'Pesan MEKAAR',
        channelDescription: 'Saluran notifikasi pesan masuk',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
      ),
      iOS: DarwinNotificationDetails(presentSound: false),
    );
    await _localNotificationsPlugin.show(
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      details,
      payload: (route ??
              NotificationRoute(
                type: NotificationRouteType.message,
                roomId: roomId,
              ))
          .encodePayload(),
    );
  }

  static Future<void> showNormalNotification({
    required String title,
    required String body,
  }) => showMessageNotification(title: title, body: body);

  static int _tripNotificationId(String tripId) =>
      0x54524950 ^ tripId.hashCode;

  static Future<void> showTripConfirmationNotification({
    required String tripId,
    required String destinationLabel,
    required int graceMinutes,
  }) async {
    await HapticService.trigger(MekaarHapticIntent.warning);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mekaar_trip_channel',
        'Auto Check-In',
        channelDescription: 'Konfirmasi kedatangan rute perjalanan',
        importance: Importance.high,
        priority: Priority.high,
        actions: const [
          AndroidNotificationAction(
            'trip_confirm_arrived',
            'Sudah Sampai',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'trip_snooze_15',
            'Tunda 15 Menit',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: 'trip_confirmation',
      ),
    );

    await _localNotificationsPlugin.show(
      _tripNotificationId(tripId),
      '📍 Konfirmasi Tiba di $destinationLabel',
      'Waktu perkiraan tiba Anda telah lewat $graceMinutes menit. '
          'Apakah Anda sudah sampai?',
      details,
      payload: '$_tripPayloadPrefix$tripId',
    );
  }

  static Future<void> cancelTripConfirmationNotification(String tripId) =>
      _localNotificationsPlugin.cancel(_tripNotificationId(tripId));

  static Future<void> showIncomingCallNotification({
    required String callerName,
    required String callType,
    String? roomId,
    String? callId,
    String? callerId,
    String? callerAvatarUrl,
    NotificationRoute? route,
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
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(presentSound: false),
    );
    await _localNotificationsPlugin.show(
      incomingCallNotificationId,
      callType == 'video' ? 'Panggilan video masuk' : 'Panggilan masuk',
      callerName,
      details,
      payload: (route ??
              NotificationRoute(
                type: NotificationRouteType.call,
                roomId: roomId,
                callId: callId,
                callerId: callerId,
                callerName: callerName,
                callerAvatarUrl: callerAvatarUrl,
                callType: callType,
              ))
          .encodePayload(),
    );
  }

  static Future<void> cancelIncomingCallNotification() async {
    await AlarmService.stopCallRingtone();
    await _localNotificationsPlugin.cancel(incomingCallNotificationId);
  }

  static Future<void> showLocalSOSNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    NotificationRoute? route,
  }) async {
    final isMasked = maskingEnabled;
    final isVictim = data != null && data['role'] == 'victim';

    if (isMasked && isVictim) {
      _logger.w("🚨 ALARM MASKED (HP KORBAN): menyamarkan notifikasi darurat.");
      await showMaskedVictimNotification();
      return;
    }

    _logger.w("🚨 ALARM PUSH RECEIVED (GUARDIAN): $title - $body. Data: $data");
    await AlarmService.playSOSAlarm();

    const androidDetails = AndroidNotificationDetails(
      'mekaar_sos_channel',
      'Darurat SOS MEKAAR',
      channelDescription: 'Saluran prioritas tinggi untuk alarm SOS darurat',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: false,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotificationsPlugin.show(
      999,
      title,
      body,
      details,
      payload: (route ??
              NotificationRoute(
                type: NotificationRouteType.sos,
                sessionId: data?['sessionId'] as String?,
                userId: data?['userId'] as String?,
                userName: (data?['victimName'] ?? data?['userName']) as String?,
              ))
          .encodePayload(),
    );
  }

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

  static const String maskedVictimTitle = 'Pembaruan Sistem Selesai';
  static const String maskedVictimBody = 'Perangkat Anda telah disinkronkan.';

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

  static Future<void> handleAppLaunchNotification() async {
    try {
      final details = await _localNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse != null) {
        _onDidReceiveNotificationResponse(details.notificationResponse!);
      }
    } catch (e) {
      _logger.w('Error checking app launch notification: $e');
    }
  }
}
