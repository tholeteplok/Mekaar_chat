import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/motion.dart';
import '../../../core/constants/onboarding_tokens.dart';
import '../../../core/services/haptic_service.dart';

/// Item Maskot Lottie untuk Panggung Konveyor Paralaks Onboarding MEKAAR.
/// Mengoptimalkan siklus CPU/GPU dengan menghentikan animasi saat berada di luar
/// viewport pandang, serta mendukung interaksi Tap Spring Bounce (Easter Egg).
class MekaarLottieParallaxItem extends StatefulWidget {
  const MekaarLottieParallaxItem({
    super.key,
    required this.assetPath,
    required this.distance,
    this.size = MekaarOnboardingTokens.mascotSize,
    this.semanticLabel,
  });

  final String assetPath;
  final double distance;
  final double size;
  final String? semanticLabel;

  @override
  State<MekaarLottieParallaxItem> createState() =>
      _MekaarLottieParallaxItemState();
}

class _MekaarLottieParallaxItemState extends State<MekaarLottieParallaxItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapMascot() {
    if (_bounceController.isAnimating) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    _bounceController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // Hanya putar animasi saat karakter berada dalam fokus atau mengintip di panggung
    final shouldAnimate = widget.distance < 1.1;

    // Kalkulasi Depth of Field Blur (0 di tengah, s.d. 3.5 di tepi panggung)
    final double rawBlur = (widget.distance * 2.8).clamp(0.0, MekaarOnboardingTokens.maxMascotBlur);
    final double effectiveBlur = context.reduceMotion ? 0.0 : rawBlur;

    Widget lottieWidget = Lottie.asset(
      widget.assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      animate: shouldAnimate,
      repeat: true,
      frameRate: FrameRate.composition,
    );

    // Terapkan filter blur bila karakter sedang mengintip di tepi panggung
    if (effectiveBlur > 0.4) {
      lottieWidget = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
          tileMode: TileMode.decal,
        ),
        child: lottieWidget,
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? 'Maskot Mika',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTapMascot,
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value,
              alignment: Alignment.bottomCenter,
              child: child,
            );
          },
          child: lottieWidget,
        ),
      ),
    );
  }
}
