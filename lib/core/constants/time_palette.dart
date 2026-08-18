/// Preferensi tema user (Clean Core).
///
/// - [auto] → tema berubah otomatis: 06.00–17.59 Light, 18.00–05.59 Dark.
/// - [light] → tema terang sepanjang hari.
/// - [dark] → tema gelap sepanjang hari.
enum ThemePreference {
  auto,
  light,
  dark,
}

extension ThemePreferenceX on ThemePreference {
  bool get isAuto => this == ThemePreference.auto;
  bool get isLight => this == ThemePreference.light;
  bool get isDark => this == ThemePreference.dark;
}

