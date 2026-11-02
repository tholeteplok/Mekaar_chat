import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/update_service.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../navigation/app_navigator.dart';
import '../providers/update_download_provider.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';
import 'mekaar_snackbar.dart';

/// MekaarUpdateBottomSheet — Lembaran terpusat untuk seluruh siklus hidup in-app update MEKAAR:
/// 1. Notifikasi rilis pembaruan baru dengan emblem keamanan sentral (Opsi B) & pill versi terpadu
/// 2. Transisi in-place: menekan "Perbarui Sekarang" langsung menjalankan progresbar di sheet yang sama
/// 3. Catatan rilis tetap aktif (Opsi 1.A) selama pengunduhan
/// 4. Kontrol bertumpuk penuh (Stacked Full-Width, Opsi 2) dengan tipografi teks murni tanpa ikon/emoji
/// 5. Auto-minimize saat barrier/swipe down ditutup ke floating circular rocket button
class MekaarUpdateBottomSheet {
  MekaarUpdateBottomSheet._();

  /// 1. Menampilkan Bottom Sheet pembaruan versi baru (transisi in-place)
  static Future<void> show({
    required BuildContext context,
    required AppUpdateInfo info,
    VoidCallback? onUpdate,
    VoidCallback? onLater,
  }) async {
    HapticService.trigger(MekaarHapticIntent.success);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _UnifiedUpdateSheet(
        info: info,
        onUpdate: onUpdate,
        onLater: onLater,
      ),
    );

    if (context.mounted) {
      _checkAndAutoMinimize(context);
    } else {
      _checkAndAutoMinimize();
    }
  }

  /// 2. Menampilkan Bottom Sheet pemantauan progres unduhan APK (buka kembali / maksimalkan)
  static Future<void> showProgressSheet({
    required BuildContext context,
    required AppUpdateInfo info,
  }) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _UnifiedUpdateSheet(
        info: info,
        autoStartDownload: true,
      ),
    );

    if (context.mounted) {
      _checkAndAutoMinimize(context);
    } else {
      _checkAndAutoMinimize();
    }
  }

  /// 3. Menampilkan Bottom Sheet prompt pemasangan saat unduhan selesai
  static Future<void> showInstallSheet({
    required BuildContext context,
    required AppUpdateInfo info,
  }) async {
    HapticService.trigger(MekaarHapticIntent.success);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _UnifiedUpdateSheet(
        info: info,
        forceInstallMode: true,
      ),
    );

    if (context.mounted) {
      _checkAndAutoMinimize(context);
    } else {
      _checkAndAutoMinimize();
    }
  }

  /// Helper auto-minimize saat sheet ditutup (baik via tap luar/barrier maupun swipe down)
  static void _checkAndAutoMinimize([BuildContext? context]) {
    final targetContext = (context != null && context.mounted)
        ? context
        : AppNavigator.currentContext;
    if (targetContext != null && targetContext.mounted) {
      try {
        final container = ProviderScope.containerOf(
          targetContext,
          listen: false,
        );
        final downloadState = container.read(updateDownloadProvider);
        if (downloadState.hasActiveTask || downloadState.isCompleted) {
          container.read(updateDownloadProvider.notifier).minimize();
        }
      } catch (_) {}
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Unified In-Place Update Sheet
// ─────────────────────────────────────────────────────────────
class _UnifiedUpdateSheet extends ConsumerStatefulWidget {
  final AppUpdateInfo info;
  final VoidCallback? onUpdate;
  final VoidCallback? onLater;
  final bool autoStartDownload;
  final bool forceInstallMode;

  const _UnifiedUpdateSheet({
    required this.info,
    this.onUpdate,
    this.onLater,
    this.autoStartDownload = false,
    this.forceInstallMode = false,
  });

  @override
  ConsumerState<_UnifiedUpdateSheet> createState() =>
      _UnifiedUpdateSheetState();
}

class _UnifiedUpdateSheetState extends ConsumerState<_UnifiedUpdateSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateDownloadProvider.notifier).maximize();
      if (widget.autoStartDownload && !widget.forceInstallMode) {
        final downloadState = ref.read(updateDownloadProvider);
        if (!downloadState.isDownloading && !downloadState.isCompleted) {
          ref.read(updateDownloadProvider.notifier).startDownload(widget.info);
        }
      }
    });
  }

  Future<void> _openFallbackBrowser() async {
    final target = widget.info.downloadUrl.isNotEmpty
        ? widget.info.downloadUrl
        : widget.info.htmlUrl;
    try {
      final uri = Uri.parse(target);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Tidak dapat membuka browser.');
      }
    }
  }

  Future<void> _handleInstall() async {
    HapticService.trigger(MekaarHapticIntent.success);
    final result = await ref
        .read(updateDownloadProvider.notifier)
        .triggerInstall();

    if (!mounted) return;

    if (result == InstallResult.success) {
      Navigator.pop(context);
    } else if (result == InstallResult.permissionRequired) {
      MekaarSnackbar.info(
        context,
        'Silakan izinkan pemasangan aplikasi dari sumber ini pada pengaturan perangkat.',
      );
    } else if (result == InstallResult.corruptApk) {
      Navigator.pop(context);
      MekaarSnackbar.error(
        context,
        'Berkas unduhan rusak atau tidak kompatibel. Cache telah dibersihkan, silakan unduh ulang.',
      );
    } else {
      MekaarSnackbar.error(
        context,
        'Gagal membuka installer otomatis. Anda dapat membuka file dari folder Unduhan.',
      );
    }
  }

  Future<void> _handleOpenDownloads() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    await ref.read(updateDownloadProvider.notifier).openDownloadsFolder();
  }

  Future<void> _handleDeleteCache() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final rootNav = Navigator.of(context, rootNavigator: true);
    final scaffoldCtx = rootNav.context;
    await ref.read(updateDownloadProvider.notifier).deleteCacheAndReset();
    if (mounted) {
      Navigator.pop(context);
    }
    if (scaffoldCtx.mounted) {
      MekaarSnackbar.info(
        scaffoldCtx,
        'Berkas unduhan dan cache berhasil dihapus',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MekaarColors.isDarkContext(context);
    final accentColor = MekaarColors.accentOf(context);
    final downloadState = ref.watch(updateDownloadProvider);

    final isDownloading = downloadState.isDownloading ||
        (widget.autoStartDownload &&
            !downloadState.isCompleted &&
            !widget.forceInstallMode);
    final isPaused = downloadState.isPaused;
    final isCompleted = downloadState.isCompleted || widget.forceInstallMode;
    final hasError = downloadState.errorMessage != null && !widget.forceInstallMode;

    final receivedMb = (downloadState.receivedBytes / (1024 * 1024))
        .toStringAsFixed(1);
    final effectiveTotal = downloadState.totalBytes > 0
        ? downloadState.totalBytes
        : widget.info.downloadSizeBytes;
    final totalMb = effectiveTotal > 0
        ? (effectiveTotal / (1024 * 1024)).toStringAsFixed(1)
        : '?';
    final progressPercent =
        (downloadState.progress * 100).clamp(0, 100).toInt();

    final statusMessage = downloadState.statusMessage.isNotEmpty
        ? downloadState.statusMessage
        : (isDownloading
            ? 'Mengunduh pembaruan...'
            : (isPaused ? 'Dihentikan sementara' : ''));

    final Color statusColor = isCompleted
        ? MekaarColors.successTextOf(context)
        : (hasError
            ? MekaarColors.sosCoral
            : (isPaused ? MekaarColors.warning : accentColor));

    // Judul Header adaptif
    final String sheetTitle;
    if (isCompleted) {
      sheetTitle = 'Pembaruan Siap Dipasang!';
    } else if (isDownloading || isPaused) {
      sheetTitle = 'Mengunduh MEKAAR';
    } else if (hasError) {
      sheetTitle = 'Unduhan Terkendala';
    } else {
      sheetTitle = 'Pembaruan Tersedia';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Judul Header Terpusat
        Center(
          child: Text(
            sheetTitle,
            style: MekaarTypography.headingSM.copyWith(
              fontWeight: FontWeight.bold,
              color: MekaarColors.textPrimaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // 2. Hero Visual Emblem Sentral (Opsi B)
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? MekaarColors.successTextOf(context).withValues(alpha: 0.16)
                  : (hasError
                      ? MekaarColors.sosCoral.withValues(alpha: 0.15)
                      : accentColor.withValues(alpha: 0.14)),
              border: Border.all(
                color: isCompleted
                    ? MekaarColors.successTextOf(context).withValues(alpha: 0.35)
                    : (hasError
                        ? MekaarColors.sosCoral.withValues(alpha: 0.35)
                        : accentColor.withValues(alpha: 0.30)),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                isCompleted
                    ? SolarIconsBold.shieldCheck
                    : (hasError
                        ? SolarIconsBold.dangerCircle
                        : (isDownloading || isPaused
                            ? SolarIconsBold.shieldUp
                            : SolarIconsBold.rocket2)),
                color: isCompleted
                    ? MekaarColors.successTextOf(context)
                    : (hasError ? MekaarColors.sosCoral : accentColor),
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Pill Kapsul Versi Terpadu
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withValues(alpha: 0.22)),
            ),
            child: Text(
              'Versi ${widget.info.latestVersion}${widget.info.formattedSize.isNotEmpty ? ' • ${widget.info.formattedSize}' : ''}',
              style: MekaarTypography.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Catatan Rilis Terstruktur (Opsi 1.A: Tetap Tampil)
        Text(
          'Apa yang baru:',
          style: MekaarTypography.bodyMD.copyWith(
            fontWeight: FontWeight.bold,
            color: MekaarColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        _buildReleaseNotesContainer(context, isDark: isDark),

        // 5. Bagian Progres Live (Muncul Dinamis Saat Mengunduh / Dijeda / Selesai / Error)
        if (isDownloading || isPaused || isCompleted || hasError) ...[
          const SizedBox(height: 16),
          if (hasError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MekaarColors.sosRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
              child: Text(
                downloadState.errorMessage ?? 'Gagal mengunduh pembaruan',
                style: MekaarTypography.caption.copyWith(
                  color: MekaarColors.sosRed,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isCompleted
                    ? 1.0
                    : (downloadState.progress > 0
                        ? downloadState.progress
                        : null),
                backgroundColor: MekaarColors.surface2Of(context),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),

            // Baris Status & Byte
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isCompleted ? 'Pembaruan siap dipasang' : statusMessage,
                    style: MekaarTypography.caption.copyWith(
                      color: isPaused
                          ? MekaarColors.warning
                          : MekaarColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  isCompleted
                      ? '$totalMb MB (100%)'
                      : '$receivedMb / $totalMb MB ($progressPercent%)',
                  style: MekaarTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],

        // 6. Garis Pemisah Visual Tipis
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          height: 1,
          color: MekaarColors.borderOf(context).withValues(alpha: 0.25),
        ),

        // 7. Tombol Aksi Bertumpuk Penuh (Stacked Full-Width, Teks Murni Tanpa Ikon/Emoji)
        _buildActionButtons(context, accentColor: accentColor),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, {required Color accentColor}) {
    final downloadState = ref.watch(updateDownloadProvider);
    final isCompleted = downloadState.isCompleted || widget.forceInstallMode;
    final hasError = downloadState.errorMessage != null && !widget.forceInstallMode;
    final isDownloading = downloadState.isDownloading ||
        (widget.autoStartDownload && !isCompleted && !hasError);
    final isPaused = downloadState.isPaused && !widget.forceInstallMode;

    if (isCompleted) {
      // Status Selesai: Pasang Sekarang (Full-Width) + Buka Unduhan & Hapus Berkas di Bawahnya
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.successTextOf(context),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: _handleInstall,
            child: const Text(
              'Pasang Sekarang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  onPressed: _handleOpenDownloads,
                  child: const Text('Buka Unduhan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    foregroundColor: MekaarColors.sosCoral,
                    side: BorderSide(
                      color: MekaarColors.sosCoral.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  onPressed: _handleDeleteCache,
                  child: const Text('Hapus Berkas'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (hasError) {
      // Status Gagal: Unduh Ulang dari Awal (Full-Width) + Buka Lewat Browser
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: () => ref
                .read(updateDownloadProvider.notifier)
                .deleteAndRetryDownload(widget.info),
            child: const Text(
              'Unduh Ulang dari Awal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _openFallbackBrowser,
            child: Text(
              'Buka Lewat Browser',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (isDownloading) {
      // Status Sedang Mengunduh: Jeda Unduhan (Full-Width) + Minimalkan
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.surface2Of(context),
              foregroundColor: MekaarColors.textPrimaryOf(context),
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              side: BorderSide(
                color: MekaarColors.borderOf(context).withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              ref.read(updateDownloadProvider.notifier).pauseDownload();
            },
            child: const Text(
              'Jeda Unduhan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              ref.read(updateDownloadProvider.notifier).minimize();
              Navigator.pop(context);
            },
            child: Text(
              'Minimalkan',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (isPaused) {
      // Status Dijeda: Lanjutkan Unduhan (Full-Width) + Minimalkan
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              ref.read(updateDownloadProvider.notifier).startDownload(widget.info);
            },
            child: const Text(
              'Lanjutkan Unduhan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              ref.read(updateDownloadProvider.notifier).minimize();
              Navigator.pop(context);
            },
            child: Text(
              'Minimalkan',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    // Status Belum Mengunduh (Idle): Perbarui Sekarang (Full-Width) + Ingatkan Nanti
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MekaarRadius.md),
            ),
          ),
          onPressed: () {
            HapticService.trigger(MekaarHapticIntent.selection);
            if (widget.onUpdate != null) {
              widget.onUpdate!();
            } else {
              ref.read(updateDownloadProvider.notifier).startDownload(widget.info);
            }
          },
          child: const Text(
            'Perbarui Sekarang',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {
            widget.onLater?.call();
            Navigator.pop(context);
          },
          child: Text(
            'Ingatkan Nanti',
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textSecondaryOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseNotesContainer(
    BuildContext context, {
    required bool isDark,
  }) {
    final updateService = UpdateService();
    final items = updateService.parseReleaseNotes(widget.info.releaseNotes);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MekaarColors.surface2Of(context),
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(
          color: MekaarColors.border.withValues(alpha: isDark ? 0.1 : 0.06),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            final Color dotColor;
            switch (item.category) {
              case ReleaseCategory.fix:
                dotColor = MekaarColors.sosCoral;
              case ReleaseCategory.feat:
                dotColor = MekaarColors.successTextOf(context);
              case ReleaseCategory.perf:
                dotColor = MekaarColors.warning;
              case ReleaseCategory.ui:
                dotColor = MekaarColors.blue;
              case ReleaseCategory.general:
                dotColor = MekaarColors.textSecondaryOf(context);
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.text,
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
