import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:video_compress/video_compress.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/file_export_service.dart';
import '../../constants/colors.dart';
import '../../services/haptic_service.dart';
import '../mekaar_snackbar.dart';
import 'bubble_media_helper.dart';
import 'read_receipt_icon.dart';

/// Komponen bubble terpusat untuk pesan media video.
///
/// Mendukung:
/// 1. Tampilan thumbnail cerdas atau backdrop bergradien elegan.
/// 2. Tombol Play semi-transparan dengan loading spinner saat unduh/dekripsi.
/// 3. Peluncuran pemutar video bawaan/eksternal via [FileExportService.openFileWithChooser].
/// 4. Penanganan batas retensi Supabase (> 30 hari).
/// 5. Caption teks, timestamp, dan tanda terima baca (read receipt).
class VideoBubble extends StatefulWidget {
  final Message message;
  final Color textColor;
  final bool isMe;
  final BorderRadius borderRadius;
  final bool isSelected;
  final ReadReceiptStatus? receiptStatus;
  final String caption;
  final Widget? metaWidget;
  final String? fontFamily;
  final VoidCallback? onSaveToVault;
  final Future<void> Function()? onOpenVideo;

  const VideoBubble({
    super.key,
    required this.message,
    required this.textColor,
    this.isMe = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.isSelected = false,
    this.receiptStatus,
    this.caption = '',
    this.metaWidget,
    this.fontFamily,
    this.onSaveToVault,
    this.onOpenVideo,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  bool _isDownloading = false;
  File? _cachedFile;
  File? _thumbnailFile;

  @override
  void initState() {
    super.initState();
    _checkLocalCache();
  }

  Future<void> _checkLocalCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetMp4 = File(
        '${tempDir.path}/mekaar_video_${widget.message.id}.mp4',
      );
      if (await targetMp4.exists() && await targetMp4.length() > 0) {
        if (mounted) setState(() => _cachedFile = targetMp4);
        _generateThumbnail(targetMp4);
        return;
      }

      final inMemory = getDecryptedFromMemory(widget.message.id);
      if (inMemory != null && await inMemory.exists()) {
        if (inMemory.path.endsWith('.mp4')) {
          if (mounted) setState(() => _cachedFile = inMemory);
          _generateThumbnail(inMemory);
        } else {
          try {
            final mp4File = await inMemory.copy(targetMp4.path);
            if (mounted) setState(() => _cachedFile = mp4File);
            _generateThumbnail(mp4File);
          } catch (_) {
            if (mounted) setState(() => _cachedFile = inMemory);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _generateThumbnail(File video) async {
    try {
      final thumb = await VideoCompress.getFileThumbnail(
        video.path,
        quality: 50,
        position: -1,
      );
      if (mounted && await thumb.exists()) {
        setState(() => _thumbnailFile = thumb);
      }
    } catch (_) {
      // Abaikan jika platform tidak mendukung VideoCompress, fallback ke backdrop kartu
    }
  }

  Future<void> _handleTap() async {
    if (widget.onOpenVideo != null) {
      await widget.onOpenVideo!();
      return;
    }

    if (_isDownloading) return;

    HapticService.trigger(MekaarHapticIntent.selection);

    // 1. Jika sudah ter-cache secara lokal
    if (_cachedFile != null && await _cachedFile!.exists()) {
      final opened = await FileExportService.openFileWithChooser(
        file: _cachedFile!,
        mimeType: 'video/mp4',
      );
      if (!opened && mounted) {
        MekaarSnackbar.info(
          context,
          'Tidak ada aplikasi pemutar video yang dapat membuka berkas ini.',
        );
      }
      return;
    }

    // 2. Cek apakah berkas di server telah melewati batas retensi (> 30 hari)
    final isExpired = _cachedFile == null &&
        DateTime.now().difference(widget.message.createdAt).inDays >= 30;
    if (isExpired) {
      if (mounted) {
        MekaarSnackbar.warning(
          context,
          'Berkas video di server telah kedaluwarsa (> 30 hari) sesuai batas retensi Supabase.',
        );
      }
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final payload = parseMediaPayload(widget.message);
      final decrypted = await getOrDecryptMedia(
        messageId: widget.message.id,
        url: widget.message.mediaUrl,
        isEncrypted: widget.message.isEncrypted,
        fileKeyB64: payload.fileKeyB64,
      );

      if (!mounted) return;

      if (decrypted == null || !await decrypted.exists()) {
        setState(() => _isDownloading = false);
        if (mounted) {
          MekaarSnackbar.error(context, 'Gagal mengunduh berkas video.');
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final targetMp4 = File(
        '${tempDir.path}/mekaar_video_${widget.message.id}.mp4',
      );

      File finalVideoFile = decrypted;
      if (!decrypted.path.endsWith('.mp4')) {
        try {
          finalVideoFile = await decrypted.copy(targetMp4.path);
        } catch (_) {
          finalVideoFile = decrypted;
        }
      }

      setState(() {
        _isDownloading = false;
        _cachedFile = finalVideoFile;
      });

      _generateThumbnail(finalVideoFile);

      final opened = await FileExportService.openFileWithChooser(
        file: finalVideoFile,
        mimeType: 'video/mp4',
      );
      if (!opened && mounted) {
        MekaarSnackbar.info(
          context,
          'Tidak ada aplikasi pemutar video yang dapat membuka berkas ini.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
        MekaarSnackbar.error(context, 'Terjadi kesalahan saat memproses video.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCaption = widget.caption.trim().isNotEmpty;
    const double cardWidth = 240.0;
    const double cardHeight = 160.0;

    final imageBorderRadius = BorderRadius.only(
      topLeft: widget.borderRadius.topLeft,
      topRight: widget.borderRadius.topRight,
      bottomLeft: hasCaption ? Radius.zero : widget.borderRadius.bottomLeft,
      bottomRight: hasCaption ? Radius.zero : widget.borderRadius.bottomRight,
    );

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: imageBorderRadius,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  // 1. Thumbnail atau Kartu Backdrop
                  if (_thumbnailFile != null && _thumbnailFile!.existsSync())
                    Image.file(
                      _thumbnailFile!,
                      width: cardWidth,
                      height: cardHeight,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    )
                  else
                    Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Color(0xFF1E2638), Color(0xFF10141D)]
                              : const [Color(0xFF2A3447), Color(0xFF1B2230)],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          SolarIconsOutline.videocameraRecord,
                          size: 44,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ),

                  // 2. Kontras overlay gelap
                  Container(
                    color: Colors.black.withValues(
                      alpha: _thumbnailFile != null ? 0.25 : 0.1,
                    ),
                  ),

                  // 3. Badge "VIDEO" di pojok kiri atas
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SolarIconsBold.videocamera,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VIDEO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Tombol Play / Loading Spinner di tengah
                  Center(
                    child: _isDownloading
                        ? Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.65),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.55),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                SolarIconsBold.play,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                  ),

                  // 5. Highlight Seleksi (jika sedang dipilih)
                  if (widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        color: MekaarColors.blue.withValues(
                          alpha: isDark ? 0.35 : 0.22,
                        ),
                      ),
                    ),

                  // 6. Timestamp mengambang jika tidak memiliki teks caption
                  if (!hasCaption && widget.metaWidget != null)
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: widget.metaWidget!,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Teks Caption & Meta di bawah jika ada
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.caption,
                    style: resolveBubbleTextStyle(
                      color: widget.textColor,
                      fontSize: 15,
                      height: 1.35,
                      fontFamily: widget.fontFamily,
                    ),
                  ),
                  if (widget.metaWidget != null) ...[
                    const SizedBox(height: 2),
                    widget.metaWidget!,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
