import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/notification_preferences_repository.dart';
import '../services/supabase_service.dart';
import 'alarm_service.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/haptic_service.dart';
import '../../core/widgets/mekaar_in_app_notification_banner.dart';

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
  final String? chatAvatar;
  final String? chatAvatarUrl;
  final bool isGuardian;
  final String? otherUserId;
  final bool isGroup;
  final String? groupName;

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
    this.chatAvatar,
    this.chatAvatarUrl,
    this.isGuardian = false,
    this.otherUserId,
    this.isGroup = false,
    this.groupName,
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
    'chatAvatar': chatAvatar,
    'chatAvatarUrl': chatAvatarUrl,
    'isGuardian': isGuardian,
    'otherUserId': otherUserId,
    'isGroup': isGroup,
    'groupName': groupName,
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
        chatAvatar: decoded['chatAvatar'] as String?,
        chatAvatarUrl: decoded['chatAvatarUrl'] as String?,
        isGuardian: decoded['isGuardian'] == true,
        otherUserId: decoded['otherUserId'] as String?,
        isGroup: decoded['isGroup'] == true,
        groupName: decoded['groupName'] as String?,
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
  static const int deviceLostNotificationId = 8001;
  static const String actionCallAccept = 'call_accept';
  static const String actionCallDecline = 'call_decline';
  static const String actionDeviceLostCall = 'device_lost_call';
  static const String _deviceLostPayloadPrefix = 'devicelost:';
  static const String messageChannelId = 'mekaar_message_channel_v3';
  static const String groupMessageChannelId = 'mekaar_group_message_channel_v1';
  static const String legacyMessageChannelId = 'mekaar_message_channel_v2';
  static const String legacyOldMessageChannelId = 'mekaar_message_channel';
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

  /// Callback khusus saat pengguna menekan tombol aksi "Jawab" atau "Tolak" pada notifikasi panggilan masuk.
  static Function(NotificationRoute route, {required bool accept})?
  _onCallAction;

  /// Prefix payload untuk membedakan notifikasi trip dari notifikasi chat biasa.
  static const String _tripPayloadPrefix = 'trip:';

  static Future<void> initialize({
    Function(NotificationRoute route)? onNotificationTap,
    Function(String tripId)? onTripNotificationTap,
    Function(String tripId, {required bool arrived, int? snoozeMinutes})?
    onTripAction,
    Function(NotificationRoute route, {required bool accept})? onCallAction,
  }) async {
    _onNotificationTap = onNotificationTap;
    _onTripNotificationTap = onTripNotificationTap;
    _onTripAction = onTripAction;
    _onCallAction = onCallAction;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      await _createNotificationChannels();

      // Minta izin notifikasi runtime Android 13+ (POST_NOTIFICATIONS)
      final androidImpl = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();

      _logger.i(
        "Notification Service Initialized (Flutter Local Notifications)",
      );
    } catch (e) {
      _logger.w(
        "Notification Service: Gagal inisialisasi native driver (fallback aktif): $e",
      );
    }
  }

  /// Mendaftarkan Android Notification Channels secara eksplisit agar sistem OS
  /// memberikan prioritas tinggi, getaran, dan suara saat aplikasi di background/ditutup.
  static Future<void> _createNotificationChannels() async {
    final androidImpl = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return;

    try {
      // 1. Channel Panggilan Masuk (Max Importance, bergetar berulang)
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'mekaar_call_channel',
          'Panggilan MEKAAR',
          description: 'Saluran panggilan suara dan video masuk',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 1000, 1000, 1000]),
        ),
      );

      // Hapus channel pesan legacy agar cache low/default importance dari OS direset
      try {
        await androidImpl.deleteNotificationChannel(legacyOldMessageChannelId);
      } catch (_) {}
      try {
        await androidImpl.deleteNotificationChannel(legacyMessageChannelId);
      } catch (_) {}

      // 2. Channel Pesan Masuk v3 (High Importance, suara & getar default)
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          messageChannelId,
          'Pesan MEKAAR',
          description: 'Saluran notifikasi pesan masuk pribadi',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // 2b. Channel Pesan Grup v1 (High Importance, terpisah untuk kustomisasi grup)
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          groupMessageChannelId,
          'Pesan Grup MEKAAR',
          description: 'Saluran notifikasi obrolan grup',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // 3. Channel Darurat SOS (Max Importance)
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'mekaar_sos_channel',
          'Darurat & SOS MEKAAR',
          description: 'Saluran peringatan darurat dan SOS',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (e) {
      _logger.w('Gagal membuat notification channels Android: $e');
    }
  }

  /// Handler saat user mengetuk local notification ATAU menekan action button.
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // Tangani aksi panggilan "Jawab" atau "Tolak" langsung dari notification tray
    if (response.actionId == actionCallAccept ||
        response.actionId == actionCallDecline) {
      final route = NotificationRoute.fromPayload(payload);
      if (route != null) {
        final isAccept = response.actionId == actionCallAccept;
        _logger.i(
          'Call notification action: ${isAccept ? "Accept" : "Decline"}, callId: ${route.callId}',
        );
        cancelIncomingCallNotification();
        _onCallAction?.call(route, accept: isAccept);
        return;
      }
    }

    // Tangani aksi panggilan telepon dari notifikasi Device Lost
    if (response.actionId == actionDeviceLostCall ||
        (payload.startsWith(_deviceLostPayloadPrefix) &&
            response.actionId != null)) {
      final contactNumber = payload.startsWith(_deviceLostPayloadPrefix)
          ? payload.substring(_deviceLostPayloadPrefix.length)
          : '';
      if (contactNumber.isNotEmpty) {
        _logger.i(
          'Device lost notification: memanggil kontak pemulihan $contactNumber',
        );
        try {
          final uri = Uri.parse('tel:$contactNumber');
          launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          _logger.e('Gagal memicu dialer dari notifikasi: $e');
        }
        return;
      }
    }

    if (payload.startsWith(_deviceLostPayloadPrefix)) {
      _logger.i('Device lost notification diketuk, membuka lock screen');
      final context = AppNavigator.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pushNamed(AppRoutes.deviceLostLock);
      }
      return;
    }

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

  /// Algoritma hashing 32-bit yang identik dengan `java.lang.String.hashCode()`.
  /// Memastikan hasil integer hash antara Dart dan Kotlin Android menghasilkan ID yang sama.
  static int _javaHashCode(String s) {
    var h = 0;
    for (var i = 0; i < s.length; i++) {
      h = (31 * h + s.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    if (h >= 0x80000000) {
      h -= 0x100000000;
    }
    return h;
  }

  /// Menghitung ID notifikasi deterministik berbasis roomId atau route.
  /// Memastikan notifikasi baru dalam percakapan yang sama saling menimpa
  /// (in-place update) di status bar dan tidak memunculkan notifikasi ganda.
  static int getMessageNotificationId(
    String? roomId, [
    NotificationRoute? route,
  ]) {
    final effectiveKey = (roomId != null && roomId.isNotEmpty)
        ? 'room_$roomId'
        : (route?.roomId != null && route!.roomId!.isNotEmpty)
        ? 'room_${route.roomId}'
        : (route?.chatName ?? 'mekaar_msg');
    final rawId = _javaHashCode(effectiveKey).abs() % (1 << 31);
    return rawId == 0 ? 1 : rawId;
  }

  /// Override status izin notifikasi sistem OS (khusus unit/widget testing).
  @visibleForTesting
  static bool? overrideNotificationsEnabled;

  /// Memeriksa apakah notifikasi aplikasi diizinkan oleh sistem operasi Android/iOS.
  static Future<bool> areNotificationsEnabled() async {
    if (overrideNotificationsEnabled != null) {
      return overrideNotificationsEnabled!;
    }

    try {
      if (Platform.isAndroid) {
        final androidImpl = _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final areEnabled = await androidImpl?.areNotificationsEnabled();
        if (areEnabled != null) return areEnabled;
        return await Permission.notification.status.isGranted;
      } else if (Platform.isIOS) {
        return await Permission.notification.status.isGranted;
      }
      return true;
    } catch (e) {
      _logger.w('Gagal memeriksa status izin notifikasi OS: $e');
      return true;
    }
  }

  /// Batalkan notifikasi pesan untuk [roomId] tertentu (misal saat room dibuka).
  static Future<void> cancelMessageNotification(String roomId) async {
    final notificationId = getMessageNotificationId(roomId);
    try {
      await _localNotificationsPlugin.cancel(notificationId);
    } catch (_) {}
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        const MethodChannel('com.mekaar.mekaar_chat/call_intent')
            .invokeMethod('cancelMessageNotification', {'roomId': roomId});
      } catch (_) {}
    }
  }

  /// Batalkan seluruh notifikasi pesan (misal saat seluruh pesan terbaca / badge 0).
  static Future<void> cancelAllMessageNotifications() async {
    try {
      await _localNotificationsPlugin.cancelAll();
    } catch (_) {}
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        const MethodChannel('com.mekaar.mekaar_chat/call_intent')
            .invokeMethod('cancelAllMessageNotifications');
      } catch (_) {}
    }
  }

  /// Membuka halaman Pengaturan Notifikasi Sistem Android untuk aplikasi atau channel pesan.
  /// Memungkinkan pengguna mengatur nada dering dan preferensi notifikasi langsung di pengaturan OS.
  static Future<bool> openSystemNotificationSettings({String? channelId}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await const MethodChannel('com.mekaar.mekaar_chat/call_intent')
            .invokeMethod('openNotificationSettings', {
          'channelId': channelId ?? messageChannelId,
        });
        return result == true;
      } catch (e) {
        _logger.w('Gagal membuka pengaturan notifikasi sistem: $e');
        return false;
      }
    }
    return false;
  }

  static Future<void> showMessageNotification({
    required String title,
    required String body,
    String? roomId,
    NotificationRoute? route,
    String? groupKey,
    bool isGroup = false,
    String? groupName,
    String? senderName,
  }) async {
    // 1. Jika ini notifikasi grup, hormati preferensi switch on/off grup pengguna
    if (isGroup) {
      try {
        final prefs = await NotificationPreferencesRepository().load();
        if (!prefs.groupNotificationsEnabled) {
          _logger.d(
            'Notifikasi grup dinonaktifkan oleh pengguna. Drop notifikasi untuk room $roomId.',
          );
          return;
        }
      } catch (_) {}
    }

    final systemNotificationsEnabled = await areNotificationsEnabled();

    final effectiveRoute =
        route ??
        NotificationRoute(
          type: NotificationRouteType.message,
          roomId: roomId,
          isGroup: isGroup,
          groupName: groupName,
        );

    if (!systemNotificationsEnabled) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final isForeground =
          lifecycle == null || lifecycle == AppLifecycleState.resumed;

      if (isForeground) {
        MekaarInAppNotificationBanner.show(
          title: title,
          body: body,
          avatarInitial: effectiveRoute.chatAvatar,
          avatarUrl: effectiveRoute.chatAvatarUrl,
          isGroup: isGroup,
          groupName: groupName,
          onTap: () {
            _onNotificationTap?.call(effectiveRoute);
          },
        );
      }
      return;
    }

    // Suara notifikasi pesan murni mengikuti nada dering default sistem Android OS
    // melalui NotificationChannel terpisah, tidak diputar manual
    // via AlarmService agar patuh pada pengaturan nada & profil suara sistem ponsel.
    await HapticService.trigger(MekaarHapticIntent.success);

    final notificationId = getMessageNotificationId(roomId, route);
    final targetChannelId =
        isGroup ? groupMessageChannelId : messageChannelId;
    final targetChannelName = isGroup ? 'Pesan Grup MEKAAR' : 'Pesan MEKAAR';
    final targetChannelDesc = isGroup
        ? 'Saluran notifikasi obrolan grup'
        : 'Saluran notifikasi pesan masuk pribadi';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        targetChannelId,
        targetChannelName,
        channelDescription: targetChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
        color: const Color(0xFF007AFF),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: isGroup ? (groupName ?? 'Grup MEKAAR') : 'MEKAAR',
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _localNotificationsPlugin.show(
        notificationId,
        title,
        body,
        details,
        payload: effectiveRoute.encodePayload(),
      );
    } catch (e) {
      _logger.e("NotificationService: Gagal menampilkan notifikasi pesan: $e");
    }
  }

  static Future<void> showMissedCallNotification({
    required String callerName,
    required String callType,
    String? roomId,
    String? callId,
    String? callerId,
  }) async {
    final systemNotificationsEnabled = await areNotificationsEnabled();
    if (!systemNotificationsEnabled) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final isForeground =
          lifecycle == null || lifecycle == AppLifecycleState.resumed;

      if (isForeground) {
        final route = NotificationRoute(
          type: NotificationRouteType.message,
          roomId: roomId,
          chatName: callerName,
          otherUserId: callerId,
        );
        MekaarInAppNotificationBanner.show(
          title: 'Panggilan Tak Terjawab',
          body:
              '$callerName mencoba menghubungi Anda (${callType == "video" ? "Video" : "Suara"})',
          avatarInitial: callerName.isNotEmpty
              ? callerName[0].toUpperCase()
              : 'U',
          onTap: () {
            _onNotificationTap?.call(route);
          },
        );
      }
      return;
    }

    await HapticService.trigger(MekaarHapticIntent.warning);

    final effectiveKey = (callId != null && callId.isNotEmpty)
        ? 'missed_call_$callId'
        : (roomId != null && roomId.isNotEmpty)
        ? 'missed_room_$roomId'
        : 'missed_call';
    final rawId = effectiveKey.hashCode.abs().remainder(1 << 31);
    final notificationId = rawId == 0 ? 1 : rawId;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        messageChannelId,
        'Pesan MEKAAR',
        channelDescription: 'Saluran notifikasi pesan dan panggilan masuk',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.missedCall,
        color: const Color(0xFFFF3B30),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _localNotificationsPlugin.show(
        notificationId,
        'Panggilan Tak Terjawab',
        '$callerName mencoba menghubungi Anda (${callType == "video" ? "Video" : "Suara"})',
        details,
        payload: NotificationRoute(
          type: NotificationRouteType.message,
          roomId: roomId,
          chatName: callerName,
          otherUserId: callerId,
        ).encodePayload(),
      );
    } catch (e) {
      _logger.e(
        "NotificationService: Gagal menampilkan notifikasi panggilan tak terjawab: $e",
      );
    }
  }

  static Future<void> showNormalNotification({
    required String title,
    required String body,
  }) => showMessageNotification(title: title, body: body);

  static int _tripNotificationId(String tripId) => 0x54524950 ^ tripId.hashCode;

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
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mekaar_call_channel',
        'Panggilan MEKAAR',
        channelDescription: 'Saluran panggilan suara dan video masuk',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 1000, 1000, 1000]),
        fullScreenIntent: true,
        actions: const [
          AndroidNotificationAction(
            actionCallAccept,
            'Jawab',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            actionCallDecline,
            'Tolak',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'incoming_call',
      ),
    );
    await _localNotificationsPlugin.show(
      incomingCallNotificationId,
      callType == 'video' ? 'Panggilan video masuk' : 'Panggilan masuk',
      callerName,
      details,
      payload:
          (route ??
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
    const iosDetails = DarwinNotificationDetails(presentSound: false);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      999,
      title,
      body,
      details,
      payload:
          (route ??
                  NotificationRoute(
                    type: NotificationRouteType.sos,
                    sessionId: data?['sessionId'] as String?,
                    userId: data?['userId'] as String?,
                    userName:
                        (data?['victimName'] ?? data?['userName']) as String?,
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
    const iosDetails = DarwinNotificationDetails(presentSound: false);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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

  /// Menampilkan notifikasi persisten di lock screen (ongoing, public, high priority)
  /// saat mode ponsel tertinggal/hilang diaktifkan (baik oleh pemilik maupun Guardian).
  ///
  /// Dilengkapi tombol aksi cepat untuk langsung memanggil nomor pemulihan (Guardian).
  static Future<void> showDeviceLostNotification({
    required String lockMessage,
    String? recoveryContact,
    String? ownerName,
  }) async {
    try {
      final cleanContact = recoveryContact?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
      final hasContact = cleanContact.isNotEmpty;

      final androidDetails = AndroidNotificationDetails(
        'mekaar_sos_channel',
        'Darurat & SOS MEKAAR',
        channelDescription:
            'Saluran peringatan darurat dan pemulihan ponsel tertinggal',
        importance: Importance.max,
        priority: Priority.max,
        ongoing: true,
        autoCancel: false,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        color: const Color(0xFFE53935), // MekaarColors.sosRed
        actions: hasContact
            ? [
                const AndroidNotificationAction(
                  actionDeviceLostCall,
                  '📞 Telepon Guardian / Pemilik',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ]
            : null,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      const title = '⚠️ MODE PONSEL TERTINGGAL AKTIF';
      final body = hasContact
          ? '$lockMessage\nHubungi: $cleanContact'
          : lockMessage;

      final payload = '$_deviceLostPayloadPrefix$cleanContact';

      await _localNotificationsPlugin.show(
        deviceLostNotificationId,
        title,
        body,
        details,
        payload: payload,
      );
      _logger.i(
        'NotificationService: Notifikasi Device Lost berhasil ditampilkan di lockscreen.',
      );
    } catch (e) {
      _logger.e(
        'NotificationService: Gagal menampilkan notifikasi Device Lost: $e',
      );
    }
  }

  /// Membatalkan notifikasi Device Lost saat perangkat dibuka kunci atau dinonaktifkan.
  static Future<void> cancelDeviceLostNotification() async {
    try {
      await _localNotificationsPlugin.cancel(deviceLostNotificationId);
      _logger.i('NotificationService: Notifikasi Device Lost dibatalkan.');
    } catch (e) {
      _logger.w(
        'NotificationService: Gagal membatalkan notifikasi Device Lost: $e',
      );
    }
  }
}
