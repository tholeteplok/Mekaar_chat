import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// MekaarTypography — Definisi terpusat semua TextStyle.
/// Semua screen WAJIB menggunakan konstanta dari sini, bukan hardcoded TextStyle.
/// Font: Plus Jakarta Sans (body/UI) + Space Grotesk (angka dan kode).
class MekaarTypography {
  MekaarTypography._();

  /// Font family aktif yang disinkronkan dengan preferensi pengguna.
  static String fontFamily = 'Plus Jakarta Sans';

  /// Font family eksklusif untuk Brand MEKAAR (Display / Hero / Wordmark)
  static const String brandFontFamily = 'Mekaar';
  static const List<String> brandFontFallbacks = ['PlusJakartaSans', 'sans-serif'];

  /// Helper terpusat untuk teks Brand Display / Hero
  static TextStyle brandDisplay({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: brandFontFamily,
      fontFamilyFallback: brandFontFallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  /// Helper terpusat untuk teks Brand Heading
  static TextStyle brandHeading({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: brandFontFamily,
      fontFamilyFallback: brandFontFallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static TextStyle _font({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: fontFeatures,
    );
  }

  /// Helper inisial profil berbasis Baloo 2 terpusat
  static TextStyle profileInitial({
    required double fontSize,
    Color? color,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );
  }

  // ─────────────────────────────────────────
  // Display — Judul besar halaman (Playful Display: Baloo 2)
  // ─────────────────────────────────────────
  static TextStyle get displayXL => GoogleFonts.baloo2(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static TextStyle get displayLG => GoogleFonts.baloo2(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static TextStyle get wordmark => const TextStyle(
    fontFamily: brandFontFamily,
    fontFamilyFallback: brandFontFallbacks,
    fontSize: 38,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.blue,
  );

  static TextStyle get tabHeader => displayLG.copyWith(color: Colors.white);

  // ─────────────────────────────────────────
  // Heading — Sub-judul & section title
  // ─────────────────────────────────────────
  static TextStyle get headingLG => GoogleFonts.baloo2(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static TextStyle get headingMD =>
      _font(fontSize: 20, fontWeight: FontWeight.w700);

  static TextStyle get headingSM =>
      _font(fontSize: 18, fontWeight: FontWeight.w700);

  /// Section Header / Judul Seksi terpusat antar-halaman
  static TextStyle get sectionHeader => _font(
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  // ─────────────────────────────────────────
  // Body — Konten utama
  // ─────────────────────────────────────────
  static TextStyle get bodyLG => _font(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle get bodyMD => _font(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle get bodySM => _font(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ─────────────────────────────────────────
  // Label — Chip, badge, caption
  // ─────────────────────────────────────────
  static TextStyle get labelLG =>
      _font(fontSize: 14, fontWeight: FontWeight.w600);

  static TextStyle get labelMD => _font(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static TextStyle get labelSM =>
      _font(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2);

  // Floor keterbacaan: caption/badge/overline tidak boleh di bawah 11px
  // agar tetap legible dan kontrasnya memadai.
  static TextStyle get caption => _font(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get badge => _font(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.0,
    letterSpacing: 0.1,
  );

  static TextStyle get snackbar => _font(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get overline => _font(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  // ─────────────────────────────────────────
  // Angka & kode — Timer, PIN dots, kode
  // ─────────────────────────────────────────
  static TextStyle get monoXL => GoogleFonts.spaceGrotesk(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 2,
  );

  static TextStyle get monoLG => GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
  );

  static TextStyle get monoMD =>
      GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600);

  // ─────────────────────────────────────────
  // Button
  // ─────────────────────────────────────────
  static TextStyle get buttonLG => _font(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static TextStyle get buttonMD =>
      _font(fontSize: 13, fontWeight: FontWeight.w700);

  // ─────────────────────────────────────────
  // Helpers — Variant warna umum
  // ─────────────────────────────────────────
  static TextStyle white(TextStyle base) => base.copyWith(color: Colors.white);
  static TextStyle coral(TextStyle base) =>
      base.copyWith(color: MekaarColors.softCoral);
  static TextStyle muted(TextStyle base) =>
      base.copyWith(color: MekaarColors.textMuted);
  static TextStyle danger(TextStyle base) =>
      base.copyWith(color: MekaarColors.sosRed);
  static TextStyle teal(TextStyle base) =>
      base.copyWith(color: MekaarColors.guardianTeal);
  /// Helper: return copy of [base] with [color] applied.
  /// Mengurangi kebutuhan copyWith(color: ...) di screen.
  static TextStyle withColor(TextStyle base, Color color) =>
      base.copyWith(color: color);
}
