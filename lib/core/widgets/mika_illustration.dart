import 'package:flutter/material.dart';

enum MikaPose {
  neutral('mika.webp'),
  happy('mika_happy.webp'),
  hi('mika_hi.webp'),
  ok('mika_ok.webp'),
  love('mika_love.webp'),
  ask('mika_ask.webp'),
  huft('mika_huft.webp'),
  hide('mika_hide.webp'),
  phone('mika_phone.webp'),
  shield('mika_shield.webp');

  const MikaPose(this.fileName);

  final String fileName;

  String get assetPath => 'assets/mascot/$fileName';
}

class MikaIllustration extends StatelessWidget {
  const MikaIllustration({
    super.key,
    required this.pose,
    this.size = 120,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.semanticLabel,
    this.animate = false,
  });

  final MikaPose pose;
  final double size;
  final Alignment alignment;
  final BoxFit fit;
  final String? semanticLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final image = SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        pose.assetPath,
        fit: fit,
        alignment: alignment,
        excludeFromSemantics: semanticLabel == null,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );

    if (!animate || reduceMotion) return image;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: image,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
