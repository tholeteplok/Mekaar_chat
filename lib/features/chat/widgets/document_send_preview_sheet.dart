import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../data/models/message_model.dart';

/// Hasil dari lembar konfirmasi/pratinjau pengiriman dokumen berkas.
class DocumentSendResult {
  final File file;
  final String fileName;
  final int fileSize;
  final String caption;

  const DocumentSendResult({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.caption,
  });
}

/// Lembar pratinjau dokumen berkas sebelum dikirim.
/// Menampilkan informasi nama berkas, ukuran, ikon tipe berkas,
/// kolom teks keterangan opsional, dan tombol kirim.
class DocumentSendPreviewSheet extends StatefulWidget {
  final File file;
  final String fileName;
  final int fileSize;
  final Message? replyMessage;
  final VoidCallback? onCancelReply;
  final ChatRoomThemeSpec? roomThemeSpec;

  const DocumentSendPreviewSheet({
    super.key,
    required this.file,
    required this.fileName,
    required this.fileSize,
    this.replyMessage,
    this.onCancelReply,
    this.roomThemeSpec,
  });

  @override
  State<DocumentSendPreviewSheet> createState() => _DocumentSendPreviewSheetState();
}

class _DocumentSendPreviewSheetState extends State<DocumentSendPreviewSheet> {
  late final TextEditingController _captionController;
  late final FocusNode _captionFocusNode;
  late Message? _currentReplyMessage;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _captionFocusNode = FocusNode();
    _currentReplyMessage = widget.replyMessage;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.of(context).pop(
      DocumentSendResult(
        file: widget.file,
        fileName: widget.fileName,
        fileSize: widget.fileSize,
        caption: _captionController.text.trim(),
      ),
    );
  }

  String get _formattedFileSize {
    final size = widget.fileSize;
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _fileExtension {
    final dotIdx = widget.fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < widget.fileName.length - 1) {
      return widget.fileName.substring(dotIdx + 1).toUpperCase();
    }
    return 'FILE';
  }

  ({IconData icon, Color color}) _resolveFileTypeStyle() {
    final ext = _fileExtension.toLowerCase();
    if (ext == 'pdf') {
      return (icon: SolarIconsBold.fileText, color: MekaarColors.sosRed);
    }
    if (['doc', 'docx', 'txt', 'rtf', 'odt'].contains(ext)) {
      return (icon: SolarIconsBold.documentText, color: AppColors.blue);
    }
    if (['xls', 'xlsx', 'csv', 'ods'].contains(ext)) {
      return (icon: SolarIconsBold.documentAdd, color: MekaarColors.guardianTeal);
    }
    if (['ppt', 'pptx', 'odp'].contains(ext)) {
      return (icon: SolarIconsBold.presentationGraph, color: Colors.deepOrange);
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return (icon: SolarIconsBold.archive, color: Colors.amber.shade800);
    }
    return (icon: SolarIconsBold.file, color: MekaarColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = widget.roomThemeSpec?.primaryAccentColor ??
        MekaarColors.primaryOf(context);
    final surfaceColor = MekaarColors.surfaceOf(context);
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final fileStyle = _resolveFileTypeStyle();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121418) : const Color(0xFFF6F8FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(MekaarIcons.back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(
          'Kirim Dokumen',
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: MekaarColors.borderOf(context).withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: fileStyle.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fileStyle.icon,
                            color: fileStyle.color,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          widget.fileName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: fileStyle.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _fileExtension,
                                style: TextStyle(
                                  color: fileStyle.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formattedFileSize,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              SolarIconsBold.shieldCheck,
                              size: 15,
                              color: MekaarColors.guardianTeal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Terenkripsi End-to-End',
                              style: TextStyle(
                                color: MekaarColors.guardianTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bagian Bawah: Balasan (Quote) jika ada + Input Keterangan & Tombol Kirim
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: MekaarColors.borderOf(context).withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentReplyMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: primaryAccent, width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Membalas pesan',
                                  style: TextStyle(
                                    color: primaryAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentReplyMessage!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(SolarIconsOutline.closeCircle, size: 18, color: textSecondary),
                            onPressed: () {
                              setState(() => _currentReplyMessage = null);
                              widget.onCancelReply?.call();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: MekaarColors.surface2Of(context),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _captionController,
                            focusNode: _captionFocusNode,
                            style: TextStyle(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Tambah keterangan (opsional)...',
                              hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _handleSend,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            SolarIconsBold.plain2,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
