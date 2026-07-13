import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/message_model.dart';
import '../constants/colors.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onDelete;
  final bool canDelete;
  final Function(Message)? onReply;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
    this.canDelete = false,
    this.onReply,
  });

  void _handleLocationTap() async {
    if (message.type == MessageType.location) {
      final coordinates = message.content.split(',');
      if (coordinates.length == 2) {
        final lat = double.tryParse(coordinates[0].trim());
        final lon = double.tryParse(coordinates[1].trim());
        if (lat != null && lon != null) {
          final url = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        }
      }
    }
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: canDelete && !isDeleted ? onDelete : null,
        onDoubleTap: onReply != null && !isDeleted ? () => onReply!(message) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
            boxShadow: isMe ? null : [
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
              if (message.replyToId != null && !isDeleted) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withValues(alpha: 0.1) : MekaarColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? MekaarColors.softCoral : MekaarColors.guardianTeal,
                        width: 3,
                      ),
                    ),
                  ),
                  child: const Text(
                    "Membalas pesan...",
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              _buildContentWidget(context, textColor),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 9,
                      color: isMe ? Colors.white.withValues(alpha: 0.6) : MekaarColors.textMuted,
                    ),
                  ),
                  if (message.autoDeleteAt != null && !isDeleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.timer_outlined,
                      size: 10,
                      color: isMe ? Colors.white.withValues(alpha: 0.6) : MekaarColors.textMuted,
                    ),
                  ],
                ],
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
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
                            Icon(Icons.visibility_off, color: Colors.white, size: 30),
                            SizedBox(height: 6),
                            Text(
                              'Media Sekali Lihat',
                              style: TextStyle(color: Colors.white, fontSize: 11),
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
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        width: 220,
                        color: MekaarColors.surface2,
                        child: const Icon(Icons.broken_image, color: MekaarColors.textMuted),
                      ),
                    ),
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message.content, style: TextStyle(color: textColor, fontSize: 14)),
            ],
          ],
        );

      case MessageType.voice:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_filled, size: 30, color: isMe ? Colors.white : MekaarColors.softCoral),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              height: 14,
              child: Row(
                children: List.generate(15, (index) {
                  return Container(
                    width: 3,
                    height: (12 * (index % 3 + 1) / 3).toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white70 : MekaarColors.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:12', // Mock duration
              style: TextStyle(color: textColor, fontSize: 11),
            ),
          ],
        );

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
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
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
                  child: const Icon(Icons.video_library, color: Colors.white24, size: 40),
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
