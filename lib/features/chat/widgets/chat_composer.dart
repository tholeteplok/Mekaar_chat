import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';

import '../../../core/constants/motion.dart';
import '../../../data/services/media_compressor.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final Message? replyMessage;
  final Message? editingMessage; // non-null when in edit mode
  final VoidCallback onSend;
  final VoidCallback onCancelReply;
  final VoidCallback? onCancelEdit;
  final Future<void> Function(File file, MessageType type)? onSendMedia;
  final Future<void> Function()? onSendLocation;
  final Future<void> Function(int durationMinutes)? onShareLiveLocation;
  final bool enabled;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.replyMessage,
    required this.onSend,
    required this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onSendMedia,
    this.onSendLocation,
    this.onShareLiveLocation,
    this.enabled = true,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _showEmojiPicker = false;

  AudioRecorder? _audioRecorder;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _recordingPath;
  double _recordingSwipeOffset = 0;
  static const double _recordingSwipeThreshold = 120;

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
    _recordTimer?.cancel();
    _audioRecorder?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    try {
      _audioRecorder ??= AudioRecorder();
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          MekaarSnackbar.error(context, 'Izin mikrofon diperlukan untuk merekam suara.');
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path;

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordDuration++;
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    if (_audioRecorder == null || !_isRecording) return;

    try {
      final path = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      if (path != null && widget.onSendMedia != null) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          final compressed = await MediaCompressor.compressAudio(file);
          await widget.onSendMedia!(compressed, MessageType.voice);
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    if (_audioRecorder == null || !_isRecording) return;

    try {
      await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    }
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
      final compressed = await MediaCompressor.compressImage(File(picked.path));
      await widget.onSendMedia!(compressed, MessageType.image);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (widget.onSendMedia == null) return;
    try {
      final picked = await _picker.pickVideo(source: source);
      if (picked == null || !mounted) return;
      setState(() => _isUploading = true);
      final compressed = await MediaCompressor.compressVideo(File(picked.path));
      await widget.onSendMedia!(compressed, MessageType.video);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentSheet() {
    HapticService.trigger(MekaarHapticIntent.selection);
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            icon: SolarIconsOutline.videoLibrary,
            label: 'Pilih dari Galeri Video',
            color: MekaarColors.purple,
            onTap: () {
              Navigator.pop(ctx);
              _pickVideo(ImageSource.gallery);
            },
          ),
          _attachItem(
            ctx,
            icon: SolarIconsOutline.videocamera,
            label: 'Rekam Video',
            color: MekaarColors.pink,
            onTap: () {
              Navigator.pop(ctx);
              _pickVideo(ImageSource.camera);
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
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MekaarColors.textPrimaryOf(context))),
      onTap: onTap,
    );
  }

  void _showLiveDurationSheet(BuildContext ctx) {
    final durations = [5, 15, 30];
    MekaarBottomSheet.show(
      context: ctx,
      showDragHandle: true,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
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

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  Widget _buildEmojiPickerPanel() {
    final emojiCategories = <String, List<String>>{
      'Ekspresi & Wajah': [
        '😀', '😂', '😍', '🥰', '😎', '🥳', '🤩', '😇',
        '😋', '🤪', '😜', '🤗', '🤔', '🫣', '😌', '😏',
        '😤', '😭', '🥺', '😱', '🤯', '😴', '😷', '😈',
      ],
      'Isyarat & Tangan': [
        '👍', '👎', '👏', '🙌', '🤝', '🙏', '✌️', '🤞',
        '🤟', '🤘', '👌', '🤏', '👈', '👉', '👆', '👇',
        '💪', '🔥', '✨', '⭐', '⚡', '💥', '🎉', '🎊',
      ],
      'Hati & Cinta': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
      ],
      'Simbol & Benda': [
        '🎈', '🎁', '🏆', '💯', '🌟', '☀️', '🌙', '☕',
        '🍕', '🚀', '🛡️', '🔒', '🔑', '💬', '📢', '🔔',
      ],
    };

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: MekaarColors.surfaceOf(context),
        border: Border(
          top: BorderSide(
            color: MekaarColors.textMutedOf(context).withValues(alpha: 0.15),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: emojiCategories.entries.map((category) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text(
                    category.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.textMutedOf(context),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: category.value.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        final text = widget.controller.text;
                        final selection = widget.controller.selection;
                        final newText = selection.isValid
                            ? text.replaceRange(selection.start, selection.end, emoji)
                            : text + emoji;
                        widget.controller.text = newText;
                        widget.controller.selection = TextSelection.collapsed(
                          offset: (selection.isValid ? selection.start : text.length) + emoji.length,
                        );
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }).toList(),
        ),
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: _isRecording
              ? GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() => _recordingSwipeOffset += details.delta.dx);
                  },
                  onHorizontalDragEnd: (details) {
                    if (_recordingSwipeOffset.abs() > _recordingSwipeThreshold) {
                      _cancelRecording();
                    }
                    setState(() => _recordingSwipeOffset = 0);
                  },
                  child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        SolarIconsOutline.trashBinMinimalistic,
                        color: MekaarColors.sosRed,
                        size: 22,
                      ),
                      onPressed: _cancelRecording,
                      tooltip: 'Batal Rekam',
                    ),
                    const SizedBox(width: MekaarSpacing.sm),
                    Expanded(
                      child: AnimatedContainer(
                        duration: MekaarMotion.fast,
                        decoration: BoxDecoration(
                          color: _recordingSwipeOffset.abs() > 60
                              ? MekaarColors.sosRed.withValues(alpha: 0.15)
                              : MekaarColors.surface2Of(context),
                          borderRadius: BorderRadius.circular(MekaarRadius.xl),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MekaarSpacing.lg,
                          vertical: MekaarSpacing.md,
                        ),
                        child: Row(
                          children: [
                            if (_recordingSwipeOffset.abs() > 60)
                              const Icon(
                                SolarIconsOutline.trashBinMinimalistic,
                                color: MekaarColors.sosRed,
                                size: 16,
                              )
                            else ...[
                              const _BlinkingDot(),
                              const SizedBox(width: 8),
                            ],
                            if (_recordingSwipeOffset.abs() > 60)
                              const SizedBox(width: 8),
                            Text(
                              _recordingSwipeOffset.abs() > 60
                                  ? 'Geser untuk batal'
                                  : 'Merekam... ${_formatDuration(_recordDuration)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _recordingSwipeOffset.abs() > 60
                                    ? MekaarColors.sosRed
                                    : MekaarColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: MekaarSpacing.sm),
                    Semantics(
                      button: true,
                      label: 'Kirim rekaman',
                      child: PressableScale(
                        onTap: _stopAndSendRecording,
                        child: AnimatedContainer(
                          duration: MekaarMotion.fast,
                          curve: MekaarMotion.standard,
                          width: MekaarSizes.composerButton,
                          height: MekaarSizes.composerButton,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MekaarColors.softCoral,
                          ),
                          child: const Icon(
                            SolarIconsOutline.plain,
                            color: Colors.white,
                            size: MekaarSizes.iconSm,
                          ),
                        ),
                      ),
                    ),
                  ],
                ))
              : Row(
                  children: [
                    // Attachment button & Emoji button
                    if (!_isEditMode) ...[
                      IconButton(
                        icon: const Icon(SolarIconsOutline.paperclip,
                            color: MekaarColors.textMuted, size: 22),
                        onPressed: widget.enabled ? _showAttachmentSheet : null,
                        tooltip: 'Lampiran',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                          color: _showEmojiPicker
                              ? MekaarColors.softCoral
                              : MekaarColors.textMutedOf(context),
                          size: 24,
                        ),
                        onPressed: widget.enabled ? _toggleEmojiPicker : null,
                        tooltip: 'Emoji',
                      ),
                    ],
                    // Text input
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: MekaarColors.surface2Of(context),
                          borderRadius: BorderRadius.circular(MekaarRadius.xl),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MekaarSpacing.lg,
                        ),
                        child: TextField(
                          controller: widget.controller,
                          enabled: widget.enabled,
                          decoration: InputDecoration(
                            hintText: !widget.enabled
                                ? 'Menyiapkan enkripsi...'
                                : (_isEditMode ? 'Edit pesan...' : 'Ketik pesan...'),
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
                          onSubmitted: (_) =>
                              widget.enabled ? widget.onSend() : null,
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() => _showEmojiPicker = false);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: MekaarSpacing.sm),
                    // Send/Mic button (morph antara mic & kirim tergantung ada teks)
                    Semantics(
                      button: true,
                      label: _isEditMode
                          ? 'Simpan edit'
                          : (_hasText ? 'Kirim pesan' : 'Rekam suara'),
                      child: PressableScale(
                        onTap: !widget.enabled
                            ? null
                            : (_isEditMode || _hasText ? widget.onSend : _startRecording),
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
                                    : MekaarColors.surface2Of(context)),
                          ),
                          child: Icon(
                            _isEditMode
                                ? SolarIconsOutline.checkCircle
                                : (_hasText ? SolarIconsOutline.plain : SolarIconsOutline.microphone),
                            color: (_isEditMode || _hasText)
                                ? Colors.white
                                : (Theme.of(context).brightness == Brightness.light
                                    ? const Color(0xFF1B2145)
                                    : MekaarColors.textPrimary),
                            size: MekaarSizes.iconSm,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (_showEmojiPicker) _buildEmojiPickerPanel(),
      ],
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: MekaarColors.sosRed,
          shape: BoxShape.circle,
        ),
      ),
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
      color: MekaarColors.surface2Of(context),
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
