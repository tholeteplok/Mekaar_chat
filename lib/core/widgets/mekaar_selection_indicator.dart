import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/motion.dart';
import 'avatar.dart';

/// Token warna terpusat untuk sorotan baris / kartu saat mode multi-select aktif.
class MekaarSelectionColors {
  const MekaarSelectionColors._();

  /// Mengembalikan warna latar sorotan item berdasarkan status terpilih & tema.
  static Color rowHighlight(
    BuildContext context, {
    required bool isSelected,
  }) {
    if (!isSelected) return Colors.transparent;
    final isDark = MekaarColors.isDarkContext(context);
    return MekaarColors.primaryOf(context).withValues(alpha: isDark ? 0.16 : 0.09);
  }
}

/// Pembungkus terpusat [Avatar] dengan indikator seleksi animasi di pojok kanan bawah.
///
/// Saat [isSelectionMode] aktif:
/// - Jika [isSelected] `true`: menampilkan lencana centang solid warna primer.
/// - Jika [isSelected] `false`: tetap menampilkan avatar bersih tanpa lencana.
class MekaarSelectionAvatar extends StatelessWidget {
  final String? initial;
  final String? imageUrl;
  final double size;
  final bool isGuardian;
  final Object? heroTag;
  final bool isSelectionMode;
  final bool isSelected;
  final Widget? fallbackBadge;

  const MekaarSelectionAvatar({
    super.key,
    this.initial,
    this.imageUrl,
    this.size = 48,
    this.isGuardian = false,
    this.heroTag,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.fallbackBadge,
  });

  @override
  Widget build(BuildContext context) {
    final showCheck = isSelectionMode && isSelected;
    final badgeSize = (size * 0.42).clamp(18.0, 22.0);
    final duration = context.motion(MekaarMotion.fast);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        Avatar(
          initial: initial,
          imageUrl: imageUrl,
          size: size,
          isGuardian: isGuardian,
          heroTag: heroTag,
        ),
        if (!showCheck && fallbackBadge != null) fallbackBadge!,
        Positioned(
          right: -2,
          bottom: -2,
          child: AnimatedScale(
            scale: showCheck ? 1.0 : 0.0,
            duration: duration,
            curve: MekaarMotion.bounce,
            child: AnimatedOpacity(
              opacity: showCheck ? 1.0 : 0.0,
              duration: duration,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: MekaarColors.primaryOf(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MekaarColors.surfaceOf(context),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: badgeSize * 0.62,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
