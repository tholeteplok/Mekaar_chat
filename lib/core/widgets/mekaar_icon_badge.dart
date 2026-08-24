import 'package:flutter/material.dart';
import '../constants/dimensions.dart';

/// Kontainer ikon standar untuk tile/list/card di seluruh app.
///
/// Satu bahasa bentuk: squircle 44×44 (`MekaarRadius.sm`) atau lingkaran 44.
/// Warna selalu adaptif — kirim warna intent via [color] dan biarkan latar
/// dihitung dari alpha-nya, atau kirim [backgroundColor] eksplisit dari
/// helper `*Of(context)`.
class MekaarIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;
  final bool circle;

  const MekaarIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.size = MekaarSizes.iconBadge,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius:
            circle ? null : BorderRadius.circular(MekaarRadius.sm),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: color,
      ),
    );
  }
}
