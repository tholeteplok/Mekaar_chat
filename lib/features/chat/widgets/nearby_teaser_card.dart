import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import 'nearby_consent_dialog.dart';
import 'nearby_orbital_canvas.dart';

/// Kartu Teaser/Preview saat fitur Teman Sekitar belum diaktifkan.
/// Menampilkan kanvas orbit interaktif 3 avatar siluet + copy edukasi privasi + tombol CTA.
class NearbyTeaserCard extends StatelessWidget {
  final double collapseProgress;
  final double canvasHeight;
  final Future<void> Function() onActivate;

  const NearbyTeaserCard({
    super.key,
    required this.collapseProgress,
    required this.canvasHeight,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final progress = collapseProgress.clamp(0.0, 1.0);

    // 3 Mock Items untuk Preview Mode
    final previewItems = [
      OrbitalAvatarItem(
        id: 'preview-1',
        displayName: 'Dei',
        distanceBadge: '< 500 m',
        onTap: () => _handleActivation(context),
      ),
      OrbitalAvatarItem(
        id: 'preview-2',
        displayName: 'Raka',
        distanceBadge: '1.2 km',
        onTap: () => _handleActivation(context),
      ),
      OrbitalAvatarItem(
        id: 'preview-3',
        displayName: 'Maya',
        distanceBadge: 'Di dekatmu',
        onTap: () => _handleActivation(context),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1. Orbital Physics Canvas ──
        NearbyOrbitalCanvas(
          items: previewItems,
          collapseProgress: progress,
          height: canvasHeight,
          isPreview: true,
        ),

        // ── 2. Compact CTA & Reassurance Bar (Hanya tampil penuh saat expanded, fade saat collapse) ──
        AnimatedOpacity(
          opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0),
          duration: const Duration(milliseconds: 150),
          child: progress > 0.75
              ? const SizedBox.shrink()
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              MekaarColors.guardianTeal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(MekaarRadius.sm),
                        ),
                        child: const Icon(
                          SolarIconsBold.radar2,
                          color: MekaarColors.guardianTeal,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Teman Sekitar',
                              style: MekaarTypography.bodyMD.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Privasi aman: hanya radius kasar, bukan koordinat GPS',
                              style: MekaarTypography.caption.copyWith(
                                color: MekaarColors.textMutedOf(context),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handleActivation(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.guardianTeal,
                          foregroundColor: MekaarColors.textOnTeal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: const Size(40, 38),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(MekaarRadius.pill),
                          ),
                        ),
                        child: const Text(
                          'Aktifkan',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _handleActivation(BuildContext context) async {
    final accept = await NearbyConsentDialog.show(context);
    if (accept) {
      await onActivate();
    }
  }
}
