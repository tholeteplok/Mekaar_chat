import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/aegis_shredder_service.dart';
import '../../../features/chat/providers/chat_provider.dart';
import '../../../features/chat/providers/private_vault_provider.dart';
import '../../../features/chat/providers/screen_protection_provider.dart';
import '../../constants/colors.dart';
import '../../constants/dimensions.dart';
import '../../constants/icons.dart';
import '../../constants/motion.dart';
import 'bubble_media_helper.dart';
import 'full_screen_image_viewer.dart';
import 'read_receipt_icon.dart';
import 'view_once_store.dart';

/// Bungkus image bubble agar pesan "Sekali Lihat" tersembunyi setelah dibuka
/// serta mendukung layout frameless, caption ala Telegram & WhatsApp,
/// dan transisi Hero mulus untuk media yang tidak dilindungi.
class ImageBubble extends ConsumerWidget {
  final Message message;
  final Color textColor;
  final bool isSticker;
  final bool isMe;
  final BorderRadius borderRadius;
  final bool isPureFrameless;
  final bool isSelected;
  final ReadReceiptStatus? receiptStatus;
  final String caption;
  final Widget? metaWidget;
  final VoidCallback onViewOnceOpened;
  final VoidCallback? onSaveToVault;

  const ImageBubble({
    super.key,
    required this.message,
    required this.textColor,
    this.isSticker = false,
    this.isMe = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.isPureFrameless = false,
    this.isSelected = false,
    this.receiptStatus,
    this.caption = '',
    this.metaWidget,
    required this.onViewOnceOpened,
    this.onSaveToVault,
  });

  void _openViewer(
    BuildContext context,
    File file, {
    File? tempFileToPurge,
    Object? heroTag,
  }) {
    if (heroTag != null) {
      Navigator.push(
        context,
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black87,
          transitionDuration: context.motion(MekaarMotion.normal),
          reverseTransitionDuration: context.motion(MekaarMotion.normal),
          pageBuilder: (_, _, _) => FullScreenImageViewer(
            imageProvider: FileImage(file),
            tempFileToPurge: tempFileToPurge,
            onSaveToVault: onSaveToVault,
            heroTag: heroTag,
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(
            imageProvider: FileImage(file),
            tempFileToPurge: tempFileToPurge,
            onSaveToVault: onSaveToVault,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isViewOnce = message.isViewOnce;

    if (isViewOnce) {
      return FutureBuilder<bool>(
        future: ViewOnceStore.isViewed(message.id),
        initialData: message.isOpened,
        builder: (ctx, snap) {
          final alreadyViewed = message.isOpened || (snap.data ?? false);
          if (alreadyViewed) {
            return _viewOnceHidden(textColor);
          }
          final payload = parseMediaPayload(message);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  onViewOnceOpened();
                  try {
                    ref
                        .read(chatActionsProvider)
                        .markViewOnceOpened(message.id);
                  } catch (_) {}

                  if (ctx.mounted && message.mediaUrl != null) {
                    final file = await getOrDecryptMedia(
                      messageId: message.id,
                      url: message.mediaUrl,
                      isEncrypted: message.isEncrypted,
                      fileKeyB64: payload.fileKeyB64,
                    );
                    if (file != null && ctx.mounted) {
                      await Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(
                            imageProvider: FileImage(file),
                            tempFileToPurge: file,
                          ),
                        ),
                      );
                      if (file.existsSync()) {
                        unawaited(
                          AegisShredderService.instance.shredFile(file.path),
                        );
                      }
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
                        Icon(
                          MekaarIcons.visibilityOff,
                          color: Colors.white,
                          size: 30,
                        ),
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
              if (payload.caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  payload.caption,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
              ],
            ],
          );
        },
      );
    }

    // Evaluasi aturan privasi dan proteksi layar untuk Hero
    final isScreenProtected =
        ref
            .watch(roomScreenProtectionProvider(message.roomId))
            .valueOrNull
            ?.effective ??
        false;
    final isCloaked = ref
        .watch(cloakedRoomIdsProvider)
        .contains(message.roomId);
    final allowHero = !isScreenProtected && !isCloaked;
    final heroTag = allowHero ? 'chat-media-${message.id}' : null;

    // 1. Cek memory cache sinkron: jika ada, render langsung tanpa FutureBuilder & tanpa kedipan!
    final cached = getDecryptedFromMemory(message.id);
    if (cached != null) {
      return _buildImageContent(context, cached, heroTag: heroTag);
    }

    // 2. Jika belum ada di memori RAM, muat via FutureBuilder sekali saja
    final payload = parseMediaPayload(message);
    return FutureBuilder<File?>(
      future: getOrDecryptMedia(
        messageId: message.id,
        url: message.mediaUrl,
        isEncrypted: message.isEncrypted,
        fileKeyB64: payload.fileKeyB64,
      ),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting &&
            file == null) {
          return SizedBox(
            height: isSticker ? 140 : 200,
            width: isSticker ? 140 : 240,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }

        if (file == null) {
          return Container(
            height: isSticker ? 120 : 180,
            width: isSticker ? 120 : 220,
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: borderRadius,
            ),
            child: Icon(
              MekaarIcons.brokenImage,
              color: MekaarColors.textMutedOf(context),
            ),
          );
        }

        return _buildImageContent(context, file, heroTag: heroTag);
      },
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    File file, {
    Object? heroTag,
  }) {
    if (isSticker) {
      Widget stickerWidget = Image.file(
        file,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
      if (heroTag != null) {
        stickerWidget = Hero(tag: heroTag, child: stickerWidget);
      }

      return GestureDetector(
        onTap: () => _openViewer(context, file, heroTag: heroTag),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 180,
            maxHeight: 180,
            minWidth: 80,
            minHeight: 80,
          ),
          child: stickerWidget,
        ),
      );
    }

    final bubbleWidth = MediaQuery.of(context).size.width * 0.76;

    Widget imageFileWidget = Image.file(
      file,
      width: bubbleWidth,
      height: 220,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    if (heroTag != null) {
      imageFileWidget = Hero(tag: heroTag, child: imageFileWidget);
    }

    if (isPureFrameless) {
      return GestureDetector(
        onTap: () => _openViewer(context, file, heroTag: heroTag),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              imageFileWidget,
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    color: MekaarColors.blue.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.35
                          : 0.22,
                    ),
                  ),
                ),
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      if (message.autoDeleteAt != null) ...[
                        const SizedBox(width: 3),
                        const Icon(
                          MekaarIcons.timerOutlined,
                          size: 9.5,
                          color: Colors.white,
                        ),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        ReadReceiptIcon(
                          status: receiptStatus ?? ReadReceiptStatus.sent,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasCaption = caption.isNotEmpty;
    return GestureDetector(
      onTap: () => _openViewer(context, file, heroTag: heroTag),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: borderRadius.topLeft,
              topRight: borderRadius.topRight,
              bottomLeft: hasCaption ? Radius.zero : borderRadius.bottomLeft,
              bottomRight: hasCaption ? Radius.zero : borderRadius.bottomRight,
            ),
            child: Stack(
              children: [
                imageFileWidget,
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      color: MekaarColors.blue.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.35
                            : 0.22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  if (metaWidget != null) ...[
                    const SizedBox(height: 2),
                    metaWidget!,
                  ],
                ],
              ),
            ),
        ],
      ),
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
            Icon(MekaarIcons.visibilityOff, color: Colors.white54, size: 30),
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
