import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/haptic_service.dart';

/// [MekaarFrostedActionButton] — Tombol aksi bulat mengambang (FAB) terpusat
/// dengan estetika kaca buram (frosted glass) yang serasi dengan [MekaarBottomNav].
///
/// Menggunakan [BackdropFilter] blur sigma 10, latar belakang transparan adaptif
/// terhadap tema aktif, border specular tipis, serta bayangan lembut.
class MekaarFrostedActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final double size;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final String? semanticLabel;

  const MekaarFrostedActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 56.0,
    this.padding = const EdgeInsets.all(8.0),
    this.tooltip,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = (isDark ? MekaarColors.cardDark : Colors.white).withValues(
      alpha: isDark ? 0.65 : 0.55,
    );

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final buttonWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.28 : 0.09,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            padding: padding,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Center(
              child: icon,
            ),
          ),
        ),
      ),
    );

    final interactiveButton = Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onPressed == null
            ? null
            : () {
                HapticService.trigger(MekaarHapticIntent.selection);
                onPressed!();
              },
        radius: size / 2,
        customBorder: const CircleBorder(),
        child: buttonWidget,
      ),
    );

    Widget result = Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? tooltip ?? 'Tombol Aksi',
      child: interactiveButton,
    );

    if (tooltip != null) {
      result = Tooltip(
        message: tooltip!,
        child: result,
      );
    }

    return result;
  }
}
