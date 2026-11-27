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

/// Hasil dari lembar pratinjau pengiriman media (mendukung 1 atau beberapa foto).
class ImageSendResult {
  final List<File> files;
  final String caption;
  final bool isViewOnce;

  File get file => files.first;

  ImageSendResult({
    File? file,
    List<File>? files,
    required this.caption,
    this.isViewOnce = false,
  }) : assert(
         file != null || (files != null && files.isNotEmpty),
         'Minimal 1 berkas foto harus disediakan.',
       ),
       files = files ?? [file!];
}

/// Lembar pratinjau media sebelum dikirim (ala WhatsApp & Telegram).
/// Mendukung mode tunggal maupun jamak (PageView, strip thumbnail, hapus item,
/// ringkasan kuota ketat, keterangan bersama, serta tombol toggle sekali lihat
/// untuk foto tunggal).
class ImageSendPreviewSheet extends StatefulWidget {
  final List<File> imageFiles;
  final Message? replyMessage;
  final VoidCallback? onCancelReply;
  final ChatRoomThemeSpec? roomThemeSpec;

  ImageSendPreviewSheet({
    super.key,
    required File imageFile,
    this.replyMessage,
    this.onCancelReply,
    this.roomThemeSpec,
  }) : imageFiles = [imageFile];

  const ImageSendPreviewSheet.multi({
    super.key,
    required this.imageFiles,
    this.replyMessage,
    this.onCancelReply,
    this.roomThemeSpec,
  });

  @override
  State<ImageSendPreviewSheet> createState() => _ImageSendPreviewSheetState();
}

class _ImageSendPreviewSheetState extends State<ImageSendPreviewSheet> {
  late final TextEditingController _captionController;
  late final FocusNode _captionFocusNode;
  late final PageController _pageController;
  late List<File> _files;
  int _currentIndex = 0;
  bool _isViewOnce = false;
  late Message? _currentReplyMessage;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _captionFocusNode = FocusNode();
    _files = List<File>.from(widget.imageFiles);
    _pageController = PageController();
    _currentReplyMessage = widget.replyMessage;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int get _totalBytes {
    var total = 0;
    for (final f in _files) {
      if (f.existsSync()) {
        total += f.lengthSync();
      }
    }
    return total;
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _files.length) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    if (_files.length <= 1) {
      Navigator.of(context).pop(null);
      return;
    }
    setState(() {
      _files.removeAt(index);
      if (_currentIndex >= _files.length) {
        _currentIndex = _files.length - 1;
      }
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  void _handleSend() {
    if (_files.isEmpty) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.of(context).pop(
      ImageSendResult(
        files: List<File>.unmodifiable(_files),
        caption: _captionController.text.trim(),
        isViewOnce: _files.length == 1 ? _isViewOnce : false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryAccent =
        widget.roomThemeSpec?.primaryAccentColor ?? MekaarColors.softCoral;
    final isMulti = _files.length > 1;
    final titleText = isMulti
        ? 'Pratinjau Foto (${_currentIndex + 1}/${_files.length})'
        : 'Pratinjau Foto';

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(MekaarIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(
          titleText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (isMulti)
            IconButton(
              icon: const Icon(
                SolarIconsOutline.trashBinMinimalistic,
                color: Colors.white,
              ),
              tooltip: 'Hapus foto ini',
              onPressed: () => _removeAt(_currentIndex),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pratinjau Gambar Penuh (swipeable saat jamak, zoom/pan per foto)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _files.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) => Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.file(
                      _files[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Strip Kuota & Info Retensi Server 7 Hari
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              color: Colors.black.withValues(alpha: 0.65),
              child: Text(
                '${_files.length}/${MediaAttachmentLimits.maxImagesPerBatch} foto • '
                '${MediaAttachmentLimits.formatBytes(_totalBytes)} / 20 MB • '
                'Hapus otomatis server ${MediaAttachmentLimits.serverRetentionDays} hari',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Strip Thumbnail Horizontal saat >1 Foto
            if (isMulti)
              Container(
                height: 68,
                color: Colors.black.withValues(alpha: 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isActive = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentIndex = index);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive
                                    ? primaryAccent
                                    : Colors.white.withValues(alpha: 0.25),
                                width: isActive ? 2.2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _files[index],
                                fit: BoxFit.cover,
                                cacheWidth: 120,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: () => _removeAt(index),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white54,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Banner Quote Balasan (jika ada)
            if (_currentReplyMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: primaryAccent, width: 3.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Membalas pesan',
                            style: TextStyle(
                              color: primaryAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _currentReplyMessage!.content,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        SolarIconsOutline.closeCircle,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() => _currentReplyMessage = null);
                        widget.onCancelReply?.call();
                      },
                    ),
                  ],
                ),
              ),

            // Bilah Input Keterangan & Kontrol Pengiriman
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              color: Colors.black.withValues(alpha: 0.75),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tombol Sekali Lihat (View Once) — hanya aktif untuk foto tunggal
                  if (!isMulti) ...[
                    GestureDetector(
                      onTap: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        setState(() => _isViewOnce = !_isViewOnce);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isViewOnce
                              ? primaryAccent
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            '(1)',
                            style: TextStyle(
                              color: _isViewOnce
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Kolom Keterangan (Caption)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _captionController,
                        focusNode: _captionFocusNode,
                        cursorColor: Colors.white,
                        keyboardAppearance: Brightness.dark,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: MekaarTheme.borderlessInputDecoration(
                          hintText: isMulti
                              ? 'Tambah keterangan album...'
                              : 'Tambah keterangan...',
                          hintStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tombol Kirim
                  GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryAccent,
                      ),
                      child: const Center(
                        child: Icon(
                          SolarIconsBold.plain,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
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
