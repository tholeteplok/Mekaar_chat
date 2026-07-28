import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/theme_resolver.dart';
import '../constants/time_palette.dart';
import 'font_provider.dart';
import 'time_tick_provider.dart';

// Top-level default (diperlukan karena static class member tidak bisa
// dipakai sebagai initializer di top-level Provider).
const ThemePreference _kDefaultThemePref = ThemePreference.auto;

/// Mengelola preferensi tema aplikasi.
///
/// Preferensi disimpan sebagai [ThemePreference] di SharedPreferences
/// key `app_theme_preference`. Key lama `app_theme_mode` (Sistem/Terang/
/// Gelap) di-migrate sekali untuk backward compatibility.
class ThemePreferenceNotifier
    extends StateNotifier<AsyncValue<ThemePreference>> {
  ThemePreferenceNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const String _key = 'app_theme_preference';
  static const String _legacyKey = 'app_theme_mode';

  /// Default first-run: Otomatis (ikuti jam device).
  static const ThemePreference defaultPreference = ThemePreference.auto;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final prefs = await SharedPreferences.getInstance();

      // Backward compat: kalau key baru belum ada, migrasi dari key lama.
      final saved = prefs.getString(_key);
      if (saved != null && saved.isNotEmpty) {
        return _fromString(saved);
      }

      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        final migrated = _migrateLegacy(legacy);
        // Tulis ke key baru agar next load tidak migrasi ulang.
        await prefs.setString(_key, _toString(migrated));
        return migrated;
      }

      return defaultPreference;
    });
  }

  Future<void> setPreference(ThemePreference pref) async {
    state = AsyncValue.data(pref);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _toString(pref));
    } catch (_) {}
  }

  Future<void> setAuto() => setPreference(ThemePreference.auto);

  Future<void> setPalette(TimePalette p) {
    switch (p) {
      case TimePalette.morning:
        return setPreference(ThemePreference.morning);
      case TimePalette.afternoon:
        return setPreference(ThemePreference.afternoon);
      case TimePalette.evening:
        return setPreference(ThemePreference.evening);
      case TimePalette.night:
        return setPreference(ThemePreference.night);
    }
  }

  static ThemePreference _fromString(String value) {
    switch (value) {
      case 'auto':
        return ThemePreference.auto;
      case 'morning':
        return ThemePreference.morning;
      case 'afternoon':
        return ThemePreference.afternoon;
      case 'evening':
        return ThemePreference.evening;
      case 'night':
        return ThemePreference.night;
      default:
        return defaultPreference;
    }
  }

  static String _toString(ThemePreference pref) {
    switch (pref) {
      case ThemePreference.auto:
        return 'auto';
      case ThemePreference.morning:
        return 'morning';
      case ThemePreference.afternoon:
        return 'afternoon';
      case ThemePreference.evening:
        return 'evening';
      case ThemePreference.night:
        return 'night';
    }
  }

  /// Mapping dari key lama (system/light/dark) ke preferensi baru.
  /// - system → auto (mengikuti "jam" tetap berguna)
  /// - light  → afternoon (clean bright, palet siang)
  /// - dark   → night
  static ThemePreference _migrateLegacy(String legacy) {
    switch (legacy) {
      case 'light':
        return ThemePreference.afternoon;
      case 'dark':
        return ThemePreference.night;
      case 'system':
      default:
        return ThemePreference.auto;
    }
  }
}

final themePreferenceProvider = StateNotifierProvider<ThemePreferenceNotifier,
    AsyncValue<ThemePreference>>((ref) {
  return ThemePreferenceNotifier();
});

/// Provider tema final untuk [MaterialApp]. Menggabungkan preferensi user
/// dengan tick per menit agar auto-switch terasa realtime.
final resolvedThemeDataProvider = Provider<ThemeData>((ref) {
  // Trigger rebuild setiap menit (untuk mode auto).
  ref.watch(timeTickProvider);
  final fontFamily = ref.watch(fontFamilyProvider).valueOrNull ?? AppFontFamily.defaultFontKey;
  final pref = ref.watch(themePreferenceProvider).valueOrNull ?? _kDefaultThemePref;
  return ThemeResolver.resolveThemeData(pref, fontFamily);
});

/// ThemeMode final untuk MaterialApp (light/dark) — berdasarkan brightness
/// palet aktif.
final resolvedThemeModeProvider = Provider<ThemeMode>((ref) {
  ref.watch(timeTickProvider);
  final pref = ref.watch(themePreferenceProvider).valueOrNull ?? _kDefaultThemePref;
  return ThemeResolver.resolveThemeMode(pref);
});
