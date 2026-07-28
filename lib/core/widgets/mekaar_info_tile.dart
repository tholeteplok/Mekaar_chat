import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';

/// Widget terpusat untuk baris informasi (icon + label + value) yang konsisten.
///
/// Standar UI Mekaar:
/// - Container icon: 44×44, radius 12
/// - Icon size: 22, warna: textSecondaryOf(context)
/// - Label: bodySM (14px)
/// - Value: bodyMD (16px), warna: textPrimaryOf(context)
///
/// Digunakan di profil, settings, dan screen lain yang menampilkan
/// pasangan label–value dengan icon.
class MekaarInfoTile extends StatelessWidget {
  const MekaarInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = iconColor ??
        (isDestructive
            ? MekaarColors.sosRed
            : MekaarColors.textSecondaryOf(context));

    final row = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? MekaarColors.cardDark
                : MekaarColors.surface2Of(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: effectiveIconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MekaarTypography.bodySM),
              Text(
                value,
                style: MekaarTypography.bodyMD.copyWith(
                  color: isDestructive
                      ? MekaarColors.sosRed
                      : MekaarColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: row,
      );
    }

    return row;
  }
}
