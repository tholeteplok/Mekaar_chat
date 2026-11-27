import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/media_attachment_limits.dart';
import '../../../core/constants/themes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../data/models/message_model.dart';

/// Item dokumen kandidat pada lembar pratinjau kirim dokumen.
class DocumentDraftItem {
  final File file;
  final String fileName;
  final int fileSize;

  const DocumentDraftItem({
    required this.file,
    required this.fileName,
    required this.fileSize,
  });
}

/// Hasil dari lembar konfirmasi/pratinjau pengiriman dokumen berkas.
class DocumentSendResult {
  final List<DocumentDraftItem> items;
  final String caption;

  File get file => items.first.file;
  String get fileName => items.first.fileName;
  int get fileSize => items.first.fileSize;

  DocumentSendResult({
    required File file,
    required String fileName,
    required int fileSize,
    required this.caption,
  }) : items = [
         DocumentDraftItem(file: file, fileName: fileName, fileSize: fileSize),
       ];

  DocumentSendResult.multi({
    required this.items,
    required this.caption,
  }) : assert(items.isNotEmpty, 'Minimal 1 dokumen harus disediakan.');
}

/// Lembar pratinjau dokumen berkas sebelum dikirim (tunggal atau jamak).
class DocumentSendPreviewSheet extends StatefulWidget {
  final List<DocumentDraftItem> documents;
  final Message? replyMessage;
  final VoidCallback? onCancelReply;
  final ChatRoomThemeSpec? roomThemeSpec;

  DocumentSendPreviewSheet({
    super.key,
    required File file,
    required String fileName,
    required int fileSize,
    this.replyMessage,
    this.onCancelReply,
    this.roomThemeSpec,
  }) : documents = [
         DocumentDraftItem(file: file, fileName: fileName, fileSize: fileSize),
       ];

  const DocumentSendPreviewSheet.multi({
    super.key,
    required this.documents,
    this.replyMessage,
    this.onCancelReply,
    this.roomThemeSpec,
  });

  @override
  State<DocumentSendPreviewSheet> createState() =>
      _DocumentSendPreviewSheetState();
}

class _DocumentSendPreviewSheetState extends State<DocumentSendPreviewSheet> {
  late final TextEditingController _captionController;
  late final FocusNode _captionFocusNode;
  late Message? _currentReplyMessage;
  late List<DocumentDraftItem> _items;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _captionFocusNode = FocusNode();
    _currentReplyMessage = widget.replyMessage;
    _items = List<DocumentDraftItem>.from(widget.documents);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  int get _totalBytes =>
      _items.fold<int>(0, (sum, item) => sum + item.fileSize);

  void _removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    if (_items.length <= 1) {
      Navigator.of(context).pop(null);
      return;
    }
    setState(() => _items.removeAt(index));
  }

  void _handleSend() {
    if (_items.isEmpty) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.of(context).pop(
      DocumentSendResult.multi(
        items: List<DocumentDraftItem>.unmodifiable(_items),
        caption: _captionController.text.trim(),
      ),
    );
  }

  String _fileExtension(String fileName) {
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < fileName.length - 1) {
      return fileName.substring(dotIdx + 1).toUpperCase();
    }
    return 'FILE';
  }

  ({IconData icon, Color color}) _resolveFileTypeStyle(String fileName) {
    final ext = _fileExtension(fileName).toLowerCase();
    if (ext == 'pdf') {
      return (icon: SolarIconsBold.fileText, color: MekaarColors.sosRed);
    }
    if (['doc', 'docx', 'txt', 'rtf', 'odt'].contains(ext)) {
      return (icon: SolarIconsBold.documentText, color: AppColors.blue);
    }
    if (['xls', 'xlsx', 'csv', 'ods'].contains(ext)) {
      return (
        icon: SolarIconsBold.documentAdd,
        color: MekaarColors.guardianTeal,
      );
    }
    if (['ppt', 'pptx', 'odp'].contains(ext)) {
      return (
        icon: SolarIconsBold.presentationGraph,
        color: Colors.deepOrange,
      );
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return (icon: SolarIconsBold.archive, color: Colors.amber.shade800);
    }
    return (icon: SolarIconsBold.file, color: MekaarColors.info);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent =
        widget.roomThemeSpec?.primaryAccentColor ??
        MekaarColors.primaryOf(context);
    final surfaceColor = MekaarColors.surfaceOf(context);
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final isMulti = _items.length > 1;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121418)
          : const Color(0xFFF6F8FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(MekaarIcons.back, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(
          isMulti
              ? 'Kirim Dokumen (${_items.length}/${MediaAttachmentLimits.maxDocumentsPerBatch})'
              : 'Kirim Dokumen',
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
            if (isMulti)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: MekaarColors.surface2Of(context),
                child: Text(
                  '${_items.length}/${MediaAttachmentLimits.maxDocumentsPerBatch} berkas • '
                  '${MediaAttachmentLimits.formatBytes(_totalBytes)} / 20 MB • '
                  'Auto-hapus server ${MediaAttachmentLimits.serverRetentionDays} hari',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: isMulti
                  ? ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = _items[index];
                        final fileStyle = _resolveFileTypeStyle(doc.fileName);
                        final ext = _fileExtension(doc.fileName);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: MekaarColors.borderOf(
                                context,
                              ).withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: fileStyle.color.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  fileStyle.icon,
                                  color: fileStyle.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: fileStyle.color.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            ext,
                                            style: TextStyle(
                                              color: fileStyle.color,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          MediaAttachmentLimits.formatBytes(
                                            doc.fileSize,
                                          ),
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  SolarIconsOutline.closeCircle,
                                  color: textSecondary,
                                  size: 20,
                                ),
                                tooltip: 'Hapus berkas',
                                onPressed: () => _removeAt(index),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : _buildSingleDocumentCard(
                      context,
                      doc: _items.first,
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
            ),

            // Bagian Bawah: Balasan (Quote) jika ada + Input Keterangan & Tombol Kirim
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: MekaarColors.borderOf(
                      context,
                    ).withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentReplyMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            icon: Icon(
                              SolarIconsOutline.closeCircle,
                              size: 18,
                              color: textSecondary,
                            ),
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
                            decoration: MekaarTheme.borderlessInputDecoration(
                              hintText: 'Tambah keterangan (opsional)...',
                              hintStyle: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
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

  Widget _buildSingleDocumentCard(
    BuildContext context, {
    required DocumentDraftItem doc,
    required bool isDark,
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final fileStyle = _resolveFileTypeStyle(doc.fileName);
    final ext = _fileExtension(doc.fileName);

    return Center(
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
                child: Icon(fileStyle.icon, color: fileStyle.color, size: 42),
              ),
              const SizedBox(height: 18),
              Text(
                doc.fileName,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: fileStyle.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ext,
                      style: TextStyle(
                        color: fileStyle.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    MediaAttachmentLimits.formatBytes(doc.fileSize),
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
              const SizedBox(height: 8),
              Text(
                MediaAttachmentLimits.retentionNotice,
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
