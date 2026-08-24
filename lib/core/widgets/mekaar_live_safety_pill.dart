import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
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
    final safeColor = MekaarColors.safeTextOf(context);
    final bgColor = safeColor.withValues(alpha: 0.10);
    final borderColor = safeColor.withValues(alpha: 0.22);

    return Semantics(
      button: onTap != null,
      label: 'Status keselamatan: ${_buildDisplayText()}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MekaarRadius.pill),
          onTap: onTap != null
              ? () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  onTap!();
                }
              : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(MekaarRadius.pill),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  SolarIconsBold.shieldCheck,
                  size: 14,
                  color: safeColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _buildDisplayText(),
                  style: MekaarTypography.labelMD.copyWith(
                    color: safeColor,
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
