import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

/// MekaarLiveSafetyPill — Kapsul status keselamatan interaktif.
///
/// Menampilkan indikator status perlindungan (E2EE, Guardian Siaga, GPS)
/// secara solid, bersih, dan elegan tanpa pemicu render loop terus-menerus.
class MekaarLiveSafetyPill extends StatelessWidget {
  final String? label;
  final int? activeGuardiansCount;
  final bool isE2eeActive;
  final VoidCallback? onTap;

  const MekaarLiveSafetyPill({
    super.key,
    this.label,
    this.activeGuardiansCount,
    this.isE2eeActive = true,
    this.onTap,
  });

  String _buildDisplayText() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    }
    final parts = <String>[];
    if (activeGuardiansCount != null && activeGuardiansCount! > 0) {
      parts.add('$activeGuardiansCount Guardian Siaga');
    }
    if (isE2eeActive) {
      parts.add('Aegis E2EE');
    }
    if (parts.isEmpty) {
      parts.add('Aegis Aktif');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? MekaarColors.guardianTeal.withValues(alpha: 0.12)
        : MekaarColors.guardianTeal.withValues(alpha: 0.08);

    final borderColor = isDark
        ? MekaarColors.guardianTeal.withValues(alpha: 0.25)
        : MekaarColors.guardianTeal.withValues(alpha: 0.20);

    return Semantics(
      button: onTap != null,
      label: 'Status keselamatan: ${_buildDisplayText()}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap != null
              ? () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  onTap!();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  SolarIconsBold.shieldCheck,
                  size: 14,
                  color: MekaarColors.guardianTeal,
                ),
                const SizedBox(width: 6),
                Text(
                  _buildDisplayText(),
                  style: MekaarTypography.labelSM.copyWith(
                    color: MekaarColors.guardianTeal,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
