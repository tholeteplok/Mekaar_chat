import 'package:flutter/material.dart';

import '../theme/force_dark_scope.dart';

/// AppColors — Single source of truth untuk token warna resmi MEKAAR (Clean Core).
abstract class AppColors {
  // ── Brand Core (Sumber Tunggal) ──
  static const Color blue = Color(0xFF136CFC);
  static const Color darkBlue = Color(0xFF111E34);
  static const Color green = Color(0xFF2EF77A);
  static const Color lightBlue = Color(0xFFFAF9F6);

  // ── Protective Semantics (Tidak Berubah) ──
  static const Color sosCoral = Color(0xFFFF5D5D);
  static const Color sosDeep = Color(0xFFD92632);
  static const Color safeTeal = Color(0xFF2DD4BF);
  static const Color warnAmber = Color(0xFFFBBF24);

  // ── Text & Surface ──
  static const Color textOnBlue = Colors.white;
  static const Color textOnGreen = Color(0xFF011E34);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E304F);
  static const Color borderLight = Color(0xFFDCE7F5);
  static const Color borderDark = Color(0xFF25395B);
  static const Color charcoal = Color(0xFF262626);
}

/// MekaarColors — Kelas utilitas warna MEKAAR dengan kompatibilitas dan context-aware helpers.
class MekaarColors {
  MekaarColors._();

  // ── Brand Core ──
  static const Color blue = AppColors.blue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color green = AppColors.green;
  static const Color lightBlue = AppColors.lightBlue;
  static const Color charcoal = AppColors.charcoal;

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

  // ── Palet Taktis & Darurat (Stealth OLED) ──
  static const Color stealthBg = Color(0xFF000000); // OLED Pure Black (Zero glow)
  static const Color stealthSurface = Color(0xFF0F172A); // Slate 900
  static const Color stealthCard = Color(0xFF1E293B); // Slate 800
  static const Color stealthCardBorder = Color(0xFF334155); // Slate 700
  static const Color stealthText = Color(0xFFF8FAFC); // Slate 50
  static const Color stealthTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color stealthSuccess = Color(0xFF22C55E); // Green 500
  static const Color stealthWarning = Color(0xFFF59E0B); // Amber 500
  static const Color stealthDanger = Color(0xFFEF4444); // Red 500

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

  @Deprecated('Gunakan MekaarColors.textSecondaryLight.')
  static const Color textMutedLight = Color(0xFF5C6B85);

  @Deprecated('Gunakan MekaarColors.textSecondaryDark.')
  static const Color textMutedDark = Color(0xFF9FB0C9);

  @Deprecated('Gunakan MekaarColors.textMutedOf(context) untuk kontras yang adaptif.')
  static const Color textMuted = Color(0xFF6B7599);

  static const Color textOnBlue = AppColors.textOnBlue;
  static const Color textOnGreen = AppColors.textOnGreen;
  static const Color textOnYellow = Color(0xFF2B2400);
  static const Color textOnLime = AppColors.textOnGreen;

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
  @Deprecated('Gunakan MekaarColors.sosCoral sebagai token resmi.')
  static const Color softCoral = AppColors.sosCoral;

  @Deprecated('Gunakan MekaarColors.sosDeep atau AppColors.sosDeep.')
  static const Color sosRed = AppColors.sosDeep;

  @Deprecated('Gunakan MekaarColors.safeTeal sebagai token resmi.')
  static const Color guardianTeal = AppColors.safeTeal;
  static const Color sosLight = Color(0xFFFFF1F2);
  static const Color guardianLight = Color(0xFFE6FFFA);
  static const Color success = Color(0xFF10B981);

  /// Warna hijau terang kontras untuk status bukti baca (centang ganda terbaca ala WhatsApp).
  static const Color readReceiptGreen = Color(0xFF25D366);

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

  static Color primaryOf(BuildContext c) => Theme.of(c).colorScheme.primary;

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
    return isDark ? textSecondaryDark : textSecondaryLight;
  }

  /// Warna aksen yang tetap terbaca sebagai teks/ikon di permukaan terang:
  /// biru brand di light mode (cyan #38BDF8 gagal kontras di atas putih),
  /// cyan di dark mode.
  static Color accentTextOf(BuildContext c) => isDarkContext(c) ? cyan : blue;

  /// Teal semantik "aman/guardian" untuk teks & ikon:
  /// terang di dark mode, tinta gelap kontras-tinggi di light mode.
  static Color safeTextOf(BuildContext c) =>
      isDarkContext(c) ? safeTeal : safeTealInk;

  static Color outgoingBubbleOf(BuildContext c) => AppColors.blue;

  static Color outgoingBubbleBorderOf(BuildContext c) => Colors.transparent;

  /// Warna teks pada gelembung keluar (outgoing).
  /// Otomatis beralih ke warna gelap kontras tinggi (AppColors.darkBlue)
  /// jika warna latar gelembung memiliki luminansi terang (luminance > 0.5)
  /// untuk memenuhi standar aksesibilitas kontras WCAG AA.
  static Color outgoingTextOf(BuildContext c, [Color? bubbleColor]) {
    if (bubbleColor != null) {
      final luminance = bubbleColor.computeLuminance();
      return luminance > 0.5 ? AppColors.darkBlue : Colors.white;
    }
    return Colors.white;
  }
}

/// MekaarColorTokens — Sistem token warna semantik deklaratif (ThemeExtension).
///
/// Menyediakan resolusi tema modern dengan dukungan transisi mulus (`lerp`)
/// dan integrasi native ke `Theme.of(context).extension<MekaarColorTokens>()`.
@immutable
class MekaarColorTokens extends ThemeExtension<MekaarColorTokens> {
  final Color surfaceCanvas;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color borderSubtle;
  final Color borderInteractive;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brandPrimary;
  final Color brandSecondary;
  final Color onBrandPrimary;
  final Color onBrandSecondary;
  final Color bubbleOutgoingBg;
  final Color bubbleOutgoingText;
  final Color bubbleIncomingBg;
  final Color bubbleIncomingText;
  final Color statusDangerBg;
  final Color statusDangerText;

  const MekaarColorTokens({
    required this.surfaceCanvas,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.borderSubtle,
    required this.borderInteractive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandPrimary,
    required this.brandSecondary,
    required this.onBrandPrimary,
    required this.onBrandSecondary,
    required this.bubbleOutgoingBg,
    required this.bubbleOutgoingText,
    required this.bubbleIncomingBg,
    required this.bubbleIncomingText,
    required this.statusDangerBg,
    required this.statusDangerText,
  });

  static const light = MekaarColorTokens(
    surfaceCanvas: AppColors.lightBlue,
    surfaceCard: AppColors.cardLight,
    surfaceElevated: Colors.white,
    borderSubtle: AppColors.borderLight,
    borderInteractive: Color(0xFF8CA2C0),
    textPrimary: AppColors.darkBlue,
    textSecondary: Color(0xFF5C6B85),
    textMuted: Color(0xFF5C6B85),
    brandPrimary: AppColors.blue,
    brandSecondary: AppColors.green,
    onBrandPrimary: Colors.white,
    onBrandSecondary: AppColors.textOnGreen,
    bubbleOutgoingBg: AppColors.blue,
    bubbleOutgoingText: Colors.white,
    bubbleIncomingBg: Colors.white,
    bubbleIncomingText: AppColors.darkBlue,
    statusDangerBg: AppColors.sosDeep,
    statusDangerText: Colors.white,
  );

  static const dark = MekaarColorTokens(
    surfaceCanvas: AppColors.darkBlue,
    surfaceCard: AppColors.cardDark,
    surfaceElevated: Color(0xFF25395B),
    borderSubtle: AppColors.borderDark,
    borderInteractive: Color(0xFF9FB0C9),
    textPrimary: Color(0xFFF4F9FF),
    textSecondary: Color(0xFF9FB0C9),
    textMuted: Color(0xFF9FB0C9),
    brandPrimary: AppColors.blue,
    brandSecondary: AppColors.green,
    onBrandPrimary: Colors.white,
    onBrandSecondary: AppColors.textOnGreen,
    bubbleOutgoingBg: AppColors.blue,
    bubbleOutgoingText: Colors.white,
    bubbleIncomingBg: AppColors.cardDark,
    bubbleIncomingText: Color(0xFFF4F9FF),
    statusDangerBg: AppColors.sosDeep,
    statusDangerText: Colors.white,
  );

  static const stealth = MekaarColorTokens(
    surfaceCanvas: Color(0xFF000000),
    surfaceCard: Color(0xFF0F172A),
    surfaceElevated: Color(0xFF1E293B),
    borderSubtle: Color(0xFF334155),
    borderInteractive: Color(0xFF475569),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF94A3B8),
    brandPrimary: AppColors.blue,
    brandSecondary: AppColors.green,
    onBrandPrimary: Colors.white,
    onBrandSecondary: AppColors.textOnGreen,
    bubbleOutgoingBg: Color(0xFF334155),
    bubbleOutgoingText: Color(0xFFE2E8F0),
    bubbleIncomingBg: Color(0xFF0F172A),
    bubbleIncomingText: Color(0xFFE2E8F0),
    statusDangerBg: AppColors.sosDeep,
    statusDangerText: Colors.white,
  );

  /// Helper akses deklaratif berbasis konteks
  static MekaarColorTokens of(BuildContext context) {
    return Theme.of(context).extension<MekaarColorTokens>() ??
        (MekaarColors.isDarkContext(context) ? dark : light);
  }

  @override
  MekaarColorTokens copyWith({
    Color? surfaceCanvas,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? borderSubtle,
    Color? borderInteractive,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brandPrimary,
    Color? brandSecondary,
    Color? onBrandPrimary,
    Color? onBrandSecondary,
    Color? bubbleOutgoingBg,
    Color? bubbleOutgoingText,
    Color? bubbleIncomingBg,
    Color? bubbleIncomingText,
    Color? statusDangerBg,
    Color? statusDangerText,
  }) {
    return MekaarColorTokens(
      surfaceCanvas: surfaceCanvas ?? this.surfaceCanvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderInteractive: borderInteractive ?? this.borderInteractive,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      onBrandPrimary: onBrandPrimary ?? this.onBrandPrimary,
      onBrandSecondary: onBrandSecondary ?? this.onBrandSecondary,
      bubbleOutgoingBg: bubbleOutgoingBg ?? this.bubbleOutgoingBg,
      bubbleOutgoingText: bubbleOutgoingText ?? this.bubbleOutgoingText,
      bubbleIncomingBg: bubbleIncomingBg ?? this.bubbleIncomingBg,
      bubbleIncomingText: bubbleIncomingText ?? this.bubbleIncomingText,
      statusDangerBg: statusDangerBg ?? this.statusDangerBg,
      statusDangerText: statusDangerText ?? this.statusDangerText,
    );
  }

  @override
  MekaarColorTokens lerp(ThemeExtension<MekaarColorTokens>? other, double t) {
    if (other is! MekaarColorTokens) return this;
    return MekaarColorTokens(
      surfaceCanvas: Color.lerp(surfaceCanvas, other.surfaceCanvas, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderInteractive:
          Color.lerp(borderInteractive, other.borderInteractive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t)!,
      onBrandPrimary: Color.lerp(onBrandPrimary, other.onBrandPrimary, t)!,
      onBrandSecondary:
          Color.lerp(onBrandSecondary, other.onBrandSecondary, t)!,
      bubbleOutgoingBg:
          Color.lerp(bubbleOutgoingBg, other.bubbleOutgoingBg, t)!,
      bubbleOutgoingText:
          Color.lerp(bubbleOutgoingText, other.bubbleOutgoingText, t)!,
      bubbleIncomingBg:
          Color.lerp(bubbleIncomingBg, other.bubbleIncomingBg, t)!,
      bubbleIncomingText:
          Color.lerp(bubbleIncomingText, other.bubbleIncomingText, t)!,
      statusDangerBg: Color.lerp(statusDangerBg, other.statusDangerBg, t)!,
      statusDangerText:
          Color.lerp(statusDangerText, other.statusDangerText, t)!,
    );
  }
}

class MekaarGradients {
  MekaarGradients._();

  static const LinearGradient canvasDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.darkBlue, AppColors.darkBlue],
  );

  static const LinearGradient canvasLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.lightBlue, AppColors.lightBlue],
  );

  static const LinearGradient canvasSos = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.sosDeep, AppColors.sosCoral],
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
