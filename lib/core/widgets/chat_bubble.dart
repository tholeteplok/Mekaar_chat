import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/message_model.dart';
import '../constants/colors.dart';

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
  });

  ReadReceiptStatus _getReceiptStatus() {
    if (!isMe) return ReadReceiptStatus.pending;
    if (otherLastReadAt == null) return ReadReceiptStatus.delivered;
    if (message.createdAt.isBefore(otherLastReadAt!) ||
        message.createdAt.isAtSameMomentAs(otherLastReadAt!)) {
      return ReadReceiptStatus.read;
    }
    return ReadReceiptStatus.delivered;
  }

  void _handleLocationTap() async {
    if (message.type == MessageType.location) {
      final coordinates = message.content.split(',');
      if (coordinates.length == 2) {
        final lat = double.tryParse(coordinates[0].trim());
        final lon = double.tryParse(coordinates[1].trim());
        if (lat != null && lon != null) {
          final url = Uri.parse(
              'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        }
      }
    }
  }

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
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
    final bubbleColor = isMe
        ? (isDeleted ? MekaarColors.border : MekaarColors.textPrimary)
        : (isDeleted ? MekaarColors.borderLight : MekaarColors.surface);
    final textColor = isMe
        ? (isDeleted ? MekaarColors.textMuted : Colors.white)
        : (isDeleted ? MekaarColors.textMuted : MekaarColors.textPrimary);

    final receiptStatus = _getReceiptStatus();

    return Align(
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
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: isMe
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                            : MekaarColors.surface2,
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
                                ? Colors.white.withValues(alpha: 0.5)
                                : MekaarColors.textMuted,
                          ),
                        ),
                      ],
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.6)
                              : MekaarColors.textMuted,
                        ),
                      ),
                      if (message.autoDeleteAt != null && !isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.timer_outlined,
                          size: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.6)
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (!message.isViewOnce && message.mediaUrl != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FullScreenImageViewer(
                        url: message.mediaUrl!,
                      ),
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: message.isViewOnce
                    ? Container(
                        height: 180,
                        width: 220,
                        color: Colors.black.withValues(alpha: 0.85),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility_off,
                                  color: Colors.white, size: 30),
                              SizedBox(height: 6),
                              Text(
                                'Media Sekali Lihat',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Image.network(
                        message.mediaUrl ?? '',
                        height: 180,
                        width: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          height: 180,
                          width: 220,
                          color: MekaarColors.surface2,
                          child: const Icon(Icons.broken_image,
                              color: MekaarColors.textMuted),
                        ),
                      ),
              ),
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message.content,
                  style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ],
        );

      case MessageType.voice:
        return _VoiceBubblePlayer(message: message, isMe: isMe);

      case MessageType.location:
        return InkWell(
          onTap: _handleLocationTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: MekaarColors.sosRed, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peta Terbagikan',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                    Text(
                      message.content,
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
    switch (status) {
      case ReadReceiptStatus.pending:
        return const Icon(Icons.access_time,
            size: 11, color: MekaarColors.textMuted);
      case ReadReceiptStatus.sent:
        return const Icon(Icons.check,
            size: 11, color: MekaarColors.textMuted);
      case ReadReceiptStatus.delivered:
        return const Icon(Icons.done_all,
            size: 11, color: MekaarColors.textMuted);
      case ReadReceiptStatus.read:
        // Uses softCoral from the design system — not hardcoded
        return const Icon(Icons.done_all,
            size: 11, color: MekaarColors.softCoral);
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
          return GestureDetector(
            onTap: () => onReact?.call(emoji),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MekaarColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MekaarColors.borderLight),
              ),
              child: Text(
                '$emoji $count',
                style: const TextStyle(fontSize: 12),
              ),
            ),
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
        color: MekaarColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
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
  bool _isPlaying = false;

  Future<void> _togglePlay() async {
    // audioplayers integration placeholder — actual play/stop
    // is handled via AudioPlayer injected at a higher level.
    // For now, toggle UI state only to avoid tight coupling here.
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
        widget.isMe ? Colors.white : MekaarColors.softCoral;
    final waveColor =
        widget.isMe ? Colors.white70 : MekaarColors.textSecondary;

    return GestureDetector(
      onTap: _togglePlay,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
                return Container(
                  width: 3,
                  height: (_isPlaying
                          ? (8 + (index % 5) * 3.0)
                          : (4 + (index % 3) * 3.0))
                      .toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: waveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.message.content.isNotEmpty ? widget.message.content : '0:00',
            style: TextStyle(
              color: widget.isMe ? Colors.white70 : MekaarColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Full-screen image viewer (photo_view)
// ─────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String url;

  const _FullScreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
