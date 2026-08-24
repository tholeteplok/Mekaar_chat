import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/message_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/motion.dart';
import '../../../data/services/media_compressor.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/emoji_pack_model.dart';
import '../providers/emoji_pack_provider.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/utils/error_resolver.dart';

class ChatComposer extends ConsumerStatefulWidget {
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
  final ChatRoomThemeSpec? roomThemeSpec;

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
    this.roomThemeSpec,
  });

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _showEmojiPicker = false;
  List<String> _recentEmojis = [];

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
    _loadRecentEmojis();
  }

  Future<void> _loadRecentEmojis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('frequent_emojis') ?? [];
      if (mounted) {
        setState(() => _recentEmojis = list);
      }
    } catch (_) {}
  }

  Future<void> _saveRecentEmoji(String emoji) async {
    final updated = List<String>.from(_recentEmojis);
    updated.remove(emoji);
    updated.insert(0, emoji);
    if (updated.length > 16) {
      updated.removeLast();
    }
    if (mounted) {
      setState(() => _recentEmojis = updated);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('frequent_emojis', updated);
    } catch (_) {}
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
            step: 0,
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
            step: 1,
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
            step: 2,
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
            step: 3,
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
            step: 4,
            icon: SolarIconsOutline.mapPoint,
            label: 'Bagikan Lokasi',
            color: AppColors.blue,
            onTap: () {
              Navigator.pop(ctx);
              widget.onSendLocation?.call();
            },
          ),
          if (widget.onShareLiveLocation != null)
            _attachItem(
              ctx,
              step: 5,
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
    int step = 0,
  }) {
    // Entrance staggered via AnimatedAppear — token motion + reduced motion.
    return AnimatedAppear(
      delay: MekaarMotion.staggerStep * step,
      child: ListTile(
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
      ),
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

  /// Tab panel aktif: null = emoji standar; string = slug pack terpasang.
  String? _activeEmojiPack;

  Widget _buildEmojiPickerPanel() {
    final installed = ref.watch(installedPacksProvider);
    final catalog = ref.watch(emojiCatalogProvider);

    final packs = catalog.valueOrNull == null
        ? const <EmojiPack>[]
        : (catalog.valueOrNull!)
            .where((p) => installed.isInstalled(p.slug))
            .toList();
    // Jaga tab aktif tetap valid.
    if (_activeEmojiPack != null &&
        !packs.any((p) => p.slug == _activeEmojiPack)) {
      _activeEmojiPack = null;
    }
    final activePack = packs
        .where((p) => p.slug == _activeEmojiPack)
        .cast<EmojiPack?>()
        .firstOrNull;

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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // ── Tab strip: Standar | pack terpasang... | Toko ──
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: MekaarSpacing.md),
              children: [
                _emojiTabChip(
                  label: 'Standar',
                  selected: _activeEmojiPack == null,
                  onTap: () => setState(() => _activeEmojiPack = null),
                ),
                for (final pack in packs)
                  _emojiTabChip(
                    label: pack.name,
                    coverUrl: pack.coverUrl,
                    selected: _activeEmojiPack == pack.slug,
                    onTap: () =>
                        setState(() => _activeEmojiPack = pack.slug),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pushNamed(context, AppRoutes.emojiStore);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: MekaarSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: MekaarColors.accentTextOf(context)
                          .withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(MekaarRadius.pill),
                      border: Border.all(
                        color: MekaarColors.accentTextOf(context)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          SolarIconsOutline.addCircle,
                          size: 16,
                          color: MekaarColors.accentTextOf(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Toko',
                          style: MekaarTypography.labelMD.copyWith(
                            fontWeight: FontWeight.w700,
                            color: MekaarColors.accentTextOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color:
                MekaarColors.textMutedOf(context).withValues(alpha: 0.12),
          ),
          // ── Konten grid ──
          Expanded(
            child: activePack != null
                ? _buildPackGrid(activePack, installed)
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: _buildStandardEmojiGrid(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emojiTabChip({
    required String label,
    String? coverUrl,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: MekaarSpacing.sm),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            color: selected
                ? MekaarColors.primaryOf(context).withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MekaarRadius.pill),
            border: Border.all(
              color: selected
                  ? MekaarColors.primaryOf(context)
                  : MekaarColors.borderOf(context),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (coverUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    coverUrl,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      SolarIconsBold.stickerSmileCircle,
                      size: 16,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: MekaarTypography.labelMD.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? MekaarColors.primaryOf(context)
                      : MekaarColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardEmojiGrid() {
    final emojiCategories = <String, List<String>>{
      if (_recentEmojis.isNotEmpty)
        'Sering Digunakan': _recentEmojis,
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

    return Column(
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
                  color: category.key == 'Sering Digunakan'
                      ? AppColors.blue
                      : MekaarColors.textMutedOf(context),
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
                    _saveRecentEmoji(emoji);
                    _insertAtCursor(emoji);
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
    );
  }

  /// Grid item pack terpasang — membaca file dari disk (luring).
  Widget _buildPackGrid(EmojiPack pack, InstalledPacksState installed) {
    final service = ref.read(emojiPackServiceProvider);
    final items = ref
        .read(emojiCatalogProvider.notifier)
        .itemsOf(pack.slug);
    final downloading = installed.downloading[pack.slug];

    if (downloading != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mengunduh ${pack.name}...',
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textSecondaryOf(context),
                )),
            const SizedBox(height: MekaarSpacing.sm),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(value: downloading, minHeight: 4),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Item pack belum tersedia.',
          style: MekaarTypography.bodySM.copyWith(
            color: MekaarColors.textMutedOf(context),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 56,
        mainAxisSpacing: MekaarSpacing.sm,
        crossAxisSpacing: MekaarSpacing.sm,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () async {
            HapticService.trigger(MekaarHapticIntent.selection);
            final file = await service.resolveLocalFile(item.shortcode);
            if (!mounted) return;
            if (file == null) {
              // File lokal hilang (mis. dibersihkan OS): minta unduh ulang.
              await ref
                  .read(installedPacksProvider.notifier)
                  .install(pack.slug);
              return;
            }
            _insertAtCursor(':${item.shortcode}:');
          },
          child: FutureBuilder<File?>(
            future: service.resolveLocalFile(item.shortcode),
            builder: (context, snap) {
              final file = snap.data;
              if (file == null) {
                return ColoredBox(
                  color: MekaarColors.surface2Of(context),
                  child: Icon(
                    SolarIconsBold.stickerSmileCircle,
                    size: 22,
                    color: MekaarColors.textMutedOf(context),
                  ),
                );
              }
              return Image.file(file, fit: BoxFit.contain);
            },
          ),
        );
      },
    );
  }

  /// Sisipkan teks pada posisi kursor controller.
  void _insertAtCursor(String token) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, token)
        : text + token;
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset:
          (selection.isValid ? selection.start : text.length) + token.length,
    );
  }

  Future<void> _handleKeyboardContentInserted(
    KeyboardInsertedContent content,
  ) async {
    if (!widget.enabled || widget.onSendMedia == null) return;

    try {
      setState(() => _isUploading = true);
      HapticFeedback.selectionClick();

      Uint8List? bytes = content.data;
      if (bytes == null || bytes.isEmpty) {
        final uri = Uri.parse(content.uri);
        if (uri.scheme == 'file') {
          bytes = await File(uri.toFilePath()).readAsBytes();
        } else if (uri.scheme == 'http' || uri.scheme == 'https') {
          final request = await HttpClient().getUrl(uri);
          final response = await request.close();
          bytes = await consolidateHttpClientResponseBytes(response);
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          MekaarSnackbar.error(
            context,
            'Gagal membaca stiker/GIF dari keyboard.',
          );
        }
        return;
      }

      final ext = content.mimeType.contains('gif')
          ? 'gif'
          : (content.mimeType.contains('webp') ? 'webp' : 'png');

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/gboard_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tempFile.writeAsBytes(bytes);

      await widget.onSendMedia!(tempFile, MessageType.image);
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal mengirim stiker/GIF: ${ErrorResolver.resolve(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomPadding = viewInsetsBottom > 0 ? 0.0 : systemBottomPadding;

    final primaryAccent = widget.roomThemeSpec?.primaryAccentColor ?? MekaarColors.softCoral;
    final secondaryAccent = widget.roomThemeSpec?.secondaryAccentColor ?? MekaarColors.textMutedOf(context);
    final glassBorder = widget.roomThemeSpec?.glassBorder;
    final glassBg = widget.roomThemeSpec?.glassBackgroundColor;

    return Padding(
      padding: EdgeInsets.only(left: 8, right: 8, bottom: bottomPadding + 6, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview
          if (widget.replyMessage != null && !_isEditMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: MekaarGlassBlurContainer(
                isFloating: true,
                borderRadius: BorderRadius.circular(16),
                border: glassBorder,
                customColor: glassBg,
                child: _ReplyPreview(
                  message: widget.replyMessage!,
                  onCancel: widget.onCancelReply,
                ),
              ),
            ),
          // Edit mode banner
          if (_isEditMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: MekaarGlassBlurContainer(
                isFloating: true,
                borderRadius: BorderRadius.circular(16),
                border: glassBorder,
                customColor: glassBg,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(SolarIconsOutline.pen, size: 16, color: primaryAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mengedit pesan',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onCancelEdit,
                        child: Icon(SolarIconsOutline.closeSquare, size: 18, color: primaryAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Upload progress indicator
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(
                backgroundColor: MekaarColors.borderOf(context),
                color: primaryAccent,
                minHeight: 2,
              ),
            ),

          // Main composer row (3 Floating Glass Containers)
          _isRecording
              ? MekaarGlassBlurContainer(
                  isFloating: true,
                  height: 48,
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  border: glassBorder,
                  customColor: glassBg,
                  child: GestureDetector(
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
                            size: 20,
                          ),
                          onPressed: _cancelRecording,
                          tooltip: 'Batal Rekam',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
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
                              Text(
                                _recordingSwipeOffset.abs() > 60
                                    ? 'Geser untuk batal'
                                    : 'Merekam... ${_formatDuration(_recordDuration)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _recordingSwipeOffset.abs() > 60
                                      ? MekaarColors.sosRed
                                      : MekaarColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PressableScale(
                          onTap: _stopAndSendRecording,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryAccent,
                            ),
                            child: const Icon(
                              SolarIconsOutline.plain,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── Container 1 (Kiri): Tombol Lampiran 📎 ──
                    if (!_isEditMode) ...[
                      MekaarGlassBlurContainer(
                        isFloating: true,
                        shape: BoxShape.circle,
                        width: 48,
                        height: 48,
                        border: glassBorder,
                        customColor: glassBg,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            SolarIconsOutline.paperclip,
                            color: secondaryAccent,
                            size: 22,
                          ),
                          onPressed: widget.enabled ? _showAttachmentSheet : null,
                          tooltip: 'Lampiran',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // ── Container 2 (Tengah): Input Teks + Emoji 😀 ──
                    Expanded(
                      child: MekaarGlassBlurContainer(
                        isFloating: true,
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          maxHeight: 130,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        border: glassBorder,
                        customColor: glassBg,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!_isEditMode)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                                  icon: Icon(
                                    MekaarIcons.smile,
                                    color: _showEmojiPicker
                                        ? primaryAccent
                                        : secondaryAccent,
                                    size: 22,
                                  ),
                                  onPressed: widget.enabled ? _toggleEmojiPicker : null,
                                  tooltip: 'Emoji',
                                ),
                              ),
                            Expanded(
                              child: TextField(
                                controller: widget.controller,
                                enabled: widget.enabled,
                                keyboardType: TextInputType.multiline,
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization: TextCapitalization.sentences,
                                contentInsertionConfiguration: ContentInsertionConfiguration(
                                  allowedMimeTypes: const <String>[
                                    'image/gif',
                                    'image/png',
                                    'image/jpeg',
                                    'image/webp',
                                  ],
                                  onContentInserted: _handleKeyboardContentInserted,
                                ),
                                decoration: InputDecoration(
                                  hintText: !widget.enabled
                                      ? 'Menyiapkan enkripsi...'
                                      : (_isEditMode ? 'Edit pesan...' : 'Ketik pesan...'),
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: widget.roomThemeSpec?.subtitleColor ?? MekaarColors.textMutedOf(context),
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 10,
                                  ),
                                  isDense: true,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.roomThemeSpec?.textColor ?? MekaarColors.textPrimaryOf(context),
                                ),
                                onSubmitted: (_) => widget.enabled ? widget.onSend() : null,
                                onTap: () {
                                  if (_showEmojiPicker) {
                                    setState(() => _showEmojiPicker = false);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Container 3 (Kanan): Mikrofon / Kirim 🎤 / ✈️ ──
                    MekaarGlassBlurContainer(
                      isFloating: true,
                      shape: BoxShape.circle,
                      width: 48,
                      height: 48,
                      border: glassBorder,
                      customColor: glassBg,
                      child: Semantics(
                        button: true,
                        label: _isEditMode ? 'Simpan edit' : (_hasText ? 'Kirim pesan' : 'Rekam suara'),
                        child: PressableScale(
                          onTap: !widget.enabled
                              ? null
                              : (_isEditMode || _hasText ? widget.onSend : _startRecording),
                          child: Center(
                            child: Icon(
                              _isEditMode
                                  ? SolarIconsOutline.checkCircle
                                  : (_hasText ? SolarIconsOutline.plain : SolarIconsOutline.microphone),
                              color: (_isEditMode || _hasText)
                                  ? primaryAccent
                                  : (widget.roomThemeSpec?.iconColor ?? MekaarColors.textPrimaryOf(context)),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          // Panel Emoji
          if (_showEmojiPicker) ...[
            const SizedBox(height: 8),
            MekaarGlassBlurContainer(
              isFloating: true,
              borderRadius: BorderRadius.circular(20),
              border: glassBorder,
              customColor: glassBg,
              child: _buildEmojiPickerPanel(),
            ),
          ],
        ],
      ),
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
      duration: MekaarMotion.loop,
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
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
          HapticService.trigger(MekaarHapticIntent.selection);
          onCancel();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MekaarSpacing.lg,
          vertical: MekaarSpacing.sm,
        ),
        color: MekaarColors.surface2Of(context),
        child: Row(
          children: [
            Icon(
              SolarIconsOutline.forward,
              size: MekaarSizes.iconSm,
              color: MekaarColors.textSecondaryOf(context),
            ),
            const SizedBox(width: MekaarSpacing.sm),
            Expanded(
              child: Text(
                'Membalas: ${message.content}',
                style: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textSecondaryOf(context),
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
      ),
    );
  }
}