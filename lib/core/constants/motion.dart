import 'package:flutter/widgets.dart';

/// MekaarMotion — Durasi & kurva animasi terpusat.
/// Semua animasi/transisi WAJIB memakai konstanta dari sini agar konsisten.
class MekaarMotion {
  MekaarMotion._();

  // Durasi
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration pop = Duration(milliseconds: 280);
  static const Duration counter = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration playful = Duration(milliseconds: 500);
  static const Duration cinematic = Duration(milliseconds: 800);
  static const Duration idle = Duration(milliseconds: 1500);

  /// Loop indikator hidup (pulse banner, shimmer, waveform) — bukan transisi.
  static const Duration loop = Duration(milliseconds: 1000);

  /// Jeda antar-item animasi staggered list; pasangkan dengan [staggerMax].
  static const Duration staggerStep = Duration(milliseconds: 40);
  static const Duration staggerMax = Duration(milliseconds: 240);

  // Kurva
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve bounce = Curves.easeOutBack;
}

/// Helper context untuk menghormati preferensi reduce-motion sistem.
extension MekaarMotionContext on BuildContext {
  /// True bila sistem meminta animasi dikurangi/dimatikan.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// Durasi efektif: Duration.zero bila reduce-motion aktif.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}
