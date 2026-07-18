import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes/app_routes.dart';
import 'core/constants/themes.dart';
import 'core/providers/theme_provider.dart';
import 'core/widgets/screen_protection_widgets.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/screen_protection_provider.dart';
import 'data/services/notification_service.dart';

class MekaarApp extends ConsumerWidget {
  const MekaarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch screenshotBlockProvider to apply the block setting at startup dynamically
    ref.watch(screenshotBlockProvider);
    // Sync Notification Masking preference ke service statis.
    NotificationService.maskingEnabled = ref.watch(notificationMaskingProvider);

    final themeMode = ref.watch(themeModeProvider);
    final protectionController = ref.watch(screenProtectionControllerProvider);
    return MaterialApp(
      title: 'MEKAAR',
      theme: MekaarTheme.lightTheme(),
      darkTheme: MekaarTheme.darkTheme(),
      themeMode: themeMode, // Sistem / Terang / Gelap (persisten)
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
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
                    ?child,
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
