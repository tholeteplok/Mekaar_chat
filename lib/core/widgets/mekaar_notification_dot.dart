import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// MekaarNotificationDot — Indikator titik notifikasi terpusat MEKAAR.
///
/// Digunakan untuk menandai adanya aksi tertunda (misalnya undangan Guardian masuk)
/// di atas ikon AppBar atau disandingkan di dalam label Tab.
class MekaarNotificationDot extends StatelessWidget {
  final Widget? child;
  final bool show;
  final Color? color;
  final double size;
  final Offset offset;
  final Color? borderColor;
  final double borderWidth;

  const MekaarNotificationDot({
    super.key,
    required this.child,
    required this.show,
    this.color,
    this.size = 8.5,
    this.offset = const Offset(2, -2),
    this.borderColor,
    this.borderWidth = 1.5,
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
    if (targetChild == null) {
      return show ? standalone(color: color, size: size, context: context) : const SizedBox.shrink();
    }

    if (!show) {
      return targetChild;
    }

    final dotColor = color ?? MekaarColors.warnAmber;
    final strokeColor = borderColor ?? MekaarColors.surfaceOf(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        targetChild,
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
