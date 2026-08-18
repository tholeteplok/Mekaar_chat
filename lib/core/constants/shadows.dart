import 'package:flutter/material.dart';

/// MekaarShadows — Elevation/shadow terpusat sesuai spesifikasi Core UI.
/// Shadow lembut & tipis (0 4px 16px rgba(21, 38, 65, 0.06)) di atas kanvas flat.
class MekaarShadows {
  MekaarShadows._();

  /// Bayangan dinamis untuk kartu berdasarkan tema (gelap/terang)
  static List<BoxShadow> cardDynamic(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const [
        BoxShadow(
          color: Color(0x330A0E1A), // Tipis di dark mode
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x0F152641), // rgba(21, 38, 65, 0.06)
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ];
  }

  /// Bayangan halus untuk kartu & tile (legacy / fallback)
  static List<BoxShadow> get card => const [
        BoxShadow(
          color: Color(0x0F152641), // rgba(21, 38, 65, 0.06)
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  /// Bayangan sangat halus untuk chat bubble.
  static List<BoxShadow> get bubble => const [
        BoxShadow(
          color: Color(0x08152641),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Bayangan mengambang untuk FAB, bottom sheet, dialog.
  static List<BoxShadow> get floating => const [
        BoxShadow(
          color: Color(0x14152641),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ];
}

