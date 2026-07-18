import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';

class ScreenProtectionStatusBadge extends StatelessWidget {
  final String label;

  const ScreenProtectionStatusBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        color: MekaarColors.safeTeal.withValues(alpha: 0.12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              SolarIconsOutline.shieldCheck,
              size: 17,
              color: MekaarColors.safeTeal,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenCaptureProtectionOverlay extends StatelessWidget {
  final bool visible;
  final VoidCallback? onAcknowledged;

  const ScreenCaptureProtectionOverlay({
    super.key,
    required this.visible,
    this.onAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Konten disembunyikan karena perekaman layar terdeteksi',
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: ColoredBox(
              color: MekaarColors.canvasTop.withValues(alpha: 0.9),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: MekaarColors.cardDark.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: MekaarColors.safeTeal.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              SolarIconsOutline.screenShare,
                              size: 52,
                              color: MekaarColors.safeTeal,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Konten disembunyikan',
                              textAlign: TextAlign.center,
                              style: MekaarTypography.headingMD.copyWith(
                                color: MekaarColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Perekaman layar terdeteksi. Konten akan tampil kembali setelah perekaman dihentikan.',
                              textAlign: TextAlign.center,
                              style: MekaarTypography.bodyMD.copyWith(
                                color: MekaarColors.textSecondary,
                              ),
                            ),
                            if (onAcknowledged != null) ...[
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: onAcknowledged,
                                child: const Text('Mengerti'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
