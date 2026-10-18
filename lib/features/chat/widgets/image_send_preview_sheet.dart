import 'dart:io';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../data/models/message_model.dart';

/// Hasil dari lembar pratinjau pengiriman media.
class ImageSendResult {
  final File file;
  final String caption;
  final bool isViewOnce;

  const ImageSendResult({
    required this.file,
    required this.caption,
    this.isViewOnce = false,
  });
}

/// Lembar pratinjau media sebelum dikirim (ala WhatsApp & Telegram).
/// Memungkinkan penambahan keterangan (caption), pratinjau pesan balasan (quote),
/// dan tombol toggle sekali lihat (view once).
class ImageSendPreviewSheet extends StatefulWidget {
  final File imageFile;
  final Message? replyMessage;
  final VoidCallback? onCancelReply;
  final ChatRoomThemeSpec? roomThemeSpec;

  const ImageSendPreviewSheet({
    super.key,
    required this.imageFile,
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
  bool _isViewOnce = false;
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
      ImageSendResult(
        file: widget.imageFile,
        caption: _captionController.text.trim(),
        isViewOnce: _isViewOnce,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryAccent =
        widget.roomThemeSpec?.primaryAccentColor ?? MekaarColors.softCoral;

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
        title: const Text(
          'Pratinjau Foto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pratinjau Gambar Penuh (bisa di-zoom/pan)
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
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
                  // Tombol Sekali Lihat (View Once)
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
                            color: _isViewOnce ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Tambah keterangan...',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
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
