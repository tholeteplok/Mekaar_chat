import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/update_service.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../providers/update_download_provider.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';
import 'mekaar_snackbar.dart';

/// MekaarUpdateBottomSheet — Rangkaian Bottom Sheet terpusat untuk alur in-app update MEKAAR:
/// 1. Notifikasi rilis pembaruan baru
/// 2. Progres pengunduhan live dengan jeda/resume & opsi minimalkan
/// 3. Prompt instalasi paket APK atau fallback ke folder unduhan
class MekaarUpdateBottomSheet {
  MekaarUpdateBottomSheet._();

  /// 1. Menampilkan Bottom Sheet notifikasi ketersediaan versi baru
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
      builder: (sheetContext) => _UpdateNotificationSheet(
        info: info,
        onUpdate: () {
          Navigator.pop(sheetContext);
          if (onUpdate != null) {
            onUpdate();
          } else {
            showProgressSheet(context: context, info: info);
          }
        },
        onLater: () {
          Navigator.pop(sheetContext);
          onLater?.call();
        },
      ),
    );
  }

  /// 2. Menampilkan Bottom Sheet pemantauan progres unduhan APK
  static Future<void> showProgressSheet({
    required BuildContext context,
    required AppUpdateInfo info,
  }) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _UpdateProgressSheet(info: info),
    );
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
      builder: (sheetContext) => _UpdateInstallPromptSheet(info: info),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet 1: Notifikasi Rilis Pembaruan
// ─────────────────────────────────────────────────────────────
class _UpdateNotificationSheet extends ConsumerWidget {
  final AppUpdateInfo info;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  const _UpdateNotificationSheet({
    required this.info,
    required this.onUpdate,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = MekaarColors.isDarkContext(context);
    final accentColor = MekaarColors.accentOf(context);
    final downloadState = ref.watch(updateDownloadProvider);
    final isAlreadyDownloaded = downloadState.isCompleted &&
        downloadState.info?.latestVersion == info.latestVersion;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Ikon & Judul
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                SolarIconsBold.rocket2,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembaruan Tersedia 🚀',
                    style: MekaarTypography.headingSM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Versi ${info.latestVersion}',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Badges Ukuran & Arsitektur
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (info.formattedSize.isNotEmpty)
              _buildBadge(
                context,
                icon: SolarIconsOutline.cloudDownload,
                label: info.formattedSize,
                accentColor: accentColor,
              ),
            if (info.matchedAbi.isNotEmpty)
              _buildBadge(
                context,
                icon: SolarIconsOutline.cpu,
                label: info.matchedAbi == 'universal'
                    ? 'Universal APK'
                    : info.matchedAbi,
                accentColor: accentColor,
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Catatan Rilis Terstruktur
        Text(
          'Catatan Rilis:',
          style: MekaarTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: MekaarColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        _buildReleaseNotesContainer(context, isDark: isDark),
        const SizedBox(height: 20),

        // Tombol Aksi
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
                onPressed: onLater,
                child: Text(
                  'Nanti',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAlreadyDownloaded
                      ? MekaarColors.successTextOf(context)
                      : accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
                onPressed: () {
                  if (isAlreadyDownloaded) {
                    Navigator.pop(context);
                    MekaarUpdateBottomSheet.showInstallSheet(
                      context: context,
                      info: info,
                    );
                  } else {
                    onUpdate();
                  }
                },
                icon: Icon(
                  isAlreadyDownloaded
                      ? SolarIconsBold.checkCircle
                      : SolarIconsBold.download,
                  size: 18,
                  color: isAlreadyDownloaded ? Colors.white : Colors.black,
                ),
                label: Text(
                  isAlreadyDownloaded ? 'Pasang Sekarang' : 'Perbarui',
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAlreadyDownloaded ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReleaseNotesContainer(BuildContext context,
      {required bool isDark}) {
    final updateService = UpdateService();
    final items = updateService.parseReleaseNotes(info.releaseNotes);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 140),
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

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: MekaarTypography.caption.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet 2: Progres Pengunduhan dengan Jeda/Lanjut & Minimalkan
// ─────────────────────────────────────────────────────────────
class _UpdateProgressSheet extends ConsumerStatefulWidget {
  final AppUpdateInfo info;

  const _UpdateProgressSheet({required this.info});

  @override
  ConsumerState<_UpdateProgressSheet> createState() =>
      _UpdateProgressSheetState();
}

class _UpdateProgressSheetState extends ConsumerState<_UpdateProgressSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final downloadState = ref.read(updateDownloadProvider);
      ref.read(updateDownloadProvider.notifier).maximize();
      if (!downloadState.isDownloading && !downloadState.isCompleted) {
        ref.read(updateDownloadProvider.notifier).startDownload(widget.info);
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

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(updateDownloadProvider);
    final isDownloading = downloadState.isDownloading;
    final isPaused = downloadState.isPaused;
    final isCompleted = downloadState.isCompleted;
    final errorMessage = downloadState.errorMessage;
    final statusMessage = downloadState.statusMessage.isNotEmpty
        ? downloadState.statusMessage
        : 'Menghubungi server rilis...';

    final receivedMb =
        (downloadState.receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final effectiveTotal = downloadState.totalBytes > 0
        ? downloadState.totalBytes
        : widget.info.downloadSizeBytes;
    final totalMb = effectiveTotal > 0
        ? (effectiveTotal / (1024 * 1024)).toStringAsFixed(1)
        : '?';

    final accentColor = isCompleted
        ? MekaarColors.successTextOf(context)
        : (errorMessage != null
            ? MekaarColors.sosCoral
            : (isPaused
                ? MekaarColors.warning
                : MekaarColors.accentOf(context)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header dengan tombol Minimalkan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  ),
                  child: Icon(
                    isCompleted
                        ? SolarIconsBold.checkCircle
                        : (errorMessage != null
                            ? SolarIconsBold.dangerCircle
                            : (isPaused
                                ? SolarIconsBold.pause
                                : SolarIconsBold.cloudDownload)),
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Unduhan Selesai' : 'Mengunduh MEKAAR',
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      'Versi ${widget.info.latestVersion}',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              tooltip: 'Minimalkan',
              icon: Icon(
                SolarIconsOutline.closeSquare,
                size: 22,
                color: MekaarColors.textSecondaryOf(context),
              ),
              onPressed: () {
                ref.read(updateDownloadProvider.notifier).minimize();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: downloadState.progress > 0 ? downloadState.progress : null,
            backgroundColor: MekaarColors.surface2Of(context),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),

        // Keterangan Status & Byte Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                statusMessage,
                style: MekaarTypography.caption.copyWith(
                  color: errorMessage != null
                      ? MekaarColors.sosCoral
                      : (isPaused
                          ? MekaarColors.warning
                          : MekaarColors.textSecondaryOf(context)),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$receivedMb / $totalMb MB',
              style: MekaarTypography.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // Error Banner jika ada
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MekaarColors.sosRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  SolarIconsBold.dangerCircle,
                  color: MekaarColors.sosRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.sosRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Tombol Aksi Kontrol (Jeda / Lanjutkan / Minimalkan / Pasang / Buka Folder)
        if (isCompleted) ...[
          const _ReadyToInstallActions(),
        ] else if (errorMessage != null) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.accentOf(context),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(46),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: () => ref
                .read(updateDownloadProvider.notifier)
                .deleteAndRetryDownload(widget.info),
            icon: const Icon(SolarIconsOutline.restart, size: 18),
            label: const Text(
              'Unduh Ulang dari Awal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openFallbackBrowser,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  icon: const Icon(SolarIconsOutline.global, size: 16),
                  label: const Text('Buka Browser'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pop(context);
                    await ref
                        .read(updateDownloadProvider.notifier)
                        .deleteCacheAndReset();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: MekaarColors.sosCoral,
                    side: BorderSide(
                      color: MekaarColors.sosCoral.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  icon: const Icon(SolarIconsOutline.trashBinTrash, size: 16),
                  label: const Text('Hapus & Tutup'),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              // Tombol Jeda / Lanjutkan
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    if (isDownloading) {
                      ref
                          .read(updateDownloadProvider.notifier)
                          .pauseDownload();
                    } else if (isPaused) {
                      ref
                          .read(updateDownloadProvider.notifier)
                          .startDownload(widget.info);
                    }
                  },
                  icon: Icon(
                    isPaused
                        ? SolarIconsBold.play
                        : SolarIconsBold.pause,
                    size: 16,
                  ),
                  label: Text(isPaused ? 'Lanjutkan' : 'Jeda'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tombol Minimalkan
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.accentOf(context),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  onPressed: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    ref.read(updateDownloadProvider.notifier).minimize();
                    Navigator.pop(context);
                  },
                  icon: const Icon(SolarIconsOutline.minimize, size: 16),
                  label: const Text(
                    'Minimalkan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                HapticService.trigger(MekaarHapticIntent.selection);
                Navigator.pop(context);
                await ref
                    .read(updateDownloadProvider.notifier)
                    .deleteCacheAndReset();
              },
              icon: const Icon(
                SolarIconsOutline.trashBinTrash,
                size: 14,
                color: MekaarColors.sosCoral,
              ),
              label: Text(
                'Batalkan & Hapus Unduhan',
                style: MekaarTypography.caption.copyWith(
                  color: MekaarColors.sosCoral,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet 3: Prompt Instalasi Paket APK & Cadangan Folder Unduhan
// ─────────────────────────────────────────────────────────────
class _UpdateInstallPromptSheet extends ConsumerWidget {
  final AppUpdateInfo info;

  const _UpdateInstallPromptSheet({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(updateDownloadProvider);
    final hasExported = downloadState.publicExportPath != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MekaarColors.successTextOf(context).withValues(alpha: 0.16),
            border: Border.all(
              color:
                  MekaarColors.successTextOf(context).withValues(alpha: 0.40),
              width: 2,
            ),
          ),
          child: Center(
            child: Icon(
              SolarIconsBold.rocket2,
              color: MekaarColors.successTextOf(context),
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pembaruan Siap Dipasang!',
          style: MekaarTypography.headingSM.copyWith(
            fontWeight: FontWeight.bold,
            color: MekaarColors.textPrimaryOf(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Versi ${info.latestVersion} telah berhasil diunduh dan siap diperbarui ke perangkat Anda.',
          style: MekaarTypography.bodySM.copyWith(
            color: MekaarColors.textSecondaryOf(context),
          ),
          textAlign: TextAlign.center,
        ),
        if (hasExported) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  SolarIconsOutline.folder,
                  size: 16,
                  color: MekaarColors.blue,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Salinan tersimpan di folder Download: ${downloadState.publicExportPath}',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _ReadyToInstallActions(),
      ],
    );
  }
}

/// Tombol aksi siap pasang tersentralisasi (2 baris: Pasang Sekarang, Buka Unduhan & Hapus Berkas)
class _ReadyToInstallActions extends ConsumerWidget {
  const _ReadyToInstallActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Baris 1: Tombol Pasang Sekarang
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.successTextOf(context),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MekaarRadius.md),
            ),
          ),
          onPressed: () async {
            HapticService.trigger(MekaarHapticIntent.success);
            final result = await ref
                .read(updateDownloadProvider.notifier)
                .triggerInstall();

            if (!context.mounted) return;

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
          },
          icon: const Icon(SolarIconsBold.shieldCheck, size: 18),
          label: const Text(
            'Pasang Sekarang',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),

        // Baris 2: Buka Unduhan & Hapus Berkas (Outlined Berjejer)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
                onPressed: () async {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  await ref
                      .read(updateDownloadProvider.notifier)
                      .openDownloadsFolder();
                },
                icon: const Icon(SolarIconsOutline.folderWithFiles, size: 16),
                label: const Text(
                  'Buka Unduhan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: MekaarColors.sosCoral,
                  side: BorderSide(
                    color: MekaarColors.sosCoral.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
                onPressed: () async {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  final rootNav = Navigator.of(context, rootNavigator: true);
                  final scaffoldCtx = rootNav.context;
                  Navigator.pop(context);
                  await ref
                      .read(updateDownloadProvider.notifier)
                      .deleteCacheAndReset();
                  if (scaffoldCtx.mounted) {
                    MekaarSnackbar.info(
                      scaffoldCtx,
                      'Berkas unduhan dan cache berhasil dihapus',
                    );
                  }
                },
                icon: const Icon(SolarIconsOutline.trashBinTrash, size: 16),
                label: const Text(
                  'Hapus Berkas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
