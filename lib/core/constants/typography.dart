import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// MekaarTypography — Definisi terpusat semua TextStyle.
/// Semua screen WAJIB menggunakan konstanta dari sini, bukan hardcoded TextStyle.
/// Font: Plus Jakarta Sans (body/UI) + Space Grotesk (angka dan kode).
class MekaarTypography {
  MekaarTypography._();

  // ─────────────────────────────────────────
  // Display — Judul besar halaman
  // ─────────────────────────────────────────
  static TextStyle get displayXL => GoogleFonts.plusJakartaSans(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static TextStyle get displayLG => GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static TextStyle get wordmark => GoogleFonts.plusJakartaSans(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
  );

  static TextStyle get tabHeader => displayLG.copyWith(color: Colors.white);

  // ─────────────────────────────────────────
  // Heading — Sub-judul & section title
  // ─────────────────────────────────────────
  static TextStyle get headingLG =>
      GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700);

  static TextStyle get headingMD =>
      GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700);

  static TextStyle get headingSM =>
      GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700);

  // ─────────────────────────────────────────
  // Body — Konten utama
  // ─────────────────────────────────────────
  static TextStyle get bodyLG => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle get bodyMD => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle get bodySM => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ─────────────────────────────────────────
  // Label — Chip, badge, caption
  // ─────────────────────────────────────────
  static TextStyle get labelLG =>
      GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600);

  static TextStyle get labelMD => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static TextStyle get labelSM => GoogleFonts.plusJakartaSans(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static TextStyle get badge => GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    height: 1.0,
    letterSpacing: 0.1,
  );

  static TextStyle get snackbar => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get overline => GoogleFonts.plusJakartaSans(
    fontSize: 10,
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
  static TextStyle get buttonLG => GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static TextStyle get buttonMD =>
      GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700);

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
