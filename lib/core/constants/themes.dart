import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'dimensions.dart';
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
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xF6FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.md),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        textStyle: const TextStyle(
          color: Color(0xFF1B2145),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MekaarColors.softCoral;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MekaarColors.softCoral.withValues(alpha: 0.35);
          }
          return null;
        }),
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
      primary: MekaarColors.yellow,
      onPrimary: MekaarColors.textOnYellow,
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
      onPrimary: MekaarColors.surfaceDark,
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
      primary: MekaarColors.softCoral,
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
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xF6FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.md),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        textStyle: TextStyle(
          color: onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
    );
  }

  static ThemeData darkTheme([String fontFamily = 'Plus Jakarta Sans']) {
    MekaarTypography.fontFamily = fontFamily;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: MekaarColors.purple,
      scaffoldBackgroundColor:
          Colors.transparent, // Let gradient canvas handle background
      colorScheme: const ColorScheme.dark(
        primary: MekaarColors.purple,
        secondary: MekaarColors.safeTeal,
        error: MekaarColors.sosRed,
        surface: MekaarColors.cardDark,
        onPrimary: Colors.white,
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
        selectedItemColor: MekaarColors.purple,
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
          borderSide: const BorderSide(color: MekaarColors.purple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MekaarColors.purple,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 4,
          shadowColor: MekaarColors.purple.withValues(alpha: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(), // Pill shape
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xF2181D2E),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.md),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
        ),
        textStyle: const TextStyle(
          color: MekaarColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MekaarColors.purple;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MekaarColors.purple.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
    );
  }
}
