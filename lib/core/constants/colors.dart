import 'package:flutter/material.dart';

class MekaarColors {
  MekaarColors._();

  // Canvas Gradients
  static const Color canvasTop = Color(0xFF161839);
  static const Color canvasMid = Color(0xFF1E2A63);
  static const Color canvasBottom = Color(0xFF2E63B8);

  // Playful accents
  static const Color yellow = Color(0xFFFFD84D);
  static const Color cyan = Color(0xFF38BDF8);
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
  static const Color textPrimary = Color(0xFFF8FAFF);      // Dark mode text primary
  static const Color textSecondary = Color(0xFFA9B4D8);    // Dark mode text secondary
  static const Color textMuted = Color(0xFF6B7599);        // Dark mode sub-text
  static const Color textOnYellow = Color(0xFF2B2400);     // Dark text for yellow button/bubble
  
  static const Color card = Color(0xFFFFFFFF);             // Light surface card
  static const Color cardDark = Color(0xFF232A52);         // Dark surface card
  static const Color surfaceOverlay = Color(0x990F1230);   // Scrim/Overlay (60% opacity)

  // Legacy/Compatibility mapping (to avoid breaking existing imports)
  static const Color softCoral = Color(0xFFFF5D5D);        // Remapped to design token sosCoral
  static const Color sosRed = Color(0xFFD92632);           // Remapped to design token sosDeep
  static const Color guardianTeal = Color(0xFF2DD4BF);     // Remapped to design token safeTeal
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
  static const Color surface2 = Color(0xFFF4F6F8);
  static const Color surface3 = Color(0xFFEAEEF2);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
}

class MekaarGradients {
  MekaarGradients._();

  static const LinearGradient canvasDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [MekaarColors.canvasTop, MekaarColors.canvasMid, MekaarColors.canvasBottom],
  );

  static const LinearGradient canvasLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4F7FF), Color(0xFFE3ECFF)],
  );

  static const LinearGradient canvasSos = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD92632), Color(0xFF7F1D2B)],
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
