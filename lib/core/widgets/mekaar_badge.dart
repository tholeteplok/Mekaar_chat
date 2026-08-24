import 'package:flutter/material.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';

/// Pill status standar MEKAAR — satu bahasa untuk badge "Aktif", "Kadaluarsa",
/// "Menunggu Persetujuan", dsb.
///
/// Latar dihitung dari [color] (tint alpha 0.12) sehingga selalu adaptif
/// terhadap token intent yang dikirim pemanggil (`successTextOf`,
/// `safeTextOf`, `sosRed`, `warnAmber`, dst.). Jangan kirim warna statis
/// light-only seperti `successLight` sebagai latar.
class MekaarBadge extends StatelessWidget {
  final String label;
  final Color color;

  /// Override latar bila perlu tint berbeda; default `color` @ 0.12.
  final Color? backgroundColor;
  final IconData? icon;
  final bool outlined;

  const MekaarBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.icon,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MekaarRadius.pill),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.30))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: MekaarTypography.labelSM.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
