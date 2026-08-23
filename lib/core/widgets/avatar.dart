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
    final inkColor = _inkFor(avatarColor);
    final innerSize = isGuardian ? size - 4 : size;

    Widget avatarChild = Center(
      child: Text(
        initial?.isNotEmpty == true ? initial![0].toUpperCase() : '?',
        style: TextStyle(
          color: inkColor,
          fontSize: innerSize * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final cacheDim = (innerSize * MediaQuery.devicePixelRatioOf(context)).round();
      avatarChild = ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: innerSize,
          height: innerSize,
          cacheWidth: cacheDim > 0 ? cacheDim : null,
          cacheHeight: cacheDim > 0 ? cacheDim : null,
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

  /// Tinta inisial dipilih dari luminansi latar agar kontras selalu memadai
  /// (putih di atas warning/success hanya ≈2:1).
  Color _inkFor(Color bg) {
    return bg.computeLuminance() > 0.5
        ? AppColors.darkBlue
        : Colors.white;
  }

  Color _getAvatarColor(String? text) {
    if (text == null || text.isEmpty) return AppColors.blue;
    final colors = [
      AppColors.blue,
      MekaarColors.guardianTeal,
      MekaarColors.info,
      MekaarColors.success,
      MekaarColors.warning,
      MekaarColors.purple,
      MekaarColors.pink,
    ];
    final index = text.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[index.abs() % colors.length];
  }
}
