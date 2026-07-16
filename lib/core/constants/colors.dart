import 'package:flutter/material.dart';

class MekaarColors {
  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  
  // Design Accents
  static const Color softCoral = Color(0xFFFF6B6B);
  static const Color sosRed = Color(0xFFEF4444);
  static const Color sosLight = Color(0xFFFFF1F2);
  static const Color guardianTeal = Color(0xFF2DD4BF);
  static const Color guardianLight = Color(0xFFE6FFFA);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);
  
  // Surface & Layout
  static const Color background = Color(0xFFFAFBFC);
  static const Color backgroundDark = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF18181B);
  static const Color surface2 = Color(0xFFF4F6F8);
  static const Color surface3 = Color(0xFFEAEEF2);
  
  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Aksen sekunder playful (untuk avatar & reaksi, tetap harmonis)
  static const Color playfulLilac = Color(0xFFA78BFA);
  static const Color playfulAmber = Color(0xFFFBBF24);
}

/// Gradient aksen — dipakai selektif untuk layer chat/sosial (bukan area SOS).
class MekaarGradients {
  MekaarGradients._();

  /// Coral → peach lembut, untuk header chat & aksen playful.
  static const LinearGradient coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFFA07A)],
  );

  /// Teal, untuk aksen guardian.
  static const LinearGradient teal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF5EEAD4)],
  );
}
