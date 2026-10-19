import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../providers/update_download_provider.dart';
import '../services/haptic_service.dart';
import 'mekaar_update_bottom_sheet.dart';

/// FloatingUpdatePill bergaya MEKAAR yang muncul ketika unduhan pembaruan
/// diminimalkan atau berstatus siap pasang di latar belakang.
class MekaarFloatingUpdatePill extends ConsumerWidget {
  const MekaarFloatingUpdatePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(updateDownloadProvider);

    if (!downloadState.hasActiveTask &&
        downloadState.status != UpdateDownloadStatus.error) {
      return const SizedBox.shrink();
    }

    final isCompleted = downloadState.isCompleted;
    final isPaused = downloadState.isPaused;
    final isError = downloadState.status == UpdateDownloadStatus.error;
    final pct = (downloadState.progress * 100).toInt();

    final Color accentColor = isCompleted
        ? MekaarColors.successTextOf(context)
        : (isError
            ? MekaarColors.sosCoral
            : (isPaused
                ? MekaarColors.warning
                : MekaarColors.accentOf(context)));

    final String labelText = isCompleted
        ? 'Siap Pasang 🚀'
        : (isError
            ? 'Unduhan Gagal'
            : (isPaused ? 'Unduhan Dijeda' : 'Update $pct%'));

    final IconData statusIcon = isCompleted
        ? SolarIconsOutline.checkCircle
        : (isError
            ? SolarIconsOutline.dangerCircle
            : (isPaused
                ? SolarIconsOutline.pause
                : SolarIconsOutline.cloudDownload));

    final isDark = MekaarColors.isDarkContext(context);
    final borderColor =
        isDark ? MekaarColors.borderDark : MekaarColors.borderLight;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badan Pill (membuka lembar progres / instalasi)
            InkWell(
              onTap: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                if (isCompleted && downloadState.info != null) {
                  MekaarUpdateBottomSheet.showInstallSheet(
                    context: context,
                    info: downloadState.info!,
                  );
                } else if (downloadState.info != null) {
                  ref.read(updateDownloadProvider.notifier).maximize();
                  MekaarUpdateBottomSheet.showProgressSheet(
                    context: context,
                    info: downloadState.info!,
                  );
                }
              },
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  top: 8,
                  bottom: 8,
                  right: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge Ikon Status
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.14),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          statusIcon,
                          size: 16,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Kolom Info
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labelText,
                          style: MekaarTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: MekaarColors.textPrimaryOf(context),
                            fontSize: 12.5,
                          ),
                        ),
                        if (!isCompleted && !isError && !isPaused) ...[
                          const SizedBox(height: 3),
                          Container(
                            width: 96,
                            height: 5,
                            decoration: BoxDecoration(
                              color: MekaarColors.surface2Of(context),
                              borderRadius:
                                  BorderRadius.circular(MekaarRadius.pill),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(MekaarRadius.pill),
                              child: LinearProgressIndicator(
                                value: downloadState.progress > 0
                                    ? downloadState.progress
                                    : null,
                                backgroundColor: Colors.transparent,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            isCompleted
                                ? 'Ketuk untuk pasang'
                                : (isError
                                    ? 'Ketuk untuk unduh ulang'
                                    : (isPaused
                                        ? 'Ketuk untuk lanjut'
                                        : 'Ketuk untuk coba lagi')),
                            style: MekaarTypography.caption.copyWith(
                              fontSize: 10.5,
                              color: MekaarColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      SolarIconsOutline.altArrowRight,
                      size: 15,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ],
                ),
              ),
            ),

            // Pembatas Vertikal Halus
            Container(
              width: 1,
              height: 22,
              color: borderColor.withValues(alpha: 0.6),
            ),

            // Tombol Tutup (Dismiss) — Langsung Menghilangkan Pill
            Tooltip(
              message: 'Tutup pembaruan',
              child: InkWell(
                onTap: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  ref.read(updateDownloadProvider.notifier).dismiss();
                },
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(24),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Icon(
                    SolarIconsOutline.closeCircle,
                    size: 16,
                    color: MekaarColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
