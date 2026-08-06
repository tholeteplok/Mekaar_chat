import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

enum BlurPosition { top, bottom, none }

/// MekaarGlassBlurContainer — Komponen terpusat pembungkus efek Backdrop Blur + Semi-Transparan Floating Glass
/// bergaya iOS & Modern Flutter.
class MekaarGlassBlurContainer extends StatelessWidget {
  final Widget child;
  final BlurPosition position;
  final double blurSigma;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Color? customColor;
  final bool isFloating;

  const MekaarGlassBlurContainer({
    super.key,
    required this.child,
    this.position = BlurPosition.none,
    this.blurSigma = 16.0,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.border,
    this.boxShadow,
    this.customColor,
    this.isFloating = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = customColor ??
        (isFloating
            ? (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.22))
            : MekaarColors.backgroundOf(context));

    final BoxBorder? effectiveBorder = border ??
        (isFloating
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.12),
                width: 1.0,
              )
            : null);

    final List<BoxShadow>? effectiveShadow = boxShadow ??
        (isFloating
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null);

    final AlignmentGeometry beginAlign =
        position == BlurPosition.bottom ? Alignment.bottomCenter : Alignment.topCenter;
    final AlignmentGeometry endAlign =
        position == BlurPosition.bottom ? Alignment.topCenter : Alignment.bottomCenter;

    final gradient = position != BlurPosition.none
        ? LinearGradient(
            begin: beginAlign,
            end: endAlign,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              bgColor.withValues(alpha: isDark ? 0.35 : 0.25),
              bgColor.withValues(alpha: isDark ? 0.15 : 0.10),
              bgColor.withValues(alpha: 0.0),
            ],
          )
        : null;

    // Mode gradient (top/bottom) = full-width tanpa radius agar fade menyentuh tepi layar.
    // Mode none (isFloating capsule) = gunakan borderRadius yang ditentukan.
    final effectiveRadius = position != BlurPosition.none
        ? BorderRadius.zero
        : (borderRadius ?? BorderRadius.circular(24));

    final containerDecoration = BoxDecoration(
      color: position == BlurPosition.none ? bgColor : null,
      gradient: gradient,
      borderRadius: shape == BoxShape.rectangle ? effectiveRadius : null,
      shape: shape,
      border: effectiveBorder,
      boxShadow: effectiveShadow,
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: containerDecoration,
      child: child,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return ClipPath(
      clipper: shape == BoxShape.circle ? const _CircleClipper() : null,
      child: ClipRRect(
        // Gradient mode: tidak ada clipping radius (full-width).
        // Floating mode: clip mengikuti effectiveRadius.
        borderRadius: shape == BoxShape.rectangle ? effectiveRadius : BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper();

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
