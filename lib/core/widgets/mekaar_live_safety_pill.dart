import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

/// MekaarLiveSafetyPill — Kapsul status keselamatan interaktif.
///
/// Menampilkan indikator status perlindungan (E2EE, Guardian Siaga, GPS)
/// dengan animasi pernapasan (breathing) yang menenangkan tanpa alarmisme.
class MekaarLiveSafetyPill extends StatefulWidget {
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

  @override
  State<MekaarLiveSafetyPill> createState() => _MekaarLiveSafetyPillState();
}

class _MekaarLiveSafetyPillState extends State<MekaarLiveSafetyPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _buildDisplayText() {
    if (widget.label != null && widget.label!.isNotEmpty) {
      return widget.label!;
    }
    final parts = <String>[];
    if (widget.activeGuardiansCount != null && widget.activeGuardiansCount! > 0) {
      parts.add('${widget.activeGuardiansCount} Guardian Siaga');
    }
    if (widget.isE2eeActive) {
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
    final isAnimationsDisabled = MediaQuery.disableAnimationsOf(context);

    final bgColor = isDark
        ? MekaarColors.guardianTeal.withValues(alpha: 0.12)
        : MekaarColors.guardianTeal.withValues(alpha: 0.08);

    final borderColor = isDark
        ? MekaarColors.guardianTeal.withValues(alpha: 0.25)
        : MekaarColors.guardianTeal.withValues(alpha: 0.20);

    return Semantics(
      button: widget.onTap != null,
      label: 'Status keselamatan: ${_buildDisplayText()}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: widget.onTap != null
              ? () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  widget.onTap!();
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
                isAnimationsDisabled
                    ? const Icon(
                        SolarIconsBold.shieldCheck,
                        size: 14,
                        color: MekaarColors.guardianTeal,
                      )
                    : ScaleTransition(
                        scale: _pulseScale,
                        child: const Icon(
                          SolarIconsBold.shieldCheck,
                          size: 14,
                          color: MekaarColors.guardianTeal,
                        ),
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
