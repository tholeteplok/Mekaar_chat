import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_routes.dart';
import 'core/constants/themes.dart';
import 'core/constants/typography.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/font_provider.dart';
import 'core/widgets/screen_protection_widgets.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/auto_lock_provider.dart';
import 'features/chat/providers/screen_protection_provider.dart';
import 'data/services/aegis_memory_guard_service.dart';
import 'data/services/database_key_service.dart';
import 'data/services/local_message_database.dart';
import 'features/chat/providers/app_realtime_listener.dart';
import 'features/chat/providers/chat_provider.dart';
import 'data/services/notification_service.dart';
import 'core/navigation/app_navigator.dart';
import 'core/widgets/mekaar_update_overlay.dart';

class MekaarApp extends ConsumerStatefulWidget {
  const MekaarApp({super.key});

  @override
  ConsumerState<MekaarApp> createState() => _MekaarAppState();
}

class _MekaarAppState extends ConsumerState<MekaarApp> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _resumeSyncTimer;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (results) {
          final isOnline = results.any((r) => r != ConnectivityResult.none);
          if (!isOnline) {
            _wasOffline = true;
            return;
          }
          if (_wasOffline) {
            _wasOffline = false;
            _recoverConnectivity();
          }
        },
        onError: (_) {},
      );
    } on MissingPluginException {
      // Abaikan di lingkungan headless/widget test
    } catch (_) {}
  }

  void _recoverConnectivity() {
    if (!mounted || LocalMessageDatabase.instance.isDecoy) return;
    try {
      ref.read(appRealtimeListenerProvider).reconnectIfNeeded();
    } catch (_) {}
    try {
      unawaited(ref.read(chatRepositoryProvider).reconnectActiveRoomStreams());
    } catch (_) {}
    try {
      final roomsState = ref.read(chatRoomsProvider);
      if (roomsState.hasError || (roomsState.valueOrNull?.isEmpty ?? true)) {
        unawaited(
          ref.read(chatRoomsProvider.notifier).refreshRooms(forceLoading: false),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _resumeSyncTimer?.cancel();
    _resumeSyncTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _resumeSyncTimer?.cancel();
      try {
        ref.read(appRealtimeListenerProvider).pauseBackgroundTimers();
      } catch (_) {}
      // Catat timestamp background untuk evaluasi Auto-Lock Timeout
      ref.read(autoLockControllerProvider).onAppPaused();

      // Hapus seluruh kunci kriptografi dari memori fisik RAM seketika saat aplikasi di-minimize/background
      unawaited(AegisMemoryGuardService.instance.zeroizeAllKeys());
      unawaited(DatabaseKeyService.instance.lockVault());
    } else if (state == AppLifecycleState.resumed) {
      // Evaluasi batas waktu Auto-Lock (jika timeout terlampaui, kunci ke PinScreen)
      unawaited(ref.read(autoLockControllerProvider).handleAppResumed(ref));

      // Pemicu otomatis pembersihan pesan kedaluwarsa & pembersihan terjadwal saat aplikasi aktif kembali
      unawaited(() async {
        final purged =
            await ref.read(chatRepositoryProvider).purgeExpiredMessages();
        if (purged > 0 && mounted) {
          await ref
              .read(chatRoomsProvider.notifier)
              .reloadFromLocalCache(syncRemoteInBackground: true);
        }
      }());

      // Beri jeda stabilisasi 350ms agar rute TCP/DNS OS pulih pasca-background
      // sebelum menyambungkan ulang listener global, stream room aktif, & daftar obrolan.
      _resumeSyncTimer?.cancel();
      _resumeSyncTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || LocalMessageDatabase.instance.isDecoy) return;
        try {
          ref.read(appRealtimeListenerProvider)
            ..resumeBackgroundTimers()
            ..reconnectIfNeeded();
        } catch (_) {}
        try {
          unawaited(
            ref.read(chatRepositoryProvider).reconnectActiveRoomStreams(),
          );
        } catch (_) {}
        try {
          unawaited(
            ref.read(chatRoomsProvider.notifier).refreshRooms(forceLoading: false),
          );
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScreenshotBlocked = ref.watch(screenshotBlockProvider);
    final protectionController = ref.watch(screenProtectionControllerProvider);
    if (isScreenshotBlocked) {
      protectionController.enterMandatorySurface('global_screenshot_block');
    } else {
      protectionController.leaveMandatorySurface('global_screenshot_block');
    }
    // Sync Notification Masking preference ke service statis (patuhi nilai persisten Master).
    ref.watch(notificationMaskingProvider);
    NotificationService.maskingEnabled =
        ref.read(notificationMaskingProvider.notifier).enforcedValue;

    // Tema otomatis berbasis waktu: MaterialApp menerima ThemeData final
    // yang sudah di-resolve (light/dark + palet sesuai preferensi).
    final themeData = ref.watch(resolvedThemeDataProvider);
    final themeMode = ref.watch(resolvedThemeModeProvider);
    // Tipografi sistem aplikasi di-lock ke default enterprise 'Plus Jakarta Sans'
    MekaarTypography.fontFamily = AppFontFamily.defaultFontKey;

    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      navigatorObservers: [AppNavigator.observer],
      title: 'MEKAAR',
      theme: themeData,
      darkTheme: MekaarTheme.darkTheme(AppFontFamily.defaultFontKey),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
        final currentChild = child ?? const SizedBox();

        return MekaarUpdateOverlay(
          child: StreamBuilder<bool>(
            stream: protectionController.captureState,
            initialData: false,
            builder: (context, captureSnapshot) {
              return StreamBuilder<Map<String, dynamic>>(
                stream: protectionController.states.map(
                  (states) => Map<String, dynamic>.from(states),
                ),
                builder: (context, _) {
                  final hideContent =
                      (captureSnapshot.data ?? false) &&
                      protectionController.hasProtectedSurface;
                  return Stack(
                    children: [
                      currentChild,
                      ScreenCaptureProtectionOverlay(visible: hideContent),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
