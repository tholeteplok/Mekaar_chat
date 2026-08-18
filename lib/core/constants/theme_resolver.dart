import 'package:flutter/material.dart';

import 'colors.dart';
import 'themes.dart';
import 'time_palette.dart';
import '../utils/time_theme_helper.dart';

/// Resolver terpusat untuk keputusan tema Core UI (3-mode: Light / Dark / Auto).
class ThemeResolver {
  ThemeResolver._();

  /// Evaluasi apakah preferensi saat ini aktif sebagai Dark mode.
  static bool isCurrentlyDark(ThemePreference pref, [TimeOfDay? time]) {
    switch (pref) {
      case ThemePreference.light:
        return false;
      case ThemePreference.dark:
        return true;
      case ThemePreference.auto:
        return !isDayTime(time ?? nowLocal());
    }
  }

  /// Brightness aktif.
  static Brightness brightnessOf(ThemePreference pref, [TimeOfDay? time]) {
    return isCurrentlyDark(pref, time) ? Brightness.dark : Brightness.light;
  }

  /// ThemeData final untuk [MaterialApp].
  static ThemeData resolveThemeData(
    ThemePreference pref,
    String fontFamily,
  ) {
    return isCurrentlyDark(pref)
        ? MekaarTheme.darkTheme(fontFamily)
        : MekaarTheme.lightTheme(fontFamily);
  }

  /// Canvas gradient/color. SOS override warna apapun.
  static LinearGradient resolveCanvasGradient(
    ThemePreference pref, {
    bool sosActive = false,
    bool forceDark = false,
  }) {
    if (sosActive) return MekaarGradients.canvasSos;
    if (forceDark || isCurrentlyDark(pref)) {
      return MekaarGradients.canvasDark;
    }
    return MekaarGradients.canvasLight;
  }

  /// ThemeMode final untuk MaterialApp (light/dark).
  static ThemeMode resolveThemeMode(ThemePreference pref) {
    return isCurrentlyDark(pref) ? ThemeMode.dark : ThemeMode.light;
  }
}

