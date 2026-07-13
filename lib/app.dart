import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes/app_routes.dart';
import 'core/constants/themes.dart';

class MekaarApp extends ConsumerWidget {
  const MekaarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'MEKAAR',
      theme: MekaarTheme.lightTheme(),
      darkTheme: MekaarTheme.darkTheme(),
      themeMode: ThemeMode.system, // Mengikuti setting system (Light/Dark)
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
