import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/time_palette.dart';

/// Ambil jam & menit dari waktu lokal device.
TimeOfDay nowLocal() {
  final n = DateTime.now();
  return TimeOfDay(hour: n.hour, minute: n.minute);
}

/// Evaluasi apakah jam [t] adalah waktu siang (06.00 - 17.59).
bool isDayTime(TimeOfDay t) {
  return t.hour >= 6 && t.hour < 18;
}

/// Icon untuk preference (auto = clockCircle, light = sun, dark = moonStars).
IconData themePreferenceIcon(ThemePreference pref) {
  switch (pref) {
    case ThemePreference.auto:
      return SolarIconsOutline.clockCircle;
    case ThemePreference.light:
      return SolarIconsOutline.sun;
    case ThemePreference.dark:
      return SolarIconsOutline.moonStars;
  }
}

/// Label Indonesia untuk [ThemePreference].
String themePreferenceLabel(ThemePreference pref) {
  switch (pref) {
    case ThemePreference.auto:
      return 'Otomatis';
    case ThemePreference.light:
      return 'Terang';
    case ThemePreference.dark:
      return 'Gelap';
  }
}

/// Subtitle penjelasan untuk mode tema.
String themePreferenceSubtitle(ThemePreference pref) {
  switch (pref) {
    case ThemePreference.auto:
      return '06.00–18.00 Terang, 18.00–06.00 Gelap';
    case ThemePreference.light:
      return 'Tetap terang sepanjang hari';
    case ThemePreference.dark:
      return 'Tetap gelap sepanjang hari';
  }
}

