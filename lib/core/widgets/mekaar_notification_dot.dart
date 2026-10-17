import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// MekaarNotificationDot — Indikator titik & lencana notifikasi terpusat MEKAAR.
///
/// Digunakan untuk menandai adanya aksi tertunda (misalnya undangan Guardian masuk)
/// atau menampilkan jumlah aktif (badge angka hijau) di atas ikon AppBar/Tab.
class MekaarNotificationDot extends StatelessWidget {
  final Widget? child;
  final bool show;
  final Color? color;
  final double size;
  final Offset offset;
  final Color? borderColor;
  final double borderWidth;

  /// Jumlah angka dinamis yang ditampilkan di dalam badge (misal: jumlah Guardian aktif)
  final int? badgeCount;

  /// Warna latar badge angka (default: MekaarColors.primaryOf(context))
  final Color? badgeColor;

  /// Menampilkan titik peringatan/pending (misal: dot amber di sudut badge angka)
  final bool showDot;

  const MekaarNotificationDot({
    super.key,
    required this.child,
    this.show = true,
    this.color,
    this.size = 8.5,
    this.offset = const Offset(2, -2),
    this.borderColor,
    this.borderWidth = 1.5,
    this.badgeCount,
    this.badgeColor,
    this.showDot = false,
  });

  /// Dot indikator mandiri (misalnya untuk diletakkan di dalam Row Tab bar).
  static Widget standalone({
    Key? key,
    Color? color,
    double size = 8.0,
    BuildContext? context,
  }) {
    final dotColor = color ?? MekaarColors.warnAmber;
    return Container(
      key: key,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetChild = child;
    final hasCount = badgeCount != null && badgeCount! > 0;
    final isDotActive = showDot || (show && !hasCount);

    if (targetChild == null) {
      return isDotActive
          ? standalone(color: color, size: size, context: context)
          : const SizedBox.shrink();
    }

    if (!hasCount && !isDotActive) {
      return targetChild;
    }

    final dotColor = color ?? MekaarColors.warnAmber;
    final strokeColor = borderColor ?? MekaarColors.surfaceOf(context);
    final countBgColor = badgeColor ?? MekaarColors.primaryOf(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        targetChild,
        if (hasCount) ...[
          Positioned(
            top: offset.dy - 3,
            right: offset.dx - 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: BoxDecoration(
                color: countBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: strokeColor,
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: countBgColor.withValues(alpha: 0.45),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
          if (showDot)
            Positioned(
              top: offset.dy - 5,
              right: offset.dx - 5,
              child: Container(
                width: 7.0,
                height: 7.0,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: strokeColor,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
                      blurRadius: 3,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            ),
        ] else if (isDotActive)
          Positioned(
            top: offset.dy,
            right: offset.dx,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: strokeColor,
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.45),
                    blurRadius: 3.5,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
