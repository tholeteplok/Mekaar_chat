import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes/app_routes.dart';
import 'core/constants/themes.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';

class MekaarApp extends ConsumerWidget {
  const MekaarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch screenshotBlockProvider to apply the block setting at startup dynamically
    ref.watch(screenshotBlockProvider);
    
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'MEKAAR',
      theme: MekaarTheme.lightTheme(),
      darkTheme: MekaarTheme.darkTheme(),
      themeMode: themeMode, // Sistem / Terang / Gelap (persisten)
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
