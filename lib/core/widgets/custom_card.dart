import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/shadows.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double? borderRadius;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.border,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? Theme.of(context).cardColor;
    final radius = borderRadius ?? MekaarRadius.lg;

    final decoration = BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? (isDark ? null : Border.all(color: MekaarColors.borderLight, width: 1)),
      boxShadow: MekaarShadows.cardDynamic(context),
    );

    Widget cardWidget = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      cardWidget = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: cardWidget,
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      child: cardWidget,
    );
  }
}
