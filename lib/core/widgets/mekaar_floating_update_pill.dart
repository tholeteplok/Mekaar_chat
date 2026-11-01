import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/shadows.dart';
import '../constants/typography.dart';
import '../providers/update_download_provider.dart';
import '../services/haptic_service.dart';
import 'mekaar_update_bottom_sheet.dart';

/// MekaarFloatingUpdatePill — Tombol melayang berbentuk lingkaran kompak
/// yang muncul ketika unduhan pembaruan diminimalkan atau siap dipasang.
///
/// Karakteristik:
/// - Bentuk lingkaran 50x50 agar ergonomis dan tidak menutup bilah navigasi bawah
/// - Menampilkan CircularProgressIndicator dengan teks persentase tengah (misal "45%") saat mengunduh (<100%)
/// - Menampilkan ikon roket [SolarIconsBold.rocket2] berwarna hijau sukses saat unduhan 100% (siap dipasang)
/// - Men-tap lingkaran langsung memicu Bottom Sheet instalasi (jika 100%) atau lembar progres (jika aktif)
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
    final pct = (downloadState.progress * 100).toInt().clamp(0, 100);

    final Color accentColor = isCompleted
        ? MekaarColors.successTextOf(context)
        : (isError
              ? MekaarColors.sosCoral
              : (isPaused
                    ? MekaarColors.warning
                    : MekaarColors.accentOf(context)));

    final isDark = MekaarColors.isDarkContext(context);
    final borderColor = isCompleted
        ? MekaarColors.successTextOf(context).withValues(alpha: 0.5)
        : (isError
              ? MekaarColors.sosCoral.withValues(alpha: 0.5)
              : (isPaused
                    ? MekaarColors.warning.withValues(alpha: 0.5)
                    : (isDark
                          ? MekaarColors.borderDark
                          : MekaarColors.borderLight)));

    final String tooltipMessage = isCompleted
        ? 'Pembaruan siap dipasang. Ketuk untuk pasang'
        : (isError
              ? 'Unduhan gagal. Ketuk untuk coba lagi'
              : (isPaused
                    ? 'Unduhan dijeda ($pct%). Ketuk untuk buka'
                    : 'Mengunduh pembaruan ($pct%). Ketuk untuk lihat'));

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltipMessage,
        child: InkWell(
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
          customBorder: const CircleBorder(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MekaarColors.surfaceOf(context),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: MekaarShadows.floating,
            ),
            child: Center(
              child: _buildContent(
                context: context,
                isCompleted: isCompleted,
                isPaused: isPaused,
                isError: isError,
                progress: downloadState.progress,
                pct: pct,
                accentColor: accentColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required bool isCompleted,
    required bool isPaused,
    required bool isError,
    required double progress,
    required int pct,
    required Color accentColor,
  }) {
    if (isCompleted) {
      return Icon(
        SolarIconsBold.rocket2,
        color: MekaarColors.successTextOf(context),
        size: 22,
      );
    }

    if (isError) {
      return const Icon(
        SolarIconsBold.dangerCircle,
        color: MekaarColors.sosCoral,
        size: 22,
      );
    }

    if (isPaused) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : 0,
              strokeWidth: 3.2,
              backgroundColor: MekaarColors.warning.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                MekaarColors.warning,
              ),
            ),
          ),
          const Icon(
            SolarIconsBold.pause,
            color: MekaarColors.warning,
            size: 18,
          ),
        ],
      );
    }

    // Mengunduh normal (< 100%)
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 3.2,
            backgroundColor: accentColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        Text(
          '$pct%',
          style: MekaarTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: MekaarColors.textPrimaryOf(context),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
