import 'package:flutter/material.dart';

/// AppNavigator — Kunci navigator global untuk pengalihan halaman dari
/// listener event background (seperti panggilan masuk Realtime).
class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;
}
