import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_routes.dart';
import 'core/constants/themes.dart';
import 'core/constants/typography.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/font_provider.dart';
import 'core/widgets/screen_protection_widgets.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/screen_protection_provider.dart';
import 'data/services/aegis_memory_guard_service.dart';
import 'data/services/database_key_service.dart';
import 'data/services/notification_service.dart';
import 'core/navigation/app_navigator.dart';
import 'core/widgets/mekaar_update_overlay.dart';

class MekaarApp extends ConsumerStatefulWidget {
  const MekaarApp({super.key});

  @override
  ConsumerState<MekaarApp> createState() => _MekaarAppState();
}

class _MekaarAppState extends ConsumerState<MekaarApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Hapus seluruh kunci kriptografi dari memori fisik RAM seketika saat aplikasi di-minimize/background
      unawaited(AegisMemoryGuardService.instance.zeroizeAllKeys());
      unawaited(DatabaseKeyService.instance.lockVault());
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
    // Sync Notification Masking preference ke service statis.
    NotificationService.maskingEnabled = ref.watch(notificationMaskingProvider);

    // Tema otomatis berbasis waktu: MaterialApp menerima ThemeData final
    // yang sudah di-resolve (light/dark + palet sesuai preferensi).
    final themeData = ref.watch(resolvedThemeDataProvider);
    final themeMode = ref.watch(resolvedThemeModeProvider);
    final fontFamily =
        ref.watch(fontFamilyProvider).valueOrNull ?? AppFontFamily.defaultFontKey;
    MekaarTypography.fontFamily = fontFamily;

    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      title: 'MEKAAR',
      theme: themeData,
      darkTheme: MekaarTheme.darkTheme(fontFamily),
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
