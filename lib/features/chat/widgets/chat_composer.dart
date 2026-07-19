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
import '../../../core/constants/typography.dart';
import '../../../core/constants/motion.dart';
import '../../../core/services/haptic_service.dart';
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
  final int autoDeleteHours;
  final ValueChanged<int>? onAutoDeleteChanged;

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
    this.autoDeleteHours = 0,
    this.onAutoDeleteChanged,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  AudioRecorder? _audioRecorder;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _recordingPath;

  bool get _isEditMode => widget.editingMessage != null;
  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  late int _autoDeleteHours;

  @override
  void initState() {
    super.initState();
    _autoDeleteHours = widget.autoDeleteHours;
    widget.controller.addListener(_onTextChanged);
  }

  void _setAutoDeleteHours(int hours) {
    setState(() => _autoDeleteHours = hours);
    widget.onAutoDeleteChanged?.call(hours);
  }

  String _autoDeleteLabel() {
    if (_autoDeleteHours <= 0) return 'Pesan Menghilang';
    if (_autoDeleteHours == 1) return 'Menghilang: 1 jam';
    if (_autoDeleteHours == 24) return 'Menghilang: 1 hari';
    if (_autoDeleteHours == 168) return 'Menghilang: 7 hari';
    return 'Menghilang: $_autoDeleteHours jam';
  }

  Future<void> _showAutoDeleteMenu() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [
          (0, 'Mati', 'Pesan disimpan selamanya'),
          (1, '1 Jam', 'Pesan otomatis terhapus setelah 1 jam'),
          (24, '1 Hari', 'Pesan otomatis terhapus setelah 1 hari'),
          (168, '7 Hari', 'Pesan otomatis terhapus setelah 7 hari'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('Pesan Menghilang', style: MekaarTypography.headingSM),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final selected = opt.$1 == _autoDeleteHours;
                return ListTile(
                  leading: Icon(
                    selected ? SolarIconsBold.history : SolarIconsOutline.history,
                    color: selected ? MekaarColors.softCoral : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3),
                  trailing: selected
                      ? const Icon(Icons.check, color: MekaarColors.softCoral)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt.$1),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (choice != null) _setAutoDeleteHours(choice);
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin mikrofon diperlukan untuk merekam suara.'),
              backgroundColor: MekaarColors.sosRed,
            ),
          );
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
          await widget.onSendMedia!(file, MessageType.voice);
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
      await widget.onSendMedia!(File(picked.path), MessageType.image);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentSheet() {
    HapticService.trigger(MekaarHapticIntent.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context),
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
      backgroundColor: MekaarColors.surfaceOf(context),
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
              ? Row(
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: MekaarColors.surface2Of(context),
                          borderRadius: BorderRadius.circular(MekaarRadius.xl),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MekaarSpacing.lg,
                          vertical: MekaarSpacing.md,
                        ),
                        child: Row(
                          children: [
                            const _BlinkingDot(),
                            const SizedBox(width: 8),
                            Text(
                              'Merekam... ${_formatDuration(_recordDuration)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: MekaarColors.textSecondary,
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
                )
              : Row(
                  children: [
                    // Auto-delete (disappearing messages) toggle
                    IconButton(
                      icon: Icon(
                        _autoDeleteHours > 0
                            ? SolarIconsBold.history
                            : SolarIconsOutline.history,
                        color: _autoDeleteHours > 0
                            ? MekaarColors.softCoral
                            : MekaarColors.textMuted,
                        size: 22,
                      ),
                      onPressed: _showAutoDeleteMenu,
                      tooltip: _autoDeleteLabel(),
                    ),
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
                          color: MekaarColors.surface2Of(context),
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
                    // Send/Mic button (morph antara mic & kirim tergantung ada teks)
                    Semantics(
                      button: true,
                      label: _isEditMode
                          ? 'Simpan edit'
                          : (_hasText ? 'Kirim pesan' : 'Rekam suara'),
                      child: PressableScale(
                        onTap: _isEditMode || _hasText ? widget.onSend : _startRecording,
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
