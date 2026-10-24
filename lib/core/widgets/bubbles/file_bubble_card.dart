import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/file_export_service.dart';
import '../../constants/colors.dart';
import '../../services/haptic_service.dart';
import '../mekaar_snackbar.dart';
import 'bubble_media_helper.dart';

/// Kartu tampilan gelembung berkas/dokumen terenkripsi pada pesan chat.
class FileBubbleCard extends StatefulWidget {
  final Message message;
  final bool isMe;
  final Color textColor;
  final String? fontFamily;
  final VoidCallback? onSaveToVault;

  const FileBubbleCard({
    super.key,
    required this.message,
    required this.isMe,
    required this.textColor,
    this.fontFamily,
    this.onSaveToVault,
  });

  @override
  State<FileBubbleCard> createState() => _FileBubbleCardState();
}

class _FileBubbleCardState extends State<FileBubbleCard> {
  bool _isDownloading = false;
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    _checkLocalCache();
  }

  Future<void> _checkLocalCache() async {
    final meta = widget.message.fileMeta;
    final fileName = meta?.fileName ?? 'dokumen';
    final tempDir = await getTemporaryDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file =
        File('${tempDir.path}/mekaar_file_${widget.message.id}_$safeFileName');
    if (await file.exists() && await file.length() > 0) {
      if (mounted) setState(() => _cachedFile = file);
    }
  }

  Future<void> _handleTap() async {
    if (_isDownloading) return;

    if (_cachedFile != null) {
      final meta = widget.message.fileMeta;
      final opened = await FileExportService.openFileWithChooser(
        file: _cachedFile!,
        mimeType: meta?.mimeType,
      );
      if (!opened && mounted) {
        MekaarSnackbar.info(
            context, 'Tidak ada aplikasi yang dapat membuka berkas ini.');
      }
      return;
    }

    final isExpired = _cachedFile == null &&
        DateTime.now().difference(widget.message.createdAt).inDays >= 30;
    if (isExpired) {
      MekaarSnackbar.warning(
        context,
        'Berkas di server telah kedaluwarsa (> 30 hari) sesuai batas retensi Supabase.',
      );
      return;
    }

    setState(() => _isDownloading = true);
    HapticService.trigger(MekaarHapticIntent.selection);

    final file = await FileExportService.resolveOrDownloadFile(widget.message);
    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _cachedFile = file;
    });

    if (file != null) {
      final meta = widget.message.fileMeta;
      await FileExportService.openFileWithChooser(
        file: file,
        mimeType: meta?.mimeType,
      );
    } else {
      if (DateTime.now().difference(widget.message.createdAt).inDays >= 30) {
        MekaarSnackbar.warning(
          context,
          'Berkas tidak ditemukan atau telah kedaluwarsa di server (> 30 hari).',
        );
      } else {
        MekaarSnackbar.error(context, 'Gagal mengunduh berkas.');
      }
    }
  }

  ({IconData icon, Color color}) _resolveFileTypeStyle(String ext) {
    final cleanExt = ext.toLowerCase();
    if (cleanExt == 'pdf') {
      return (icon: SolarIconsBold.fileText, color: MekaarColors.sosRed);
    }
    if (['doc', 'docx', 'txt', 'rtf', 'odt'].contains(cleanExt)) {
      return (icon: SolarIconsBold.documentText, color: MekaarColors.blue);
    }
    if (['xls', 'xlsx', 'csv', 'ods'].contains(cleanExt)) {
      return (
        icon: SolarIconsBold.documentAdd,
        color: MekaarColors.guardianTeal
      );
    }
    if (['ppt', 'pptx', 'odp'].contains(cleanExt)) {
      return (
        icon: SolarIconsBold.presentationGraph,
        color: Colors.deepOrange
      );
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(cleanExt)) {
      return (icon: SolarIconsBold.archive, color: Colors.amber.shade800);
    }
    return (icon: SolarIconsBold.file, color: MekaarColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.message.fileMeta ??
        FileAttachmentMeta(
          fileName: 'Berkas Dokumen',
          fileSize: 0,
        );

    final isExpired = _cachedFile == null &&
        DateTime.now().difference(widget.message.createdAt).inDays >= 30;

    final style = _resolveFileTypeStyle(meta.fileExtension);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = widget.isMe
        ? Colors.black.withValues(alpha: 0.1)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.textColor.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    style.icon,
                    color: style.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        meta.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: resolveBubbleTextStyle(
                          color: widget.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: style.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              meta.fileExtension,
                              style: resolveBubbleTextStyle(
                                color: isExpired
                                    ? Colors.amber.shade800
                                    : style.color,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: widget.fontFamily,
                              ),
                            ),
                          ),
                          if (isExpired) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Kedaluwarsa di server',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: resolveBubbleTextStyle(
                                  color: Colors.amber.shade800,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: widget.fontFamily,
                                ),
                              ),
                            ),
                          ] else if (meta.formattedFileSize.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              meta.formattedFileSize,
                              style: resolveBubbleTextStyle(
                                color: widget.textColor.withValues(alpha: 0.7),
                                fontSize: 11.5,
                                fontFamily: widget.fontFamily,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.textColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: _isDownloading
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(widget.textColor),
                          ),
                        )
                      : Icon(
                          _cachedFile != null
                              ? SolarIconsOutline.eye
                              : (isExpired
                                  ? SolarIconsOutline.clockCircle
                                  : SolarIconsOutline.download),
                          color: isExpired && _cachedFile == null
                              ? Colors.amber.shade800
                              : widget.textColor,
                          size: 18,
                        ),
                ),
              ],
            ),
          ),
        ),
        if (meta.caption != null && meta.caption!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              meta.caption!,
              style: resolveBubbleTextStyle(
                color: widget.textColor,
                fontSize: 14,
                height: 1.35,
                fontFamily: widget.fontFamily,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
