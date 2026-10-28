import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class Avatar extends StatelessWidget {
  final String? initial;
  final String? imageUrl;
  final double size;
  final bool isGuardian;
  final Color? backgroundColor;
  final bool useCrayonStyle;

  const Avatar({
    super.key,
    this.initial,
    this.imageUrl,
    this.size = 48,
    this.isGuardian = false,
    this.backgroundColor,
    this.useCrayonStyle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final innerSize = isGuardian ? size - 4 : size;
    final letter = initial?.isNotEmpty == true
        ? initial![0].toUpperCase()
        : '?';

    Widget avatarChild;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final cacheDim = (innerSize * MediaQuery.devicePixelRatioOf(context))
          .round();
      avatarChild = ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: innerSize,
          height: innerSize,
          cacheWidth: cacheDim > 0 ? cacheDim : null,
          cacheHeight: cacheDim > 0 ? cacheDim : null,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialWidget(context, letter, innerSize, isDark),
        ),
      );
    } else {
      avatarChild = _buildInitialWidget(context, letter, innerSize, isDark);
    }

    final BoxDecoration boxDecoration;
    if (useCrayonStyle && (imageUrl == null || imageUrl!.isEmpty)) {
      final circleBg = isDark
          ? const Color(0xFF152641)
          : const Color(0xFFFFFDF8);
      final circleBorder = isDark
          ? const Color(0x33CBD5E1)
          : const Color(0x261E293B);

      boxDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? circleBg,
        border: Border.all(color: circleBorder, width: 1.0),
      );
    } else {
      final avatarColor = backgroundColor ?? _getAvatarColor(initial);
      boxDecoration = BoxDecoration(shape: BoxShape.circle, color: avatarColor);
    }

    final coreWidget = Container(
      width: innerSize,
      height: innerSize,
      decoration: boxDecoration,
      clipBehavior: Clip.antiAlias,
      child: ClipOval(child: avatarChild),
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

  Widget _buildInitialWidget(
    BuildContext context,
    String letter,
    double innerSize,
    bool isDark,
  ) {
    if (!useCrayonStyle) {
      final avatarColor = backgroundColor ?? _getAvatarColor(initial);
      final inkColor = _inkFor(avatarColor);
      return Center(
        child: Text(
          letter,
          style: TextStyle(
            color: inkColor,
            fontSize: innerSize * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // Pola Inisial Biru MEKAAR: Font Acidic Murni, Miring Kiri 25°, Font Besar Terpotong Kontainer
    final fontSize = innerSize * 1.12;

    return Center(
      child: Transform.rotate(
        angle: -25 * (math.pi / 180), // Miring kiri 25 derajat
        child: Text(
          letter,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Acidic',
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.blue,
            fontFamilyFallback: const ['PlusJakartaSans', 'sans-serif'],
          ),
        ),
      ),
    );
  }

  /// Tinta inisial dipilih dari luminansi latar agar kontras selalu memadai
  /// (putih di atas warning/success hanya ≈2:1).
  Color _inkFor(Color bg) {
    return bg.computeLuminance() > 0.5 ? AppColors.darkBlue : Colors.white;
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
