import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'typography.dart';

class MekaarTheme {
  static ThemeData lightTheme([String fontFamily = 'Plus Jakarta Sans']) {
    MekaarTypography.fontFamily = fontFamily;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: MekaarColors.softCoral,
      scaffoldBackgroundColor:
          Colors.transparent, // Let gradient canvas handle background
      colorScheme: const ColorScheme.light(
        primary: MekaarColors.softCoral,
        secondary: MekaarColors.safeTeal,
        error: MekaarColors.sosRed,
        surface: MekaarColors.card,
        onPrimary: Colors.white,
        onSurface: Color(0xFF1B2145), // Dark text on light card
        onSurfaceVariant: Color(0xFF56617F),
      ),
      textTheme: GoogleFonts.getTextTheme(
        fontFamily,
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2145),
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2145),
          ),
          displaySmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2145),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2145),
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2145),
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            height: 1.6,
            color: Color(0xFF1B2145),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Color(0xFF56617F),
          ),
          bodySmall: TextStyle(fontSize: 14, color: Color(0xFF56617F)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Color(0xFF1B2145),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: MekaarColors.softCoral,
        unselectedItemColor: MekaarColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            999,
          ), // Pill shape for search/input
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: MekaarColors.softCoral, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MekaarColors.yellow,
          foregroundColor: MekaarColors.textOnYellow,
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 4,
          shadowColor: MekaarColors.yellow.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Time-based themes (auto theme: Pagi / Siang / Sore).
  // Malam reuse [darkTheme] untuk konsistensi dengan mode gelap aplikasi.
  // ─────────────────────────────────────────────────

  static ThemeData morningTheme([String fontFamily = 'Plus Jakarta Sans']) {
    MekaarTypography.fontFamily = fontFamily;
    return _buildLight(
      fontFamily,
      brightness: Brightness.light,
      primary: MekaarColors.warnAmber,
      onPrimary: Colors.white,
      surface: MekaarColors.morningSurface,
      onSurface: MekaarColors.morningOnSurface,
      statusBarIconBrightness: Brightness.dark,
    );
  }

  static ThemeData afternoonTheme([String fontFamily = 'Plus Jakarta Sans']) {
    MekaarTypography.fontFamily = fontFamily;
    return _buildLight(
      fontFamily,
      brightness: Brightness.light,
      primary: MekaarColors.cyan,
      onPrimary: Colors.white,
      surface: MekaarColors.card,
      onSurface: const Color(0xFF1B2145),
      statusBarIconBrightness: Brightness.dark,
    );
  }

  static ThemeData eveningTheme([String fontFamily = 'Plus Jakarta Sans']) {
    MekaarTypography.fontFamily = fontFamily;
    return _buildLight(
      fontFamily,
      brightness: Brightness.light,
      primary: MekaarColors.pink,
      onPrimary: Colors.white,
      surface: MekaarColors.eveningSurface,
      onSurface: MekaarColors.eveningOnSurface,
      statusBarIconBrightness: Brightness.dark,
    );
  }

  /// Builder bersama untuk 3 tema light di atas. Menghindari duplikasi
  /// TextTheme / AppBarTheme / ButtonTheme — yang berbeda hanya palet.
  static ThemeData _buildLight(
    String fontFamily, {
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color surface,
    required Color onSurface,
    required Brightness statusBarIconBrightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: MekaarColors.safeTeal,
        error: MekaarColors.sosRed,
        surface: surface,
        onPrimary: onPrimary,
        onSurface: onSurface,
        onSurfaceVariant: const Color(0xFF56617F),
      ),
      textTheme: GoogleFonts.getTextTheme(
        fontFamily,
        TextTheme(
          displayLarge: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: onSurface),
          displayMedium: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: onSurface),
          displaySmall: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: onSurface),
          headlineMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: onSurface),
          headlineSmall: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: onSurface),
          bodyLarge: TextStyle(
              fontSize: 18, height: 1.6, color: onSurface),
          bodyMedium: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: onSurface.withValues(alpha: 0.78)),
          bodySmall:
              TextStyle(fontSize: 14, color: onSurface.withValues(alpha: 0.7)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIconBrightness,
          statusBarBrightness: Brightness.light,
        ),
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primary,
        unselectedItemColor: MekaarColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  static ThemeData darkTheme([String fontFamily = 'Plus Jakarta Sans']) {
    MekaarTypography.fontFamily = fontFamily;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: MekaarColors.yellow,
      scaffoldBackgroundColor:
          Colors.transparent, // Let gradient canvas handle background
      colorScheme: const ColorScheme.dark(
        primary: MekaarColors.yellow,
        secondary: MekaarColors.safeTeal,
        error: MekaarColors.sosRed,
        surface: MekaarColors.cardDark,
        onPrimary: MekaarColors.textOnYellow,
        onSurface: MekaarColors.textPrimary,
      ),
      textTheme: GoogleFonts.getTextTheme(
        fontFamily,
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: MekaarColors.textPrimary,
          ),
          displayMedium: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: MekaarColors.textPrimary,
          ),
          displaySmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: MekaarColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: MekaarColors.textPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: MekaarColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            height: 1.6,
            color: MekaarColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: MekaarColors.textSecondary,
          ),
          bodySmall: TextStyle(fontSize: 14, color: MekaarColors.textMuted),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MekaarColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: MekaarColors.yellow,
        unselectedItemColor: MekaarColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MekaarColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            999,
          ), // Pill shape for search/input
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: MekaarColors.yellow, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MekaarColors.yellow,
          foregroundColor: MekaarColors.textOnYellow,
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 4,
          shadowColor: MekaarColors.yellow.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
