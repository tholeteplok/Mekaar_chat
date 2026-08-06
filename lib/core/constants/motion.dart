import 'package:flutter/animation.dart';

/// MekaarMotion — Durasi & kurva animasi terpusat.
/// Semua animasi/transisi WAJIB memakai konstanta dari sini agar konsisten.
class MekaarMotion {
  MekaarMotion._();

  // Durasi
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration playful = Duration(milliseconds: 500);
  static const Duration cinematic = Duration(milliseconds: 800);
  static const Duration counter = Duration(milliseconds: 300);
  static const Duration idle = Duration(milliseconds: 1500);

  // Kurva
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve bounce = Curves.easeOutBack;
}
