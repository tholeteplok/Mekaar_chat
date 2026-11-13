import 'package:flutter/material.dart';

/// AppNavigator — Kunci navigator global untuk pengalihan halaman dari
/// listener event background (seperti panggilan masuk Realtime & notifikasi).
class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  /// Nama rute yang sedang aktif di puncak navigator stack
  static String? currentRouteName;

  /// Observer untuk melacak rute aktif secara otomatis
  static final NavigatorObserver observer = _AppNavigatorObserver();
}

class _AppNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNavigator.currentRouteName = route.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppNavigator.currentRouteName = newRoute?.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNavigator.currentRouteName = previousRoute?.settings.name;
  }
}
