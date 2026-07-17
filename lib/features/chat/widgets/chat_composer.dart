import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/message_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/widgets/animations.dart';

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final Message? replyMessage;
  final Message? editingMessage; // non-null when in edit mode
  final bool isViewOnce;
  final VoidCallback onSend;
  final VoidCallback onToggleViewOnce;
  final VoidCallback onCancelReply;
  final VoidCallback? onCancelEdit;
  final Future<void> Function(File file, MessageType type)? onSendMedia;
  final Future<void> Function()? onSendLocation;
  final Future<void> Function(int durationMinutes)? onShareLiveLocation;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.replyMessage,
    required this.isViewOnce,
    required this.onSend,
    required this.onToggleViewOnce,
    required this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onSendMedia,
    this.onSendLocation,
    this.onShareLiveLocation,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  bool get _isEditMode => widget.editingMessage != null;
  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    if (widget.onSendMedia == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null || !mounted) return;
      setState(() => _isUploading = true);
      await widget.onSendMedia!(File(picked.path), MessageType.image);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MekaarColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MekaarColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _attachItem(
              ctx,
              icon: SolarIconsOutline.gallery,
              label: 'Pilih dari Galeri',
              color: MekaarColors.info,
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            _attachItem(
              ctx,
              icon: SolarIconsOutline.camera,
              label: 'Ambil Foto',
              color: MekaarColors.guardianTeal,
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            _attachItem(
              ctx,
              icon: SolarIconsOutline.mapPoint,
              label: 'Bagikan Lokasi',
              color: MekaarColors.softCoral,
              onTap: () {
                Navigator.pop(ctx);
                widget.onSendLocation?.call();
              },
            ),
            if (widget.onShareLiveLocation != null)
              _attachItem(
                ctx,
                icon: SolarIconsOutline.gps,
                label: 'Lokasi Live',
                color: MekaarColors.guardianTeal,
                onTap: () {
                  Navigator.pop(ctx);
                  _showLiveDurationSheet(ctx);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _attachItem(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MekaarColors.textPrimary)),
      onTap: onTap,
    );
  }

  void _showLiveDurationSheet(BuildContext ctx) {
    final durations = [5, 15, 30];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: MekaarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bagikan Lokasi Live Selama',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ...durations.map(
            (m) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(SolarIconsOutline.gps,
                    color: MekaarColors.guardianTeal, size: 20),
              ),
              title: Text('$m menit'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await widget.onShareLiveLocation?.call(m);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (widget.replyMessage != null && !_isEditMode)
          _ReplyPreview(
            message: widget.replyMessage!,
            onCancel: widget.onCancelReply,
          ),
        // Edit mode banner
        if (_isEditMode)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: MekaarColors.softCoral.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(SolarIconsOutline.pen,
                    size: 16, color: MekaarColors.softCoral),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mengedit pesan',
                    style: TextStyle(
                        fontSize: 12,
                        color: MekaarColors.softCoral,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCancelEdit,
                  child: const Icon(SolarIconsOutline.closeSquare,
                      size: 18, color: MekaarColors.softCoral),
                ),
              ],
            ),
          ),
        // Upload progress indicator
        if (_isUploading)
          const LinearProgressIndicator(
            backgroundColor: MekaarColors.borderLight,
            color: MekaarColors.softCoral,
            minHeight: 2,
          ),
        // Main composer row
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.md,
            vertical: MekaarSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: MekaarColors.surface,
            border: Border(
              top: BorderSide(color: MekaarColors.borderLight, width: 1),
            ),
          ),
          child: Row(
            children: [
              // View-once toggle
              IconButton(
                icon: Icon(
                  SolarIconsOutline.eye,
                  color: widget.isViewOnce
                      ? MekaarColors.softCoral
                      : MekaarColors.textMuted,
                  size: 22,
                ),
                onPressed: widget.onToggleViewOnce,
                tooltip: 'Mode Sekali Lihat',
              ),
              // Attachment button
              if (!_isEditMode)
                IconButton(
                  icon: const Icon(SolarIconsOutline.paperclip,
                      color: MekaarColors.textMuted, size: 22),
                  onPressed: _showAttachmentSheet,
                  tooltip: 'Lampiran',
                ),
              // Text input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: MekaarColors.surface2,
                    borderRadius: BorderRadius.circular(MekaarRadius.xl),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: MekaarSpacing.lg,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    decoration: InputDecoration(
                      hintText: _isEditMode
                          ? 'Edit pesan...'
                          : 'Ketik pesan...',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: MekaarSpacing.md,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
              ),
              const SizedBox(width: MekaarSpacing.sm),
              // Send button (morph antara mic & kirim tergantung ada teks)
              Semantics(
                button: true,
                label: _isEditMode
                    ? 'Simpan edit'
                    : (_hasText ? 'Kirim pesan' : 'Rekam suara'),
                child: PressableScale(
                  onTap: widget.onSend,
                  child: AnimatedContainer(
                    duration: MekaarMotion.fast,
                    curve: MekaarMotion.standard,
                    width: MekaarSizes.composerButton,
                    height: MekaarSizes.composerButton,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isEditMode
                          ? MekaarColors.softCoral
                          : (_hasText
                              ? MekaarColors.softCoral
                              : MekaarColors.textPrimary),
                    ),
                    child: Icon(
                      _isEditMode
                          ? SolarIconsOutline.checkCircle
                          : (_hasText ? SolarIconsOutline.plain : SolarIconsOutline.microphone),
                      color: Colors.white,
                      size: MekaarSizes.iconSm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Reply Preview Banner
// ─────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final Message message;
  final VoidCallback onCancel;

  const _ReplyPreview({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MekaarSpacing.lg,
        vertical: MekaarSpacing.sm,
      ),
      color: MekaarColors.surface2,
      child: Row(
        children: [
          const Icon(
            SolarIconsOutline.forward,
            size: MekaarSizes.iconSm,
            color: MekaarColors.textSecondary,
          ),
          const SizedBox(width: MekaarSpacing.sm),
          Expanded(
            child: Text(
              'Membalas: ${message.content}',
              style: const TextStyle(
                fontSize: 12,
                color: MekaarColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(SolarIconsOutline.closeCircle, size: MekaarSizes.iconSm),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
