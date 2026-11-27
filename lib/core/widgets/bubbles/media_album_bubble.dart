import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../../data/models/message_model.dart';
import '../../../features/chat/providers/screen_protection_provider.dart';
import '../../../features/settings/providers/chat_theme_provider.dart';
import '../../constants/colors.dart';
import '../../constants/icons.dart';
import '../../constants/motion.dart';
import '../../theme/chat_preset_resolver.dart';
import '../avatar.dart';
import 'bubble_media_helper.dart';
import 'full_screen_image_viewer.dart';
import 'read_receipt_icon.dart';
import 'themed_bubble_container.dart';

/// Bubble album kolase tersentralisasi untuk 2–4+ pesan foto berturut-turut
/// yang memiliki `album_id` terenkripsi yang sama.
class MediaAlbumBubble extends ConsumerWidget {
  final List<Message> messages;
  final bool isMe;
  final bool isSelected;
  final bool isSelectionMode;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool showSenderAvatar;
  final VoidCallback? onSenderTap;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onSelectionLongPress;
  final bool showReadReceipts;
  final DateTime? otherLastReadAt;
  final void Function(Message msg)? onSaveToVault;

  const MediaAlbumBubble({
    super.key,
    required this.messages,
    required this.isMe,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.senderName,
    this.senderAvatarUrl,
    this.showSenderAvatar = false,
    this.onSenderTap,
    this.onSelectionTap,
    this.onSelectionLongPress,
    this.showReadReceipts = true,
    this.otherLastReadAt,
    this.onSaveToVault,
  });

  static final DateFormat _timeFormat = DateFormat('HH:mm');

  String _extractSharedCaption() {
    for (final msg in messages) {
      final caption = parseMediaPayload(msg).caption.trim();
      if (caption.isNotEmpty) return caption;
    }
    return '';
  }

  ReadReceiptStatus? _resolveReceiptStatus(Message latest) {
    if (!isMe) return null;
    if (latest.isSending) return ReadReceiptStatus.pending;
    if (otherLastReadAt != null &&
        !latest.createdAt.isAfter(otherLastReadAt!)) {
      return ReadReceiptStatus.read;
    }
    return ReadReceiptStatus.delivered;
  }

  Future<void> _openAlbumViewer(
    BuildContext context,
    int tappedIndex,
    bool allowHero,
  ) async {
    final items = <AlbumViewerItem>[];
    for (final msg in messages) {
      final payload = parseMediaPayload(msg);
      final cached = getDecryptedFromMemory(msg.id, msg.mediaUrl);
      final file = cached ??
          await getOrDecryptMedia(
            messageId: msg.id,
            url: msg.mediaUrl,
            isEncrypted: msg.isEncrypted,
            fileKeyB64: payload.fileKeyB64,
          );
      if (file == null) continue;
      items.add(
        AlbumViewerItem(
          imageProvider: FileImage(file),
          heroTag: allowHero ? 'chat-media-${msg.id}' : null,
          caption: payload.caption,
          onSaveToVault:
              onSaveToVault != null ? () => onSaveToVault!(msg) : null,
        ),
      );
    }

    if (items.isEmpty || !context.mounted) return;
    final safeIndex = tappedIndex.clamp(0, items.length - 1);

    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: context.motion(MekaarMotion.normal),
        reverseTransitionDuration: context.motion(MekaarMotion.normal),
        pageBuilder: (_, _, _) => FullScreenImageViewer.album(
          items: items,
          initialIndex: safeIndex,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (messages.isEmpty) return const SizedBox.shrink();

    final latest = messages.last;
    final chatPref =
        ref.watch(chatThemeProvider).valueOrNull ??
        const ChatThemePreference();
    final activeFontFamily = chatPref.effectiveFontFamily;
    final spec = ChatPresetResolver.getBubbleSpec(
      chatPref,
      context,
      isMe: isMe,
      fontFamily: activeFontFamily,
    );

    final isScreenProtected =
        ref
            .watch(roomScreenProtectionProvider(latest.roomId))
            .valueOrNull
            ?.effective ??
        false;
    final allowHero = !isScreenProtected;
    final sharedCaption = _extractSharedCaption();
    final receiptStatus = _resolveReceiptStatus(latest);
    final metaColor = spec.textColor.withValues(alpha: 0.72);
    final albumWidth = (MediaQuery.sizeOf(context).width * 0.72).clamp(
      210.0,
      300.0,
    );

    final bubbleBody = GestureDetector(
      onTap: isSelectionMode ? onSelectionTap : null,
      onLongPress: onSelectionLongPress,
      child: ThemedBubbleContainer(
        spec: spec,
        isMe: isMe,
        isSelected: isSelected,
        selectionColor: MekaarColors.blue.withValues(alpha: 0.25),
        customPadding: const EdgeInsets.all(6),
        constraints: BoxConstraints(maxWidth: albumWidth + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && senderName != null && senderName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                child: Text(
                  senderName!,
                  style: resolveBubbleTextStyle(
                    color: MekaarColors.primaryOf(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: activeFontFamily,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: albumWidth,
                child: _buildCollageGrid(context, albumWidth, allowHero),
              ),
            ),
            if (sharedCaption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                child: Text(
                  sharedCaption,
                  style: resolveBubbleTextStyle(
                    color: spec.textColor,
                    fontSize: 14.5,
                    height: 1.38,
                    fontFamily: activeFontFamily,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 4, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _timeFormat.format(latest.createdAt.toLocal()),
                    style: TextStyle(
                      fontSize: 11,
                      color: metaColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe && showReadReceipts && receiptStatus != null) ...[
                    const SizedBox(width: 4),
                    ReadReceiptIcon(
                      status: receiptStatus,
                      color: metaColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showSenderAvatar) ...[
            GestureDetector(
              onTap: onSenderTap,
              child: Avatar(
                initial: senderName ?? '?',
                imageUrl: senderAvatarUrl,
                size: 30,
              ),
            ),
            const SizedBox(width: 6),
          ],
          bubbleBody,
        ],
      ),
    );
  }

  Widget _buildCollageGrid(
    BuildContext context,
    double albumWidth,
    bool allowHero,
  ) {
    const gap = 2.5;
    if (messages.length == 2) {
      return SizedBox(
        height: 190,
        child: Row(
          children: [
            Expanded(
              child: _buildTile(context, 0, albumWidth / 2, allowHero),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _buildTile(context, 1, albumWidth / 2, allowHero),
            ),
          ],
        ),
      );
    }

    if (messages.length == 3) {
      return SizedBox(
        height: 230,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTile(context, 0, albumWidth * 0.6, allowHero),
            ),
            const SizedBox(width: gap),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: _buildTile(context, 1, albumWidth * 0.4, allowHero),
                  ),
                  const SizedBox(height: gap),
                  Expanded(
                    child: _buildTile(context, 2, albumWidth * 0.4, allowHero),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4+ foto: grid 2x2 dengan badge +N pada tile ke-4 jika >4
    final extraCount = messages.length - 4;
    return SizedBox(
      height: 240,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildTile(context, 0, albumWidth / 2, allowHero),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _buildTile(context, 1, albumWidth / 2, allowHero),
                ),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildTile(context, 2, albumWidth / 2, allowHero),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _buildTile(
                    context,
                    3,
                    albumWidth / 2,
                    allowHero,
                    extraCount: extraCount > 0 ? extraCount : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    int index,
    double logicalWidth,
    bool allowHero, {
    int? extraCount,
  }) {
    final msg = messages[index];
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (logicalWidth * dpr).round().clamp(180, 640);
    final cached = getDecryptedFromMemory(msg.id, msg.mediaUrl);
    final payload = cached == null ? parseMediaPayload(msg) : null;

    Widget buildImage(File file) {
      Widget img = Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
      );
      if (allowHero) {
        img = Hero(tag: 'chat-media-${msg.id}', child: img);
      }
      if (extraCount != null && extraCount > 0) {
        img = Stack(
          fit: StackFit.expand,
          children: [
            img,
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.52),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return GestureDetector(
        onTap: isSelectionMode
            ? onSelectionTap
            : () => _openAlbumViewer(context, index, allowHero),
        child: img,
      );
    }

    if (cached != null) {
      return buildImage(cached);
    }

    return FutureBuilder<File?>(
      future: getOrDecryptMedia(
        messageId: msg.id,
        url: msg.mediaUrl,
        isEncrypted: msg.isEncrypted,
        fileKeyB64: payload!.fileKeyB64,
      ),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return buildImage(file);
        }
        return Container(
          color: MekaarColors.surface2Of(context),
          child: Center(
            child: snapshot.connectionState == ConnectionState.waiting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MekaarColors.accentOf(context),
                    ),
                  )
                : Icon(
                    MekaarIcons.brokenImage,
                    color: MekaarColors.textMutedOf(context),
                  ),
          ),
        );
      },
    );
  }
}
