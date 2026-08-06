import 'package:flutter/material.dart';

class MekaarColors {
  MekaarColors._();

  // Canvas Gradients
  static const Color canvasTop = Color(0xFF161839);
  static const Color canvasMid = Color(0xFF1E2A63);
  static const Color canvasBottom = Color(0xFF2E63B8);

  // Playful accents & Primary Brand Token
  static const Color primary = Color(0xFF38BDF8);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFA78BFA);
  static const Color pink = Color(0xFFF472B6);
  static const Color lime = Color(0xFFA3E635);

  // Protective Semantics
  static const Color sosCoral = Color(0xFFFF5D5D);
  static const Color sosDeep = Color(0xFFD92632);
  static const Color safeTeal = Color(0xFF2DD4BF);
  static const Color warnAmber = Color(0xFFFBBF24);

  // Text & Surfaces (Base Tokens)
  static const Color textPrimary = Color(0xFFF8FAFF); // Dark mode text primary
  static const Color textSecondary = Color(
    0xFFA9B4D8,
  ); // Dark mode text secondary
  static const Color textMuted = Color(0xFF6B7599); // Dark mode sub-text
  static const Color textOnYellow = Color(
    0xFF2B2400,
  ); // Dark text for yellow button/bubble
  static const Color textOnLime = Color(
    0xFF1A2E05,
  ); // Dark text for lime button

  static const Color card = Color(0xFFFFFFFF); // Light surface card
  static const Color cardDark = Color(0xFF232A52); // Dark surface card
  static const Color surfaceOverlay = Color(
    0x990F1230,
  ); // Scrim/Overlay (60% opacity)

  // Legacy/Compatibility mapping (to avoid breaking existing imports)
  static const Color softCoral = Color(
    0xFFFF5D5D,
  ); // Remapped to design token sosCoral
  static const Color sosRed = Color(
    0xFFD92632,
  ); // Remapped to design token sosDeep
  static const Color guardianTeal = Color(
    0xFF2DD4BF,
  ); // Remapped to design token safeTeal
  static const Color sosLight = Color(0xFFFFF1F2);
  static const Color guardianLight = Color(0xFFE6FFFA);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  static const Color background = Color(0xFFFAFBFC);
  static const Color backgroundDark = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF18181B);

  // Time-based palette tokens (tema otomatis Pagi/Siang/Sore/Malam)
  // Pagi: sunrise warm
  static const Color morningSurface = Color(0xFFFFF8EE);
  static const Color morningOnSurface = Color(0xFF3D2814);
  // Sore: golden hour warm
  static const Color eveningSurface = Color(0xFFFFE4D6);
  static const Color eveningOnSurface = Color(0xFF4A1E2F);
  static const Color surface2 = Color(0xFFF4F6F8);
  static const Color surface2Dark = Color(0xFF1E2235);
  static const Color surface3 = Color(0xFFEAEEF2);
  static const Color surface3Dark = Color(0xFF252A3A);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  static Color surfaceOf(BuildContext c) =>
      Theme.of(c).colorScheme.surface;

  static Color surface2Of(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    if (isDark) return MekaarColors.surface2Dark;
    final surface = Theme.of(c).colorScheme.surface;
    if (surface == MekaarColors.morningSurface) return const Color(0xFFFFF1DF);
    if (surface == MekaarColors.eveningSurface) return const Color(0xFFFFD9C9);
    return MekaarColors.surface2;
  }

  static Color backgroundOf(BuildContext c) =>
      Theme.of(c).colorScheme.surface;

  static Color dividerOf(BuildContext c) =>
      Theme.of(c).dividerColor;

  static Color textPrimaryOf(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    if (isDark) return MekaarColors.textPrimary;
    final onSurface = Theme.of(c).colorScheme.onSurface;
    if (onSurface == Colors.white || onSurface.computeLuminance() > 0.5) {
      return const Color(0xFF1B2145);
    }
    return onSurface;
  }

  static Color textSecondaryOf(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    if (isDark) return MekaarColors.textSecondary;
    final onSurfaceVariant = Theme.of(c).colorScheme.onSurfaceVariant;
    if (onSurfaceVariant.computeLuminance() > 0.5) {
      return const Color(0xFF56617F);
    }
    return onSurfaceVariant;
  }

  static Color textMutedOf(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    if (isDark) return MekaarColors.textMuted;
    final onSurfaceVariant = Theme.of(c).colorScheme.onSurfaceVariant;
    if (onSurfaceVariant.computeLuminance() > 0.5) {
      return const Color(0xFF56617F).withValues(alpha: 0.72);
    }
    return onSurfaceVariant.withValues(alpha: 0.72);
  }

  static Color outgoingBubbleOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF2E2718)
          : const Color(0xFFFEF9C3);

  static Color outgoingBubbleBorderOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF4D3E20)
          : const Color(0xFFFDE68A);

  static Color outgoingTextOf(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFFF8FAFF)
          : const Color(0xFF1E2A63);
}

class MekaarGradients {
  MekaarGradients._();

  static const LinearGradient canvasDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      MekaarColors.canvasTop,
      MekaarColors.canvasMid,
      MekaarColors.canvasBottom,
    ],
  );

  static const LinearGradient canvasLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color.fromARGB(255, 146, 226, 253), Color(0xFFE3ECFF)],
  );

  static const LinearGradient canvasSos = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD92632), Color(0xFF7F1D2B)],
  );

  // Canvas Morning (Sunrise Glow): FF9A8B → FFC3A0 → FECF6A → A1E3FF
  static const LinearGradient canvasMorning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF9A8B), // Pink coral
      Color(0xFFFFC3A0), // Soft peach
      Color(0xFFFECF6A), // Warm yellow
      Color(0xFFA1E3FF), // Light blue
    ],
  );

  static const LinearGradient canvasAfternoon = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4F7FF), Color(0xFFE3ECFF)],
  );

  // Canvas Evening (Sunset on the Waves): FFC857 → FF6B6B → 1D3557
  static const LinearGradient canvasEvening = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFC857), // Golden yellow
      Color(0xFFFF6B6B), // Coral red
      Color(0xFF1D3557), // Deep navy
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
    colors: [Color(0xFFFF6B6B), Color(0xFFFFA07A)],
  );

  static const LinearGradient teal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF5EEAD4)],
  );
}
