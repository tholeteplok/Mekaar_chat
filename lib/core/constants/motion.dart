import 'package:flutter/animation.dart';

/// MekaarMotion — Durasi & kurva animasi terpusat.
/// Semua animasi/transisi WAJIB memakai konstanta dari sini agar konsisten.
class MekaarMotion {
  MekaarMotion._();

  // Durasi
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  // Kurva
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve bounce = Curves.easeOutBack;
}
