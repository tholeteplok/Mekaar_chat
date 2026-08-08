import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:mekaar_chat/core/navigation/app_navigator.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';
import 'package:mekaar_chat/data/services/push_notification_service.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/data/repositories/trip_repository.dart';
import 'app.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase using --dart-define
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    final message =
        '.env belum terbaca. Pastikan Anda menjalankan aplikasi dengan flag: --dart-define-from-file=.env';
    SupabaseService.markInitializationFailed(message);
    logger.w(message);
  } else {
    final configError = _validateSupabaseConfig(supabaseUrl, supabaseAnonKey);

    if (configError != null) {
      SupabaseService.markInitializationFailed(configError);
      logger.w(configError);
    } else {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
        SupabaseService.markInitialized();
        logger.i("Supabase initialized successfully");
      } catch (e) {
        final message =
            'Supabase gagal initialize. Periksa SUPABASE_URL, SUPABASE_ANON_KEY, dan koneksi ke server Supabase.';
        SupabaseService.markInitializationFailed(message);
        logger.e("$message Error: $e");
      }
    }
  }

  // 2. Run Application Immediately (<50ms) to mount Flutter Engine & render SplashScreen
  runApp(
    ProviderScope(
      child: NotificationListenerHost(child: const MekaarApp()),
    ),
  );

  // 3. Parallel Background Initialization for Native Notification & Push FCM
  unawaited(_initializeSecondaryServices());
}

Future<void> _initializeSecondaryServices() async {
  try {
    await NotificationService.initialize(
      onNotificationTap: (roomId) {
        final context = AppNavigator.currentContext;
        if (context != null && context.mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.chat,
            arguments: {'chatId': roomId},
          );
        }
      },
      onTripNotificationTap: (tripId) {
        final context = AppNavigator.currentContext;
        if (context != null && context.mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.tripArrivalConfirm,
            arguments: {'tripId': tripId},
          );
        }
      },
      onTripAction: (tripId, {required arrived, snoozeMinutes}) async {
        try {
          final repo = TripRepository(SupabaseService());
          if (arrived) {
            await repo.confirmArrivalManually(tripId);
          } else if (snoozeMinutes != null) {
            await repo.snoozeTrip(tripId, snoozeMinutes);
          }
          await NotificationService.cancelTripConfirmationNotification(tripId);
        } catch (e) {
          logger.w('Gagal memproses trip notification action: $e');
        }
      },
    );

    // Cek apakah app cold-started dari tap local notification
    await NotificationService.handleAppLaunchNotification();

    await PushNotificationService.initialize(
      onNotificationClick: (roomId) {
        final context = AppNavigator.currentContext;
        if (context != null && context.mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.chat,
            arguments: {'chatId': roomId},
          );
        }
      },
    );
  } catch (e) {
    logger.w('Notifikasi initialization non-fatal error: $e');
  }
}

String? _validateSupabaseConfig(String supabaseUrl, String supabaseAnonKey) {
  if (supabaseUrl.isEmpty) {
    return 'SUPABASE_URL kosong. Periksa file .env dan lakukan full restart aplikasi.';
  }

  if (supabaseAnonKey.isEmpty) {
    return 'SUPABASE_ANON_KEY kosong. Periksa file .env dan lakukan full restart aplikasi.';
  }

  final uri = Uri.tryParse(supabaseUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'SUPABASE_URL tidak valid. Gunakan URL Supabase lengkap dari project settings.';
  }

  if (uri.host == 'placeholder.supabase.co' ||
      supabaseAnonKey == 'placeholderKey') {
    return 'Konfigurasi Supabase masih memakai placeholder. Periksa file .env dan lakukan full restart aplikasi.';
  }

  if (!uri.host.endsWith('.supabase.co')) {
    return 'SUPABASE_URL tidak mengarah ke domain Supabase yang valid.';
  }

  return null;
}
