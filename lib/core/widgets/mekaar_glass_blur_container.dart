import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

enum BlurPosition { top, bottom, none }

/// MekaarGlassBlurContainer — Komponen terpusat pembungkus efek Backdrop Blur + Gradasi Mask Transparan
/// bergaya Telegram & Gemini Mobile.
class MekaarGlassBlurContainer extends StatelessWidget {
  final Widget child;
  final BlurPosition position;
  final double blurSigma;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? customColor;

  const MekaarGlassBlurContainer({
    super.key,
    required this.child,
    this.position = BlurPosition.top,
    this.blurSigma = 15.0,
    this.height,
    this.padding,
    this.borderRadius,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = customColor ?? MekaarColors.backgroundOf(context);

    final AlignmentGeometry beginAlign = position == BlurPosition.bottom
        ? Alignment.bottomCenter
        : Alignment.topCenter;
    final AlignmentGeometry endAlign = position == BlurPosition.bottom
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    final gradient = LinearGradient(
      begin: beginAlign,
      end: endAlign,
      colors: [
        bgColor.withValues(alpha: 0.88),
        bgColor.withValues(alpha: 0.0),
      ],
    );

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: position != BlurPosition.none ? gradient : null,
            color: position == BlurPosition.none
                ? bgColor.withValues(alpha: 0.85)
                : null,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
