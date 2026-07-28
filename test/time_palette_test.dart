import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/time_palette.dart';
import 'package:mekaar_chat/core/utils/time_theme_helper.dart';

void main() {
  group('paletteForTime', () {
    test('04:00 → morning (batas pagi)', () {
      expect(paletteForTime(const TimeOfDay(hour: 4, minute: 0)),
          TimePalette.morning);
    });

    test('09:59 → morning (akhir slot pagi)', () {
      expect(paletteForTime(const TimeOfDay(hour: 9, minute: 59)),
          TimePalette.morning);
    });

    test('10:00 → afternoon (batas siang)', () {
      expect(paletteForTime(const TimeOfDay(hour: 10, minute: 0)),
          TimePalette.afternoon);
    });

    test('14:59 → afternoon (akhir slot siang)', () {
      expect(paletteForTime(const TimeOfDay(hour: 14, minute: 59)),
          TimePalette.afternoon);
    });

    test('15:00 → evening (batas sore)', () {
      expect(paletteForTime(const TimeOfDay(hour: 15, minute: 0)),
          TimePalette.evening);
    });

    test('17:59 → evening (akhir slot sore)', () {
      expect(paletteForTime(const TimeOfDay(hour: 17, minute: 59)),
          TimePalette.evening);
    });

    test('18:00 → night (batas malam)', () {
      expect(paletteForTime(const TimeOfDay(hour: 18, minute: 0)),
          TimePalette.night);
    });

    test('23:59 → night', () {
      expect(paletteForTime(const TimeOfDay(hour: 23, minute: 59)),
          TimePalette.night);
    });

    test('02:00 → night (lewat tengah malam sebelum jam 04.00)', () {
      expect(paletteForTime(const TimeOfDay(hour: 2, minute: 0)),
          TimePalette.night);
    });

    test('03:59 → night (akhir slot malam)', () {
      expect(paletteForTime(const TimeOfDay(hour: 3, minute: 59)),
          TimePalette.night);
    });
  });

  group('ThemePreferenceX.toFixedPalette', () {
    test('auto → null', () {
      expect(ThemePreference.auto.toFixedPalette(), isNull);
    });

    test('morning → TimePalette.morning', () {
      expect(ThemePreference.morning.toFixedPalette(), TimePalette.morning);
    });

    test('afternoon → TimePalette.afternoon', () {
      expect(
          ThemePreference.afternoon.toFixedPalette(), TimePalette.afternoon);
    });

    test('evening → TimePalette.evening', () {
      expect(ThemePreference.evening.toFixedPalette(), TimePalette.evening);
    });

    test('night → TimePalette.night', () {
      expect(ThemePreference.night.toFixedPalette(), TimePalette.night);
    });
  });
}
