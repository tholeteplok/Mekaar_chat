import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/onboarding_tokens.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mika_illustration.dart';

/// Item Maskot Lottie untuk Panggung Konveyor Paralaks Onboarding MEKAAR.
/// Menampilkan animasi karakter kodok Mika yang berdiri kokoh di atas garis pijakan,
/// mendukung interaksi Tap Spring Bounce (Easter Egg), dan fallback aman.
class MekaarLottieParallaxItem extends StatefulWidget {
  const MekaarLottieParallaxItem({
    super.key,
    required this.assetPath,
    required this.distance,
    this.fallbackType,
    this.size = MekaarOnboardingTokens.mascotSize,
    this.semanticLabel,
  });

  final String assetPath;
  final double distance;
  final MikaIllustrationType? fallbackType;
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

    Widget lottieWidget = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        widget.assetPath,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        animate: shouldAnimate,
        repeat: true,
        frameRate: FrameRate.max,
        errorBuilder: (context, error, stackTrace) {
          if (widget.fallbackType != null) {
            return MikaIllustration(
              type: widget.fallbackType!,
              size: widget.size * 0.9,
              semanticLabel: widget.semanticLabel,
            );
          }
          return Center(
            child: Icon(
              Icons.sentiment_satisfied_alt_rounded,
              size: widget.size * 0.5,
              color: AppColors.blue,
            ),
          );
        },
      ),
    );

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
