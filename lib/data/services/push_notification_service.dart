import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'supabase_service.dart';
import 'notification_dedup_service.dart';

/// Top-level background message handler dipanggil oleh Firebase Messaging OS
/// saat aplikasi di-background atau ditutup (terminated state).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    await Firebase.initializeApp();
    await NotificationService.initialize();

    final data = message.data;
    final type = data['type'] as String? ?? 'message';
    final title = data['title'] as String? ?? 'Pesan Baru';
    final body = data['body'] as String? ?? 'Anda menerima pesan baru';
    final roomId = data['roomId'] as String?;

    if (type == 'call') {
      final callerName = data['callerName'] as String? ?? 'Seseorang';
      final callType = data['callType'] as String? ?? 'voice';
      await NotificationService.showIncomingCallNotification(
        callerName: callerName,
        callType: callType,
        payload: roomId,
      );
    } else if (type == 'sos') {
      await NotificationService.showLocalSOSNotification(
        title: title,
        body: body,
        data: data,
      );
    } else {
      await NotificationService.showMessageNotification(
        title: title,
        body: body,
        roomId: roomId,
      );
    }
  } catch (e) {
    Logger().w('Background messaging handler error: $e');
  }
}

class PushNotificationService {
  static final Logger _logger = Logger();
  static FirebaseMessaging? _messaging;

  static Future<void> initialize({
    required Function(String roomId) onNotificationClick,
  }) async {
    // FCM Push notifications hanya didukung di Android & iOS secara native
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _logger.i('PushNotificationService: Platform desktop/web, FCM dilewati.');
      return;
    }

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      // Registrasi handler pesan di latar belakang (background/terminated)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Minta izin notifikasi (iOS & Android 13+)
      final settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _logger.i('FCM Permission status: ${settings?.authorizationStatus}');

      // Ambil token FCM perangkat dan daftarkan ke Supabase
      final token = await _messaging?.getToken();
      if (token != null) {
        await updateFcmTokenInSupabase(token);
      }

      // Dengarkan pembaruan token FCM
      _messaging?.onTokenRefresh.listen((newToken) {
        updateFcmTokenInSupabase(newToken);
      });

      // Re-registrasi token setiap kali user login
      // Mengatasi skenario: fresh install → buka app → login → token belum teregistrasi
      try {
        SupabaseService().client.auth.onAuthStateChange.listen((data) async {
          if (data.event == AuthChangeEvent.signedIn) {
            final token = await _messaging?.getToken();
            if (token != null) {
              await updateFcmTokenInSupabase(token);
              _logger.i('FCM token re-registered after sign-in');
            }
          }
        });
      } catch (e) {
        _logger.w('Gagal setup auth state listener untuk FCM: $e');
      }

      // Penanganan pesan saat aplikasi aktif di layar (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final data = message.data;
        final type = data['type'] as String? ?? 'message';
        final title = data['title'] as String? ?? 'Pesan Baru';
        final body = data['body'] as String? ?? 'Anda menerima pesan baru';
        final roomId = data['roomId'] as String?;

        // Dedup: cek apakah sudah dinotifikasi dari jalur Realtime
        final dedupKey = _getDedupKey(type, data);
        if (dedupKey != null &&
            NotificationDedupService.isDuplicate(dedupKey)) {
          return;
        }
        if (dedupKey != null) {
          NotificationDedupService.markNotified(dedupKey);
        }

        if (type == 'call') {
          final callerName = data['callerName'] as String? ?? 'Seseorang';
          final callType = data['callType'] as String? ?? 'voice';
          NotificationService.showIncomingCallNotification(
            callerName: callerName,
            callType: callType,
            payload: roomId,
          );
        } else if (type == 'sos') {
          NotificationService.showLocalSOSNotification(
            title: title,
            body: body,
            data: data,
          );
        } else {
          NotificationService.showMessageNotification(
            title: title,
            body: body,
            roomId: roomId,
          );
        }
      });

      // Penanganan saat notifikasi diketuk (aplikasi terbuka dari background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final roomId = message.data['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          onNotificationClick(roomId);
        }
      });

      // Penanganan saat notifikasi diketuk (aplikasi terbuka dari mati/terminated)
      final initialMessage = await _messaging?.getInitialMessage();
      if (initialMessage != null) {
        final roomId = initialMessage.data['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          onNotificationClick(roomId);
        }
      }
    } catch (e) {
      _logger.w('PushNotificationService: Inisialisasi fallback (Firebase belum dikonfigurasi native): $e');
    }
  }

  static Future<void> updateFcmTokenInSupabase(String token) async {
    try {
      final client = SupabaseService().client;
      if (client.auth.currentUser != null) {
        await client.rpc('update_fcm_token', params: {'p_token': token});
        _logger.i('FCM token registered in Supabase (length: ${token.length})');
      }
    } catch (e) {
      _logger.w('Gagal menyimpan token FCM ke Supabase: $e');
    }
  }

  /// Generate dedup key berdasarkan tipe notifikasi.
  /// Digunakan untuk mencegah notifikasi ganda dari Realtime + FCM.
  static String? _getDedupKey(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'message':
        final msgId = data['messageId'] as String?;
        if (msgId != null) return 'msg_$msgId';
        // Fallback: gunakan roomId + timestamp
        final roomId = data['roomId'] as String?;
        return roomId != null
            ? 'msg_fcm_${roomId}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}'
            : null;
      case 'call':
        final roomId = data['roomId'] as String?;
        return roomId != null ? 'call_$roomId' : null;
      case 'sos':
        final sessionId = data['sessionId'] as String?;
        return sessionId != null ? 'sos_$sessionId' : null;
      default:
        return null;
    }
  }
}
