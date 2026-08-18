import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/theme_resolver.dart';
import 'package:mekaar_chat/core/constants/time_palette.dart';
import 'package:mekaar_chat/core/utils/time_theme_helper.dart';

void main() {
  group('isDayTime (06.00–17.59 Light, 18.00–05.59 Dark)', () {
    test('06:00 → true (awal siang/terang)', () {
      expect(isDayTime(const TimeOfDay(hour: 6, minute: 0)), isTrue);
    });

    test('12:00 → true (siang)', () {
      expect(isDayTime(const TimeOfDay(hour: 12, minute: 0)), isTrue);
    });

    test('17:59 → true (akhir waktu terang)', () {
      expect(isDayTime(const TimeOfDay(hour: 17, minute: 59)), isTrue);
    });

    test('18:00 → false (mulai gelap)', () {
      expect(isDayTime(const TimeOfDay(hour: 18, minute: 0)), isFalse);
    });

    test('23:59 → false (tengah malam)', () {
      expect(isDayTime(const TimeOfDay(hour: 23, minute: 59)), isFalse);
    });

    test('05:59 → false (sebelum jam 6 pagi)', () {
      expect(isDayTime(const TimeOfDay(hour: 5, minute: 59)), isFalse);
    });
  });

  group('ThemeResolver.isCurrentlyDark', () {
    test('light preference selalu false (tidak gelap)', () {
      expect(
        ThemeResolver.isCurrentlyDark(
          ThemePreference.light,
          const TimeOfDay(hour: 22, minute: 0),
        ),
        isFalse,
      );
    });

    test('dark preference selalu true (gelap)', () {
      expect(
        ThemeResolver.isCurrentlyDark(
          ThemePreference.dark,
          const TimeOfDay(hour: 12, minute: 0),
        ),
        isTrue,
      );
    });

    test('auto preference mengikuti jam: siang → false, malam → true', () {
      expect(
        ThemeResolver.isCurrentlyDark(
          ThemePreference.auto,
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
      expect(
        ThemeResolver.isCurrentlyDark(
          ThemePreference.auto,
          const TimeOfDay(hour: 20, minute: 0),
        ),
        isTrue,
      );
    });
  });
}

