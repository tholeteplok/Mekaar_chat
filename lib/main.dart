import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:mekaar_chat/core/navigation/app_navigator.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/data/services/alarm_service.dart';
import 'package:mekaar_chat/data/services/notification_service.dart';
import 'package:mekaar_chat/data/services/push_notification_service.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/features/chat/screens/incoming_call_screen.dart';
import 'package:mekaar_chat/data/repositories/trip_repository.dart';
import 'package:mekaar_chat/data/services/deep_link_service.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_dialogs.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aktifkan Android Photo Picker bawaan OS (Galeri visual foto & video modern)
  final imagePickerPlatform = ImagePickerPlatform.instance;
  if (imagePickerPlatform is ImagePickerAndroid) {
    imagePickerPlatform.useAndroidPhotoPicker = true;
  }

  // Sanitasi Forensik: Matikan seluruh output log console pada build produksi (Release Mode)
  // guna mencegah kebocoran pesan terdekripsi, token, dan metadata via Android logcat atau USB debugging.
  Logger.level = kReleaseMode ? Level.off : Level.debug;

  // Inisialisasi format tanggal lokal (Indonesia) untuk intl
  await initializeDateFormatting('id_ID', null);

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
          // Timeout lebih panjang dari default SDK (10 detik) untuk
          // mengurangi false-positive RealtimeSubscribeException(timedOut).
          // Log debug hanya di build debug untuk observasi kontensi channel.
          realtimeClientOptions: RealtimeClientOptions(
            timeout: const Duration(seconds: 20),
            logLevel: kDebugMode ? RealtimeLogLevel.debug : null,
          ),
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
  // 1. Inisialisasi Deep Link Service secara independen
  try {
    await DeepLinkService.initialize();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        final context = AppNavigator.currentContext;
        if (context != null && context.mounted) {
          Navigator.pushNamed(context, AppRoutes.newPassword);
        }
      }
    });
  } catch (e) {
    logger.w('DeepLinkService initialization non-fatal error: $e');
  }

  // 2. Inisialisasi Notification Service lokal & channel Android
  try {
    await NotificationService.initialize(
      onNotificationTap: _handleNotificationRoute,
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
      onCallAction: (route, {required accept}) async {
        if (accept) {
          _handleNotificationRoute(route);
        } else {
          final callId = route.callId;
          if (callId != null && callId.isNotEmpty) {
            try {
              final client = SupabaseService().client;
              await client
                  .from('calls')
                  .update({
                    'status': 'declined',
                    'ended_at': DateTime.now().toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', callId);
            } catch (e) {
              logger.w('Gagal tolak panggilan dari notification action: $e');
            }
          }
        }
      },
    );

    // Cek apakah app cold-started dari tap local notification
    await NotificationService.handleAppLaunchNotification();
  } catch (e) {
    logger.w('NotificationService initialization non-fatal error: $e');
  }

  // 3. Inisialisasi Push Notification FCM
  try {
    await PushNotificationService.initialize(
      onNotificationClick: _handleNotificationRoute,
    );
  } catch (e) {
    logger.w('PushNotificationService initialization non-fatal error: $e');
  }
}

/// Pusat navigasi untuk semua jenis tap notifikasi (local maupun FCM).
///
/// `message` → buka chat room; `call` → buka layar panggilan masuk;
/// `sos` → buka viewer SOS guardian (bukan SOSActiveScreen sisi korban).
void _handleNotificationRoute(NotificationRoute route) async {
  final context = AppNavigator.currentContext;
  if (context == null || !context.mounted) return;

  switch (route.type) {
    case NotificationRouteType.message:
      final roomId = route.roomId;
      if (roomId == null || roomId.isEmpty) return;

      // ── Mitigasi Privasi Kontak Vault (Tersembunyi) ──
      try {
        final hiddenRooms =
            await PrivateContactRepository().getHiddenRoomIds();
        if (!context.mounted) return;
        if (hiddenRooms.contains(roomId)) {
          bool isUnlocked = false;
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            isUnlocked = container.read(privateVaultUnlockedProvider);
          } catch (_) {}

          if (!isUnlocked) {
            // Arahkan ke layar utama dan minta PIN Vault terlebih dahulu
            Navigator.of(context).popUntil((r) => r.isFirst);
            final unlocked =
                await PrivateVaultDialogs.showUnlockPasscodeDialog(context);
            if (!context.mounted) return;
            if (unlocked) {
              try {
                final container =
                    ProviderScope.containerOf(context, listen: false);
                container.read(privateVaultUnlockedProvider.notifier).state =
                    true;
              } catch (_) {}
              Navigator.pushNamed(
                context,
                AppRoutes.chat,
                arguments: {
                  'chatId': roomId,
                  'chatName': route.chatName,
                  'chatAvatarUrl': route.chatAvatarUrl,
                  'isGuardian': route.isGuardian,
                  'otherUserId': route.otherUserId,
                },
              );
            }
            return;
          }
        }
      } catch (_) {}

      if (context.mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.chat,
          arguments: {
            'chatId': roomId,
            'chatName': route.chatName,
            'chatAvatarUrl': route.chatAvatarUrl,
            'isGuardian': route.isGuardian,
            'otherUserId': route.otherUserId,
          },
        );
      }
    case NotificationRouteType.call:
      final callId = route.callId;
      final roomId = route.roomId;
      final callerId = route.callerId;
      if (callId == null || roomId == null || callerId == null) return;

      bool isVaultLocked = false;
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final hiddenRooms =
            await PrivateContactRepository().getHiddenRoomIds();
        if (hiddenRooms.contains(roomId)) {
          bool isUnlocked = false;
          try {
            isUnlocked = container.read(privateVaultUnlockedProvider);
          } catch (_) {}
          isVaultLocked = !isUnlocked;
        }
      } catch (_) {}

      if (!context.mounted) return;

      // PENGECAHAN TRANSISI: layar panggilan masuk sengaja memakai
      // MaterialPageRoute (platform-feel slide-up ala dialer OS), bukan
      // MekaarPageRoute fade. Jangan diubah tanpa revisi design.md.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: callId,
            roomId: roomId,
            callerId: callerId,
            callerName: isVaultLocked
                ? 'Panggilan Masuk'
                : (route.callerName ?? 'Seseorang'),
            callerAvatarUrl: isVaultLocked ? null : route.callerAvatarUrl,
            callType: route.callType ?? 'voice',
            isVaultLocked: isVaultLocked,
          ),
        ),
      );
    case NotificationRouteType.sos:
      final sessionId = route.sessionId;
      if (sessionId == null || sessionId.isEmpty) return;
      AlarmService.stopSOSAlarm();
      Navigator.pushNamed(
        context,
        AppRoutes.sosViewer,
        arguments: {
          'sessionId': sessionId,
          'userId': route.userId,
          'userName': route.userName ?? 'Korban',
        },
      );
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
