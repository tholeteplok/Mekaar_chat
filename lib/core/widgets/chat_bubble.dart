import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/message_model.dart';
import '../../data/services/e2ee_service.dart';
import '../constants/colors.dart';
import '../constants/shadows.dart';
import '../services/haptic_service.dart';
import 'animations.dart';

// Helper function to download, decrypt, and cache E2EE media locally.
Future<File?> _getOrDecryptMedia({
  required String messageId,
  required String? url,
  required bool isEncrypted,
  required String fileKeyB64,
}) async {
  if (url == null || url.isEmpty) return null;

  try {
    final tempDir = await getTemporaryDirectory();
    final uri = Uri.parse(url);
    final ext = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'bin';
    final cachedFile = File('${tempDir.path}/decrypted_$messageId.$ext');

    if (await cachedFile.exists()) {
      return cachedFile;
    }

    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) return null;

    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

    if (isEncrypted && fileKeyB64.isNotEmpty) {
      final decryptedBytes = await E2eeService.instance.decryptMedia(bytes, fileKeyB64);
      await cachedFile.writeAsBytes(decryptedBytes);
    } else {
      await cachedFile.writeAsBytes(bytes);
    }

    return cachedFile;
  } catch (_) {
    return null;
  }
}

// Pelacakan pesan "Sekali Lihat" yang sudah dibuka (lokal, persisten).
class ViewOnceStore {
  static const String _key = 'viewed_once_message_ids';
  static final Set<String> _memory = {};
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key) ?? [];
      _memory.addAll(stored);
    } catch (_) {}
    _loaded = true;
  }

  static Future<bool> isViewed(String id) async {
    await _ensureLoaded();
    return _memory.contains(id);
  }

  static Future<void> markViewed(String id) async {
    await _ensureLoaded();
    if (_memory.contains(id)) return;
    _memory.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _memory.toList());
    } catch (_) {}
  }
}

// ─────────────────────────────────────────
// Enum for read receipt status
// ─────────────────────────────────────────
enum ReadReceiptStatus {
  pending,    // clock: not yet sent to server
  sent,       // single check: reached server
  delivered,  // double check (muted): delivered to other device
  read,       // double check (softCoral): other person opened the room
}

// ─────────────────────────────────────────
// ChatBubble widget
// ─────────────────────────────────────────
class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onDelete;
  final bool canDelete;
  final bool canEdit;
  final bool canForward;
  final Function(Message)? onReply;
  final Function(Message, String)? onEdit;
  final Function(Message)? onForward;
  final Function(Message, String)? onReact;
  // Read receipt: the other participant's last_read_at timestamp
  final DateTime? otherLastReadAt;
  // Whether to show the read (blue) receipt. Controlled by the current user's
  // own "Bukti Baca" privacy setting.
  final bool showReadReceipts;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
    this.canDelete = false,
    this.canEdit = false,
    this.canForward = false,
    this.onReply,
    this.onEdit,
    this.onForward,
    this.onReact,
    this.otherLastReadAt,
    this.showReadReceipts = true,
  });

  ReadReceiptStatus _getReceiptStatus() {
    if (!isMe) return ReadReceiptStatus.pending;
    // Jika pengguna mematikan bukti baca, jangan perlihatkan status "dibaca".
    if (!showReadReceipts) return ReadReceiptStatus.delivered;
    if (otherLastReadAt == null) return ReadReceiptStatus.delivered;
    if (message.createdAt.isBefore(otherLastReadAt!) ||
        message.createdAt.isAtSameMomentAs(otherLastReadAt!)) {
      return ReadReceiptStatus.read;
    }
    return ReadReceiptStatus.delivered;
  }

  void _handleLocationTap() async {
    if (message.type == MessageType.location) {
      final parsed = _parseLocationContent(message.content);
      if (parsed != null) {
        final url = Uri.parse(
            'https://www.openstreetmap.org/?mlat=${parsed.$1}&mlon=${parsed.$2}#map=17/${parsed.$1}/${parsed.$2}');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }
      }
    }
  }

  // Parse sisa detik dari konten live "LIVE:lat,lon:secs".
  int? _parseLiveRemaining(String content) {
    final parts = content.split(':');
    if (parts.length >= 3) return int.tryParse(parts[2]);
    return null;
  }

  // Parse konten lokasi (statis "lat,lon" atau live "LIVE:lat,lon:secs").
  (double, double)? _parseLocationContent(String content) {
    String coords = content;
    if (coords.startsWith('LIVE:')) {
      final parts = coords.substring(5).split(':');
      if (parts.isNotEmpty) coords = parts.first;
    }
    final split = coords.split(',');
    if (split.length < 2) return null;
    final lat = double.tryParse(split[0].trim());
    final lon = double.tryParse(split[1].trim());
    if (lat != null && lon != null) return (lat, lon);
    return null;
  }

  void _showContextMenu(BuildContext context) {
    HapticService.trigger(MekaarHapticIntent.warning);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MessageContextMenu(
        message: message,
        isMe: isMe,
        canDelete: canDelete,
        canEdit: canEdit,
        canForward: canForward,
        onReply: onReply,
        onEdit: onEdit,
        onForward: onForward,
        onDelete: onDelete,
        onReact: onReact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: MekaarColors.infoLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              color: MekaarColors.info,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isDeleted = message.isDeleted;
    Color? bubbleColor;
    Gradient? bubbleGradient;
    Color textColor;

    if (isMe) {
      bubbleColor = isDeleted ? MekaarColors.border : MekaarColors.yellow;
      textColor = isDeleted ? MekaarColors.textMuted : MekaarColors.textOnYellow;
    } else {
      if (isDeleted) {
        bubbleColor = MekaarColors.borderLight;
        textColor = MekaarColors.textMuted;
      } else {
        bubbleGradient = MekaarGradients.incomingBubble;
        textColor = MekaarColors.textPrimary;
      }
    }

    final receiptStatus = _getReceiptStatus();

    return AnimatedAppear(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      offsetY: 10,
      child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: !isDeleted ? () => _showContextMenu(context) : null,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                gradient: bubbleGradient,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: isMe ? null : MekaarShadows.bubble,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview
                  if (message.replyToId != null && !isDeleted) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.1)
                            : MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe
                                ? MekaarColors.softCoral
                                : MekaarColors.guardianTeal,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Text(
                        "Membalas pesan...",
                        style: TextStyle(
                            fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  // Main content
                  _buildContentWidget(context, textColor),
                  const SizedBox(height: 4),
                  // Timestamp + edited + read receipt
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.isEdited && !isDeleted) ...[
                        Text(
                          'diedit ',
                          style: TextStyle(
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                            color: isMe
                                ? MekaarColors.textOnYellow.withValues(alpha: 0.5)
                                : MekaarColors.textMuted,
                          ),
                        ),
                      ],
                      if (message.isEncrypted && !isDeleted) ...[
                        Icon(
                          Icons.lock_outline,
                          size: 10,
                          color: isMe
                              ? MekaarColors.textOnYellow.withValues(alpha: 0.6)
                              : MekaarColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe
                              ? MekaarColors.textOnYellow.withValues(alpha: 0.6)
                              : MekaarColors.textMuted,
                        ),
                      ),
                      if (message.autoDeleteAt != null && !isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.timer_outlined,
                          size: 10,
                          color: isMe
                              ? MekaarColors.textOnYellow.withValues(alpha: 0.6)
                              : MekaarColors.textMuted,
                        ),
                      ],
                      // Read receipt icon (only for sent messages)
                      if (isMe && !isDeleted) ...[
                        const SizedBox(width: 4),
                        _ReadReceiptIcon(status: receiptStatus),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Emoji reactions strip below bubble
            if (message.reactions.isNotEmpty && !isDeleted)
              _ReactionsStrip(
                reactions: message.reactions,
                isMe: isMe,
                onReact: onReact != null
                    ? (emoji) => onReact!(message, emoji)
                    : null,
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildContentWidget(BuildContext context, Color textColor) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            'Pesan telah dihapus',
            style: TextStyle(
              color: textColor,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
        );

      case MessageType.image:
        return _ImageBubble(
          message: message,
          textColor: textColor,
          onViewOnceOpened: () => ViewOnceStore.markViewed(message.id),
        );

      case MessageType.voice:
        return _VoiceBubblePlayer(message: message, isMe: isMe);

      case MessageType.location:
        final isLive = message.content.startsWith('LIVE:');
        final liveRemaining = isLive
            ? _parseLiveRemaining(message.content)
            : null;
        return InkWell(
          onTap: _handleLocationTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: isLive
                    ? MekaarColors.guardianTeal
                    : MekaarColors.sosRed,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MekaarColors.guardianTeal
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LOKASI LIVE',
                          style: TextStyle(
                            color: MekaarColors.guardianTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    Text(
                      isLive ? 'Berbagi Lokasi Live' : 'Peta Terbagikan',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                    Text(
                      isLive
                          ? (liveRemaining != null
                              ? 'Kedaluwarsa dalam ${liveRemaining}s'
                              : 'Memperbarui...')
                          : message.content,
                      style: TextStyle(color: textColor, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case MessageType.video:
        return Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                message.mediaUrl ?? '',
                height: 180,
                width: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  width: 220,
                  color: Colors.black.withValues(alpha: 0.85),
                  child: const Icon(Icons.video_library,
                      color: Colors.white24, size: 40),
                ),
              ),
            ),
            const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────
// Read Receipt Icon (uses MekaarColors — no hardcoded colors)
// ─────────────────────────────────────────
class _ReadReceiptIcon extends StatelessWidget {
  final ReadReceiptStatus status;

  const _ReadReceiptIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final baseColor = MekaarColors.textOnYellow.withValues(alpha: 0.5);
    switch (status) {
      case ReadReceiptStatus.pending:
        return Icon(Icons.access_time, size: 11, color: baseColor);
      case ReadReceiptStatus.sent:
        return Icon(Icons.check, size: 11, color: baseColor);
      case ReadReceiptStatus.delivered:
        return Icon(Icons.done_all, size: 11, color: baseColor);
      case ReadReceiptStatus.read:
        return const Icon(Icons.done_all, size: 11, color: MekaarColors.sosCoral);
    }
  }
}

// ─────────────────────────────────────────
// Reactions Strip
// ─────────────────────────────────────────
class _ReactionsStrip extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isMe;
  final Function(String emoji)? onReact;

  const _ReactionsStrip({
    required this.reactions,
    required this.isMe,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 20,
        right: isMe ? 20 : 0,
        bottom: 4,
      ),
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          return _PopReaction(
            emoji: emoji,
            count: count,
            onTap: () => onReact?.call(emoji),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Long-Press Context Menu
// ─────────────────────────────────────────
class _MessageContextMenu extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool canDelete;
  final bool canEdit;
  final bool canForward;
  final Function(Message)? onReply;
  final Function(Message, String)? onEdit;
  final Function(Message)? onForward;
  final VoidCallback? onDelete;
  final Function(Message, String)? onReact;

  const _MessageContextMenu({
    required this.message,
    required this.isMe,
    required this.canDelete,
    required this.canEdit,
    required this.canForward,
    this.onReply,
    this.onEdit,
    this.onForward,
    this.onDelete,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MekaarColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: MekaarShadows.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji Reactions Row
          if (onReact != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReact!(message, emoji);
                    },
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: MekaarColors.borderLight, height: 1),
          ],
          // Action buttons
          if (onReply != null)
            _menuItem(
              context,
              icon: Icons.reply,
              label: 'Balas',
              onTap: () {
                Navigator.pop(context);
                onReply!(message);
              },
            ),
          if (canEdit && onEdit != null)
            _menuItem(
              context,
              icon: Icons.edit_outlined,
              label: 'Edit Pesan',
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context);
              },
            ),
          if (canForward && onForward != null)
            _menuItem(
              context,
              icon: Icons.forward,
              label: 'Teruskan',
              onTap: () {
                Navigator.pop(context);
                onForward!(message);
              },
            ),
          if (canDelete && onDelete != null)
            _menuItem(
              context,
              icon: Icons.delete_outline,
              label: 'Hapus',
              color: MekaarColors.sosRed,
              onTap: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller =
        TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Pesan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                onEdit!(message, newContent);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.softCoral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = MekaarColors.textPrimary,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
    );
  }
}

// ─────────────────────────────────────────
// Voice Note Player (replaces static mock)
// ─────────────────────────────────────────
class _VoiceBubblePlayer extends StatefulWidget {
  final Message message;
  final bool isMe;

  const _VoiceBubblePlayer({required this.message, required this.isMe});

  @override
  State<_VoiceBubblePlayer> createState() => _VoiceBubblePlayerState();
}

class _VoiceBubblePlayerState extends State<_VoiceBubblePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        setState(() => _isLoading = true);
        final file = await _getOrDecryptMedia(
          messageId: widget.message.id,
          url: url,
          isEncrypted: widget.message.isEncrypted,
          fileKeyB64: widget.message.content,
        );
        if (file != null) {
          await _player.play(DeviceFileSource(file.path));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _progress {
    if (_duration.inMilliseconds == 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe ? Colors.white : MekaarColors.softCoral;
    final activeWave =
        widget.isMe ? Colors.white : MekaarColors.softCoral;
    final inactiveWave =
        widget.isMe ? Colors.white38 : MekaarColors.border;

    return GestureDetector(
      onTap: _togglePlay,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                ),
              ),
            )
          else
            Icon(
              _isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 32,
              color: iconColor,
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            height: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(15, (index) {
                final played = (index / 15) <= _progress;
                return Container(
                  width: 3,
                  height: (4 + (index % 4) * 3.0).toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: played ? activeWave : inactiveWave,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label(),
            style: TextStyle(
              color: widget.isMe ? Colors.white70 : MekaarColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    if (_isPlaying || _position > Duration.zero) {
      final m = _position.inMinutes;
      final s = _position.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return widget.message.content.isNotEmpty ? widget.message.content : '0:00';
  }
}

// ─────────────────────────────────────────
// Full-screen image viewer (photo_view)
// ─────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final ImageProvider imageProvider;

  const _FullScreenImageViewer({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PhotoView(
        imageProvider: imageProvider,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

// Bungkus image bubble agar pesan "Sekali Lihat" tersembunyi setelah dibuka.
class _ImageBubble extends StatelessWidget {
  final Message message;
  final Color textColor;
  final VoidCallback onViewOnceOpened;

  const _ImageBubble({
    required this.message,
    required this.textColor,
    required this.onViewOnceOpened,
  });

  @override
  Widget build(BuildContext context) {
    final isViewOnce = message.isViewOnce;

    if (isViewOnce) {
      return FutureBuilder<bool>(
        future: ViewOnceStore.isViewed(message.id),
        initialData: false,
        builder: (ctx, snap) {
          final alreadyViewed = snap.data ?? false;
          if (alreadyViewed) {
            return _viewOnceHidden(textColor);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  onViewOnceOpened();
                  if (ctx.mounted && message.mediaUrl != null) {
                    final file = await _getOrDecryptMedia(
                      messageId: message.id,
                      url: message.mediaUrl,
                      isEncrypted: message.isEncrypted,
                      fileKeyB64: message.content,
                    );
                    if (file != null && ctx.mounted) {
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              _FullScreenImageViewer(imageProvider: FileImage(file)),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  height: 180,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_off,
                            color: Colors.white, size: 30),
                        SizedBox(height: 6),
                        Text(
                          'Media Sekali Lihat — Ketuk untuk membuka',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (message.content.isNotEmpty && !message.isEncrypted) ...[
                const SizedBox(height: 6),
                Text(message.content,
                    style: TextStyle(color: textColor, fontSize: 14)),
              ],
            ],
          );
        },
      );
    }

    return FutureBuilder<File?>(
      future: _getOrDecryptMedia(
        messageId: message.id,
        url: message.mediaUrl,
        isEncrypted: message.isEncrypted,
        fileKeyB64: message.content,
      ),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 180,
            width: 220,
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (file == null) {
          return Container(
            height: 180,
            width: 220,
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.broken_image, color: MekaarColors.textMuted),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _FullScreenImageViewer(imageProvider: FileImage(file)),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  file,
                  height: 180,
                  width: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (message.content.isNotEmpty && !message.isEncrypted) ...[
              const SizedBox(height: 6),
              Text(message.content,
                  style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ],
        );
      },
    );
  }

  Widget _viewOnceHidden(Color textColor) {
    return Container(
      height: 180,
      width: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, color: Colors.white54, size: 30),
            SizedBox(height: 6),
            Text(
              'Media sudah dilihat',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Reaction chip with pop-in animation
// ─────────────────────────────────────────
class _PopReaction extends StatefulWidget {
  final String emoji;
  final int count;
  final VoidCallback? onTap;

  const _PopReaction({
    required this.emoji,
    required this.count,
    this.onTap,
  });

  @override
  State<_PopReaction> createState() => _PopReactionState();
}

class _PopReactionState extends State<_PopReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.4, end: 1).animate(curved),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: MekaarColors.surface2Of(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MekaarColors.borderLight),
          ),
          child: Text(
            '${widget.emoji} ${widget.count}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
