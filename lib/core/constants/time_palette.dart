/// Enum palet waktu untuk tema otomatis.
///
/// Merepresentasikan 4 slot waktu harian yang dipakai oleh fitur tema
/// otomatis MEKAAR. [night] secara visual reuse [MekaarTheme.darkTheme]
/// agar konsisten dengan mode gelap yang sudah ada.
enum TimePalette {
  morning,
  afternoon,
  evening,
  night,
}

/// Preferensi tema user.
///
/// - [auto] → tema berubah otomatis mengikuti jam device lokal.
/// - [morning] / [afternoon] / [evening] / [night] → tema dikunci manual.
enum ThemePreference {
  auto,
  morning,
  afternoon,
  evening,
  night,
}

extension ThemePreferenceX on ThemePreference {
  /// Konversi ke [TimePalette]. Untuk [ThemePreference.auto] gunakan
  /// [ThemeResolver.resolvePalette] agar ikut jam.
  TimePalette? toFixedPalette() {
    switch (this) {
      case ThemePreference.morning:
        return TimePalette.morning;
      case ThemePreference.afternoon:
        return TimePalette.afternoon;
      case ThemePreference.evening:
        return TimePalette.evening;
      case ThemePreference.night:
        return TimePalette.night;
      case ThemePreference.auto:
        return null;
    }
  }

  bool get isAuto => this == ThemePreference.auto;
}
