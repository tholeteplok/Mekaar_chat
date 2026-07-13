import 'package:flutter/material.dart';
import '../constants/colors.dart';

class Avatar extends StatelessWidget {
  final String? initial;
  final String? imageUrl;
  final double size;
  final bool isGuardian;
  final Color? backgroundColor;

  const Avatar({
    super.key,
    this.initial,
    this.imageUrl,
    this.size = 48,
    this.isGuardian = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = backgroundColor ?? _getAvatarColor(initial);
    final innerSize = isGuardian ? size - 4 : size;

    Widget avatarChild = Center(
      child: Text(
        initial?.isNotEmpty == true ? initial![0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: innerSize * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarChild = ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: innerSize,
          height: innerSize,
          errorBuilder: (context, error, stackTrace) => avatarChild,
        ),
      );
    }

    final coreWidget = Container(
      width: innerSize,
      height: innerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColor,
      ),
      child: avatarChild,
    );

    if (isGuardian) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MekaarColors.guardianTeal,
        ),
        child: coreWidget,
      );
    }

    return coreWidget;
  }

  Color _getAvatarColor(String? text) {
    if (text == null || text.isEmpty) return MekaarColors.softCoral;
    final colors = [
      MekaarColors.softCoral,
      MekaarColors.guardianTeal,
      MekaarColors.info,
      MekaarColors.success,
      MekaarColors.warning,
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
    ];
    final index = text.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[index.abs() % colors.length];
  }
}
