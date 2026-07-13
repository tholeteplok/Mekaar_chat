import 'package:logger/logger.dart';

class NotificationService {
  static final Logger _logger = Logger();

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

  // Mock function to simulate FCM notification routing via Supabase Edge Function
  static Future<void> sendSOSNotification({
    required String guardianId,
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    _logger.i("Sending SOS Notification payload to Guardian $guardianId for User $userName at ($latitude, $longitude)");
  }
}
