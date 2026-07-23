import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontCategory {
  playful,
  modern,
}

class AppFontFamily {
  final String key;
  final String displayName;
  final String subtitle;
  final FontCategory category;

  const AppFontFamily({
    required this.key,
    required this.displayName,
    required this.subtitle,
    required this.category,
  });

  static const String defaultFontKey = 'Plus Jakarta Sans';

  static const List<AppFontFamily> availableFonts = [
    // ── Kategori 1: Youth & Playful / Comic ──
    AppFontFamily(
      key: 'Comic Neue',
      displayName: 'Comic Neue',
      subtitle: 'Playful & santai gaya komik',
      category: FontCategory.playful,
    ),
    AppFontFamily(
      key: 'Fredoka',
      displayName: 'Fredoka',
      subtitle: 'Membulat, imut & modern',
      category: FontCategory.playful,
    ),
    AppFontFamily(
      key: 'Nunito',
      displayName: 'Nunito',
      subtitle: 'Soft rounded, hangat & ramah',
      category: FontCategory.playful,
    ),
    AppFontFamily(
      key: 'Quicksand',
      displayName: 'Quicksand',
      subtitle: 'Geometris membulat & kasual',
      category: FontCategory.playful,
    ),
    AppFontFamily(
      key: 'Comfortaa',
      displayName: 'Comfortaa',
      subtitle: 'Estetis membulat & futuristis',
      category: FontCategory.playful,
    ),
    AppFontFamily(
      key: 'Shantell Sans',
      displayName: 'Shantell Sans',
      subtitle: 'Gaya tulisan spidol komik',
      category: FontCategory.playful,
    ),

    // ── Kategori 2: Clean & Modern ──
    AppFontFamily(
      key: 'Plus Jakarta Sans',
      displayName: 'Plus Jakarta Sans',
      subtitle: 'Default MEKAAR — Modern & seimbang',
      category: FontCategory.modern,
    ),
    AppFontFamily(
      key: 'Inter',
      displayName: 'Inter',
      subtitle: 'Netral & keterbacaan tinggi',
      category: FontCategory.modern,
    ),
    AppFontFamily(
      key: 'Poppins',
      displayName: 'Poppins',
      subtitle: 'Geometris & rapi',
      category: FontCategory.modern,
    ),
    AppFontFamily(
      key: 'Lexend',
      displayName: 'Lexend',
      subtitle: 'Optimal untuk membaca / disleksia',
      category: FontCategory.modern,
    ),
  ];

  static AppFontFamily findByKey(String key) {
    return availableFonts.firstWhere(
      (f) => f.key == key,
      orElse: () => availableFonts.firstWhere((f) => f.key == defaultFontKey),
    );
  }
}

/// Mengelola preferensi gaya font aplikasi (dinamis via GoogleFonts).
/// Persisten via SharedPreferences (`app_font_family`).
class FontFamilyNotifier extends StateNotifier<String> {
  FontFamilyNotifier() : super(AppFontFamily.defaultFontKey) {
    _load();
  }

  static const String _key = 'app_font_family';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && saved.isNotEmpty) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setFontFamily(String fontFamilyKey) async {
    state = fontFamilyKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, fontFamilyKey);
    } catch (_) {}
  }
}

final fontFamilyProvider =
    StateNotifierProvider<FontFamilyNotifier, String>((ref) {
  return FontFamilyNotifier();
});
