import 'package:flutter/material.dart';

import 'colors.dart';
import 'themes.dart';
import 'time_palette.dart';
import '../utils/time_theme_helper.dart';

/// Resolver terpusat untuk semua keputusan tema berbasis waktu.
/// Memisahkan "apa yang dipilih" (ThemePreference) dari "apa yang dipakai"
/// (ThemeData + gradient) sehingga widget tinggal panggil.
class ThemeResolver {
  ThemeResolver._();

  /// Resolusi palet final. Kalau user pilih Auto, hitung dari jam.
  static TimePalette resolvePalette(ThemePreference pref) {
    if (pref.isAuto) {
      return paletteForTime(nowLocal());
    }
    return pref.toFixedPalette() ?? paletteForTime(nowLocal());
  }

  /// Brightness inherent tiap palet. Sore = light (hangat), Malam = dark.
  static Brightness brightnessOf(TimePalette p) {
    switch (p) {
      case TimePalette.morning:
      case TimePalette.afternoon:
      case TimePalette.evening:
        return Brightness.light;
      case TimePalette.night:
        return Brightness.dark;
    }
  }

  /// ThemeData final untuk [MaterialApp]. Memetakan preferensi ke factory
  /// yang ada di [MekaarTheme]. Malam reuse [MekaarTheme.darkTheme].
  static ThemeData resolveThemeData(
    ThemePreference pref,
    String fontFamily,
  ) {
    final palette = resolvePalette(pref);
    return _themeForPalette(palette, fontFamily);
  }

  static ThemeData _themeForPalette(TimePalette p, String fontFamily) {
    switch (p) {
      case TimePalette.morning:
        return MekaarTheme.morningTheme(fontFamily);
      case TimePalette.afternoon:
        return MekaarTheme.afternoonTheme(fontFamily);
      case TimePalette.evening:
        return MekaarTheme.eveningTheme(fontFamily);
      case TimePalette.night:
        return MekaarTheme.darkTheme(fontFamily);
    }
  }

  /// Canvas gradient. SOS override warna apapun.
  static LinearGradient resolveCanvasGradient(
    TimePalette p, {
    bool sosActive = false,
  }) {
    if (sosActive) return MekaarGradients.canvasSos;
    switch (p) {
      case TimePalette.morning:
        return MekaarGradients.canvasMorning;
      case TimePalette.afternoon:
        return MekaarGradients.canvasAfternoon;
      case TimePalette.evening:
        return MekaarGradients.canvasEvening;
      case TimePalette.night:
        return MekaarGradients.canvasDark;
    }
  }

  /// ThemeMode final untuk MaterialApp (light/dark). Auto-otomatis akan
  /// jadi light atau dark tergantung palet aktif.
  static ThemeMode resolveThemeMode(ThemePreference pref) {
    return brightnessOf(resolvePalette(pref)) == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }
}
