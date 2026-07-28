import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/time_palette.dart';

/// Representasi satu slot waktu dengan rentang [start, end).
/// Slot bisa melintasi tengah malam (end < start) untuk [night].
class AutoTimeSlot {
  final TimeOfDay start;
  final TimeOfDay end;
  final TimePalette palette;

  const AutoTimeSlot(this.start, this.end, this.palette);

  /// True jika [t] berada dalam slot ini. Mendukung slot yang melintasi
  /// tengah malam (mis. 18:00–04:00).
  bool contains(TimeOfDay t) {
    final tMin = t.hour * 60 + t.minute;
    final sMin = start.hour * 60 + start.minute;
    final eMin = end.hour * 60 + end.minute;

    if (sMin <= eMin) {
      return tMin >= sMin && tMin < eMin;
    }
    // Wraps midnight: 18:00 → 04:00
    return tMin >= sMin || tMin < eMin;
  }
}

/// Daftar slot waktu harian. Batas jam custom (user request):
/// - 04:00 Pagi
/// - 10:00 Siang
/// - 15:00 Sore
/// - 18:00 Malam (wraps ke 04:00)
const List<AutoTimeSlot> kAutoTimeSlots = [
  AutoTimeSlot(TimeOfDay(hour: 4, minute: 0), TimeOfDay(hour: 10, minute: 0),
      TimePalette.morning),
  AutoTimeSlot(TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 15, minute: 0),
      TimePalette.afternoon),
  AutoTimeSlot(TimeOfDay(hour: 15, minute: 0), TimeOfDay(hour: 18, minute: 0),
      TimePalette.evening),
  AutoTimeSlot(TimeOfDay(hour: 18, minute: 0), TimeOfDay(hour: 4, minute: 0),
      TimePalette.night),
];

/// Ambil jam & menit dari waktu lokal device (auto-detect timezone via
/// DateTime.now() internal, termasuk DST).
TimeOfDay nowLocal() {
  final n = DateTime.now();
  return TimeOfDay(hour: n.hour, minute: n.minute);
}

/// Cari palet yang sesuai dengan jam [t].
TimePalette paletteForTime(TimeOfDay t) {
  for (final slot in kAutoTimeSlots) {
    if (slot.contains(t)) return slot.palette;
  }
  // Fallback (seharusnya tidak pernah terjadi karena slot[3] wraps midnight).
  return TimePalette.night;
}

/// Label Indonesia untuk palet. Tidak ada hardcoded di widget.
String timePaletteLabel(TimePalette p) {
  switch (p) {
    case TimePalette.morning:
      return 'Pagi';
    case TimePalette.afternoon:
      return 'Siang';
    case TimePalette.evening:
      return 'Sore';
    case TimePalette.night:
      return 'Malam';
  }
}

/// Rentang jam untuk label UI (mis. "04.00–10.00").
String timePaletteRangeLabel(TimePalette p) {
  switch (p) {
    case TimePalette.morning:
      return '04.00–10.00';
    case TimePalette.afternoon:
      return '10.00–15.00';
    case TimePalette.evening:
      return '15.00–18.00';
    case TimePalette.night:
      return '18.00–04.00';
  }
}

/// Icon SolarIconsOutline untuk palet (satu sumber, tidak ada hardcoded).
IconData timePaletteIcon(TimePalette p) {
  switch (p) {
    case TimePalette.morning:
      return SolarIconsOutline.sunrise;
    case TimePalette.afternoon:
      return SolarIconsOutline.sun;
    case TimePalette.evening:
      return SolarIconsOutline.sunset;
    case TimePalette.night:
      return SolarIconsOutline.moonStars;
  }
}

/// Icon untuk preference (auto = clockCircle, fixed = palet icon).
IconData themePreferenceIcon(ThemePreference pref) {
  if (pref.isAuto) return SolarIconsOutline.clockCircle;
  final p = pref.toFixedPalette();
  return p == null ? SolarIconsOutline.clockCircle : timePaletteIcon(p);
}

/// Label Indonesia untuk [ThemePreference]. Termasuk mode "Otomatis".
String themePreferenceLabel(ThemePreference pref) {
  if (pref.isAuto) return 'Otomatis';
  final p = pref.toFixedPalette();
  return p == null ? 'Otomatis' : timePaletteLabel(p);
}

/// Subtitle untuk cell UI (rentang jam atau "Ikuti jam").
String themePreferenceSubtitle(ThemePreference pref) {
  if (pref.isAuto) return 'Ikuti jam';
  final p = pref.toFixedPalette();
  return p == null ? 'Ikuti jam' : timePaletteRangeLabel(p);
}
