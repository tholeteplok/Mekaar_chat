import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes/app_routes.dart';
import 'core/constants/themes.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/font_provider.dart';
import 'core/widgets/screen_protection_widgets.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/screen_protection_provider.dart';
import 'data/services/notification_service.dart';

import 'features/auth/screens/set_username_screen.dart';
import 'core/navigation/app_navigator.dart';

class MekaarApp extends ConsumerWidget {
  const MekaarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch screenshotBlockProvider to apply the block setting at startup dynamically
    ref.watch(screenshotBlockProvider);
    // Sync Notification Masking preference ke service statis.
    NotificationService.maskingEnabled = ref.watch(notificationMaskingProvider);

    final themeMode = ref.watch(themeModeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final protectionController = ref.watch(screenProtectionControllerProvider);
    final authState = ref.watch(authProvider);

    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      title: 'MEKAAR',
      theme: MekaarTheme.lightTheme(fontFamily),
      darkTheme: MekaarTheme.darkTheme(fontFamily),
      themeMode: themeMode, // Sistem / Terang / Gelap (persisten)
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
        Widget currentChild = child ?? const SizedBox();
        if (authState.needsUsername) {
          currentChild = const SetUsernameScreen();
        }

        return StreamBuilder<bool>(
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
        );
      },
    );
  }
}
