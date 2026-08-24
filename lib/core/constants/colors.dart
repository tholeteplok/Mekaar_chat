import 'package:flutter/material.dart';

import '../theme/force_dark_scope.dart';

/// AppColors — Single source of truth untuk token warna resmi MEKAAR (Clean Core).
abstract class AppColors {
  // ── Brand Core (Sumber Tunggal) ──
  static const Color blue = Color(0xFF136CFC);
  static const Color darkBlue = Color(0xFF152641);
  static const Color green = Color(0xFFC3F84A);
  static const Color lightBlue = Color(0xFFE8F4FC);

  // ── Protective Semantics (Tidak Berubah) ──
  static const Color sosCoral = Color(0xFFFF5D5D);
  static const Color sosDeep = Color(0xFFD92632);
  static const Color safeTeal = Color(0xFF2DD4BF);
  static const Color warnAmber = Color(0xFFFBBF24);

  // ── Text & Surface ──
  static const Color textOnBlue = Colors.white;
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E304F);
  static const Color borderLight = Color(0xFFDCE7F5);
  static const Color borderDark = Color(0xFF25395B);
}

/// MekaarColors — Kelas utilitas warna MEKAAR dengan kompatibilitas dan context-aware helpers.
class MekaarColors {
  MekaarColors._();

  // ── Brand Core ──
  static const Color blue = AppColors.blue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color green = AppColors.green;
  static const Color lightBlue = AppColors.lightBlue;

  // ── Brand Aliases ──
  static const Color brandPrimary = AppColors.blue;
  static const Color brandSecondary = AppColors.green;
  static const Color canvasTop = AppColors.darkBlue;
  static const Color canvasMid = AppColors.darkBlue;
  static const Color canvasBottom = AppColors.darkBlue;

  // ── Functional Accent ──
  static const Color accent = AppColors.blue;
  static const Color accentDark = AppColors.blue;

  static Color accentOf(BuildContext c) => AppColors.blue;

  // ── Playful accents (untuk preset chat room & badges) ──
  static const Color primary = AppColors.blue;
  static const Color cyan = Color(0xFF38BDF8);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFA78BFA);
  static const Color pink = Color(0xFFF472B6);
  static const Color lime = AppColors.green;

  // ── Protective Semantics ──
  static const Color sosCoral = AppColors.sosCoral;
  static const Color sosDeep = AppColors.sosDeep;
  static const Color safeTeal = AppColors.safeTeal;
  /// Tinta gelap teal untuk teks/ikon di atas permukaan terang
  /// (safeTeal #2DD4BF hanya ≈1.8:1 di atas putih).
  static const Color safeTealInk = Color(0xFF0C6B60);
  static const Color warnAmber = AppColors.warnAmber;

  // ── Surfaces & Text Tokens ──
  static const Color textPrimaryLight = AppColors.darkBlue;
  static const Color textPrimaryDark = Color(0xFFF4F9FF);
  static const Color textPrimary = Color(0xFFF4F9FF); // Dark mode text primary

  static const Color textSecondaryLight = Color(0xFF5C6B85);
  static const Color textSecondaryDark = Color(0xFF9FB0C9);
  static const Color textSecondary = Color(0xFF9FB0C9);

  static const Color textMutedLight = Color(0xFF5C6B85);
  static const Color textMutedDark = Color(0xFF9FB0C9);
  static const Color textMuted = Color(0xFF6B7599);

  static const Color textOnBlue = AppColors.textOnBlue;
  static const Color textOnYellow = Color(0xFF2B2400);
  static const Color textOnLime = Color(0xFF1A2E05);
  /// Tinta gelap untuk teks di atas permukaan teal #2DD4BF (putih ≈1.9:1).
  static const Color textOnTeal = Color(0xFF04302A);

  static const Color card = AppColors.cardLight;
  static const Color cardDark = AppColors.cardDark;
  static const Color surfaceOverlay = Color(0x99152641); // 60% overlay

  // ── Borders ──
  static const Color borderLight = AppColors.borderLight;
  static const Color borderDark = AppColors.borderDark;
  static const Color border = Color(0xFFDCE7F5);

  // ── Permukaan komposer chat & mockup preview-nya ──
  /// Frosted bar komposer di chat_screen (alpha penuh, bukan token tema).
  static const Color composerOverlayLight = Color(0xF6FFFFFF);
  static const Color composerOverlayDark = Color(0xF2181D2E);
  /// Pil input "Ketik pesan…" pada preview pengaturan tema chat.
  static const Color composerPillLight = Color(0xFFE8F4FC);
  static const Color composerPillDark = Color(0xFF1E2638);

  // ── Background Surfaces ──
  static const Color background = AppColors.lightBlue;
  static const Color backgroundDark = AppColors.darkBlue;
  static const Color surface = AppColors.cardLight;
  static const Color surfaceDark = AppColors.cardDark;

  static const Color surface2 = Color(0xFFE8F4FC);
  static const Color surface2Dark = Color(0xFF25395B);
  static const Color surface3 = Color(0xFFDCE7F5);
  static const Color surface3Dark = Color(0xFF1E304F);

  // ── Legacy Compatibility Mappings ──
  static const Color softCoral = AppColors.sosCoral;
  static const Color sosRed = AppColors.sosDeep;
  static const Color guardianTeal = AppColors.safeTeal;
  static const Color sosLight = Color(0xFFFFF1F2);
  static const Color guardianLight = Color(0xFFE6FFFA);
  static const Color success = Color(0xFF10B981);
  /// Tinta hijau gelap untuk teks status online/aktif di permukaan terang.
  static const Color successInk = Color(0xFF047857);
  static Color successTextOf(BuildContext c) =>
      isDarkContext(c) ? success : successInk;
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color info = AppColors.blue;
  static const Color infoLight = Color(0xFFEFF6FF);

  // ── Context-aware Helpers ──
  /// True jika konteks ini harus memakai palet gelap: tema sistem gelap
  /// ATAU berada di dalam subtree forceDark (SOS / device-lost).
  static bool isDarkContext(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ||
      ForceDarkScope.isForcedDark(c);

  static Color primaryOf(BuildContext c) =>
      Theme.of(c).colorScheme.primary;

  static Color surfaceOf(BuildContext c) =>
      isDarkContext(c) ? cardDark : Theme.of(c).colorScheme.surface;

  static Color surface2Of(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark ? surface2Dark : surface2;
  }

  static Color surface3Of(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark ? surface3Dark : surface3;
  }

  static Color backgroundOf(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark ? backgroundDark : background;
  }

  static Color dividerOf(BuildContext c) =>
      isDarkContext(c) ? borderDark : Theme.of(c).dividerColor;

  static Color borderOf(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark ? borderDark : borderLight;
  }

  static Color cardBorderOf(BuildContext c) => borderOf(c);

  static Color textPrimaryOf(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark ? textPrimaryDark : textPrimaryLight;
  }

  static Color textSecondaryOf(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark ? textSecondaryDark : textSecondaryLight;
  }

  static Color textMutedOf(BuildContext c) {
    final isDark = isDarkContext(c);
    return isDark
        ? textSecondaryDark.withValues(alpha: 0.72)
        : textSecondaryLight.withValues(alpha: 0.72);
  }

  /// Warna aksen yang tetap terbaca sebagai teks/ikon di permukaan terang:
  /// biru brand di light mode (cyan #38BDF8 gagal kontras di atas putih),
  /// cyan di dark mode.
  static Color accentTextOf(BuildContext c) =>
      isDarkContext(c) ? cyan : blue;

  /// Teal semantik "aman/guardian" untuk teks & ikon:
  /// terang di dark mode, tinta gelap kontras-tinggi di light mode.
  static Color safeTextOf(BuildContext c) =>
      isDarkContext(c) ? safeTeal : safeTealInk;

  static Color outgoingBubbleOf(BuildContext c) => AppColors.blue;

  static Color outgoingBubbleBorderOf(BuildContext c) => Colors.transparent;

  static Color outgoingTextOf(BuildContext c) => Colors.white;
}

class MekaarGradients {
  MekaarGradients._();

  static const LinearGradient canvasDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.darkBlue,
      AppColors.darkBlue,
    ],
  );

  static const LinearGradient canvasLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.lightBlue,
      AppColors.lightBlue,
    ],
  );

  static const LinearGradient canvasSos = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.sosDeep,
      AppColors.sosCoral,
    ],
  );

  static const LinearGradient incomingBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [MekaarColors.purple, MekaarColors.purpleLight],
  );

  static const LinearGradient coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.sosCoral, Color(0xFFFFA07A)],
  );

  static const LinearGradient teal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.safeTeal, Color(0xFF5EEAD4)],
  );
}
