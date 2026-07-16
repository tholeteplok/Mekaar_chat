import 'package:flutter/material.dart';

/// MekaarShadows — Elevation/shadow terpusat.
/// Gantikan BoxShadow inline agar konsisten lintas komponen.
class MekaarShadows {
  MekaarShadows._();

  /// Bayangan halus untuk kartu & tile.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Bayangan sangat halus untuk chat bubble.
  static List<BoxShadow> get bubble => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Bayangan mengambang untuk FAB, bottom sheet, dialog.
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
