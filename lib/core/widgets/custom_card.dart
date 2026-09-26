import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/shadows.dart';

import 'mekaar_sketch_card.dart';

class CustomCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double? borderRadius;
  final bool useSketchBorder;
  final SketchCornerAccent? sketchAccent;
  final List<SketchCornerAccent>? sketchAccents;
  final int? sketchIndex;
  final int? sketchSeed;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.border,
    this.borderRadius,
    this.useSketchBorder = false,
    this.sketchAccent,
    this.sketchAccents,
    this.sketchIndex,
    this.sketchSeed,
  });

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  late final int _stableSeed;

  @override
  void initState() {
    super.initState();
    _stableSeed =
        widget.sketchSeed ?? widget.sketchIndex ?? Random().nextInt(1000);
  }

  List<SketchCornerAccent> _resolveAccents() {
    if (widget.sketchAccents != null) return widget.sketchAccents!;
    if (widget.sketchAccent != null) return [widget.sketchAccent!];
    final seed = widget.sketchSeed ?? widget.sketchIndex ?? _stableSeed;
    return MekaarSketchBorderPainter.resolveDualAccents(seed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = widget.color ?? MekaarColors.surfaceOf(context);
    final radius = widget.borderRadius ??
        (widget.useSketchBorder ? MekaarRadius.card : MekaarRadius.lg);

    if (widget.useSketchBorder) {
      final resolvedAccents = _resolveAccents();

      final decoration = BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: MekaarShadows.cardDynamic(context),
      );

      Widget cardWidget = Container(
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: decoration,
        child: widget.child,
      );

      if (widget.onTap != null) {
        cardWidget = InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          child: cardWidget,
        );
      }

      return Container(
        margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
        child: CustomPaint(
          foregroundPainter: MekaarSketchBorderPainter(
            borderRadius: radius,
            accents: resolvedAccents,
            isDark: isDark,
          ),
          child: cardWidget,
        ),
      );
    }

    final decoration = BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: widget.border ??
          (isDark
              ? null
              : Border.all(color: MekaarColors.borderLight, width: 1)),
      boxShadow: MekaarShadows.cardDynamic(context),
    );

    Widget cardWidget = Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: decoration,
      child: widget.child,
    );

    if (widget.onTap != null) {
      cardWidget = InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(radius),
        child: cardWidget,
      );
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
      child: cardWidget,
    );
  }
}
