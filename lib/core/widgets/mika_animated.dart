import 'package:flutter/material.dart';
import 'mika_illustration.dart';

/// Reaksi satu-kali yang dimainkan oleh [MikaAnimated] (kompatibilitas).
enum MikaReaction {
  happy,
  love,
  hi,
  ok,
  huft,
  shield,
  ask,
  sleep,
  phone,
  pin,
  hide,
  neutral;

  Duration get duration => Duration.zero;
}

/// Widget maskot Mika terpusat berbasis aset WebP baru.
class MikaAnimated extends StatelessWidget {
  const MikaAnimated({
    super.key,
    this.illustration,
    this.pose,
    this.size = 180,
    this.idle = true,
    this.semanticLabel,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.reaction,
    this.isDarkOverride,
    this.customOffset,
    this.customScale,
  });

  final MikaIllustrationType? illustration;
  final MikaPose? pose;
  final double size;
  final bool idle;
  final String? semanticLabel;
  final BoxFit fit;
  final Alignment alignment;
  final MikaReaction? reaction;
  final bool? isDarkOverride;
  final Offset? customOffset;
  final double? customScale;

  void react(MikaReaction reaction) {}

  @override
  Widget build(BuildContext context) {
    final effectiveType = illustration ?? (pose != null ? pose!.illustrationType : MikaIllustrationType.emptyChat);
    return MikaIllustration(
      type: effectiveType,
      size: size,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
    );
  }
}
