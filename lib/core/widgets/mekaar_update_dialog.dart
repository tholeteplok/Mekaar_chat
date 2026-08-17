import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/update_service.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'mekaar_snackbar.dart';

/// Helper terpusat untuk menampilkan dialog pengunduhan dan instalasi update
Future<void> showInAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  void Function(String url)? onOpenUrl,
}) async {
  HapticService.trigger(MekaarHapticIntent.selection);

  void defaultOpenUrl(String urlString) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final target = urlString.trim().isNotEmpty
        ? urlString.trim()
        : 'https://github.com/tholeteplok/Mekaar_chat/releases';
    try {
      final uri = Uri.parse(target);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallbackLaunched =
            await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      }
    } catch (_) {
      try {
        final uri = Uri.parse(target);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          MekaarSnackbar.error(context, 'Tidak dapat membuka tautan.');
        }
      }
    }
  }

  // Fallback jika non-Android atau link download kosong
  if (!Platform.isAndroid || info.downloadUrl.isEmpty) {
    final handler = onOpenUrl ?? defaultOpenUrl;
    handler(info.downloadUrl.isNotEmpty ? info.downloadUrl : info.htmlUrl);
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => InAppUpdateDialog(
      info: info,
      onOpenUrl: onOpenUrl ?? defaultOpenUrl,
    ),
  );
}

/// Dialog proses unduhan APK dengan kalkulasi byte yang stabil dan throttled rendering
class InAppUpdateDialog extends ConsumerStatefulWidget {
  final AppUpdateInfo info;
  final ValueChanged<String> onOpenUrl;

  const InAppUpdateDialog({
    super.key,
    required this.info,
    required this.onOpenUrl,
  });

  @override
  ConsumerState<InAppUpdateDialog> createState() => _InAppUpdateDialogState();
}

class _InAppUpdateDialogState extends ConsumerState<InAppUpdateDialog> {
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  late int _totalBytes;
  String _statusMessage = 'Menghubungi server rilis...';
  bool _isCompleted = false;
  String? _downloadError;
  int _lastUiUpdateTime = 0;

  @override
  void initState() {
    super.initState();
    _totalBytes = widget.info.downloadSizeBytes;
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final updateService = ref.read(updateServiceProvider);
      if (mounted) {
        setState(() {
          _statusMessage = 'Mengunduh paket instalasi...';
        });
      }

      final file = await updateService.downloadApk(
        downloadUrl: widget.info.downloadUrl,
        version: widget.info.latestVersion,
        expectedTotalBytes: widget.info.downloadSizeBytes,
        onProgress: (progress, received, total) {
          if (!mounted) return;

          final now = DateTime.now().millisecondsSinceEpoch;
          // Jaminan progress selalu bergerak maju (monotonik)
          _receivedBytes = math.max(_receivedBytes, received);
          if (total > 0) {
            _totalBytes = total;
          }
          if (progress > 0) {
            _downloadProgress = math.max(_downloadProgress, progress);
          }

          // Throttle pembaruan UI ke interval ~60ms atau saat selesai 100%
          final shouldUpdateUi =
              (now - _lastUiUpdateTime > 60) || progress >= 1.0;
          if (shouldUpdateUi) {
            _lastUiUpdateTime = now;
            setState(() {
              if (_downloadProgress >= 1.0) {
                _statusMessage = 'Memverifikasi paket...';
              } else if (_downloadProgress > 0) {
                _statusMessage =
                    'Mengunduh ${(_downloadProgress * 100).toInt()}%...';
              }
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isCompleted = true;
        _downloadProgress = 1.0;
        _statusMessage = 'Membuka Penginstal Paket Android...';
      });

      final installed = await updateService.installApk(file.path);
      if (!installed && mounted) {
        setState(() {
          _downloadError =
              'Tidak dapat membuka penginstal secara otomatis. Silakan pasang dari folder unduhan atau buka melalui browser.';
        });
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadError = 'Gagal mengunduh berkas: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receivedMb = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = _totalBytes > 0
        ? (_totalBytes / (1024 * 1024)).toStringAsFixed(1)
        : (widget.info.downloadSizeBytes > 0
            ? (widget.info.downloadSizeBytes / (1024 * 1024)).toStringAsFixed(1)
            : '?');

    return Dialog(
      backgroundColor: MekaarColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: MekaarColors.border.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        MekaarColors.accentOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    SolarIconsBold.cloudDownload,
                    color: MekaarColors.accentOf(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pembaruan MEKAAR',
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
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_downloadError != null) ...[
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
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _downloadError!,
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.sosRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MekaarColors.accentOf(context),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenUrl(widget.info.htmlUrl);
                      },
                      icon: const Icon(
                        SolarIconsOutline.global,
                        size: 16,
                      ),
                      label: const Text('Buka Browser'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  backgroundColor: MekaarColors.surface2Of(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    MekaarColors.accentOf(context),
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _statusMessage,
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$receivedMb / $totalMb MB',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.accentOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isCompleted ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
