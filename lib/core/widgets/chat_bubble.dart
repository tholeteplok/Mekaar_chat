import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/chat_theme_model.dart';
import '../../data/models/message_model.dart';
import '../../features/settings/providers/chat_theme_provider.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/icons.dart';
import '../constants/typography.dart';
import '../providers/font_provider.dart';
import '../routes/app_routes.dart';
import '../services/haptic_service.dart';
import '../theme/chat_preset_resolver.dart';
import '../utils/emoji_shortcode_parser.dart';
import 'bubbles/animated_preset_bubble_entrance.dart';
import 'bubbles/bubble_media_helper.dart';
import 'bubbles/custom_emoji_glyph.dart';
import 'bubbles/file_bubble_card.dart';
import 'bubbles/image_bubble.dart';
import 'bubbles/message_context_menu.dart';
import 'bubbles/reactions_strip.dart';
import 'bubbles/read_receipt_icon.dart';
import 'bubbles/view_once_store.dart';
import 'bubbles/voice_bubble_player.dart';
import 'mekaar_bottom_sheet.dart';

// Re-exports untuk 100% backward compatibility
export 'bubbles/animated_preset_bubble_entrance.dart';
export 'bubbles/bubble_media_helper.dart';
export 'bubbles/custom_emoji_glyph.dart';
export 'bubbles/file_bubble_card.dart';
export 'bubbles/full_screen_image_viewer.dart';
export 'bubbles/image_bubble.dart';
export 'bubbles/message_context_menu.dart';
export 'bubbles/reactions_strip.dart';
export 'bubbles/read_receipt_icon.dart';
export 'bubbles/view_once_store.dart';
export 'bubbles/voice_bubble_player.dart';

// ─────────────────────────────────────────
// ChatBubble widget
// ─────────────────────────────────────────
class ChatBubble extends ConsumerWidget {
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
  final VoidCallback? onUnsend;
  final bool canUnsend;
  // Read receipt: the other participant's last_read_at timestamp
  final DateTime? otherLastReadAt;
  // Whether to show the read (blue) receipt. Controlled by the current user's
  // own "Bukti Baca" privacy setting.
  final bool showReadReceipts;
  // Nama pengirim pada obrolan grup
  final String? senderName;
  // Pesan yang dibalas & nama pengirimnya (untuk tampilan kutipan balas)
  final Message? replyToMessage;
  final String? replyToSenderName;
  // Multi-select context properties
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onSelectionLongPress;
  final Function(Message)? onSaveToVault;

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
    this.onUnsend,
    this.canUnsend = false,
    this.onSaveToVault,
    this.otherLastReadAt,
    this.showReadReceipts = true,
    this.senderName,
    this.replyToMessage,
    this.replyToSenderName,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onSelectionTap,
    this.onSelectionLongPress,
  });

  ReadReceiptStatus _getReceiptStatus() {
    if (message.isSending) return ReadReceiptStatus.pending;
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

  void _handleLocationTap(BuildContext context) {
    if (message.type == MessageType.location) {
      final parsed = _parseLocationContent(message.content);
      if (parsed != null) {
        final isLive = message.content.startsWith('LIVE:');
        HapticService.trigger(MekaarHapticIntent.selection);
        Navigator.pushNamed(
          context,
          AppRoutes.map,
          arguments: {
            'latitude': parsed.$1,
            'longitude': parsed.$2,
            'locationName':
                isLive ? 'Lokasi Live (Real-time)' : 'Lokasi Terbagikan',
          },
        );
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
    MekaarBottomSheet.show(
      context: context,
      builder: (ctx) => MessageContextMenu(
        message: message,
        isMe: isMe,
        canDelete: canDelete,
        canEdit: canEdit,
        canForward: canForward,
        canUnsend: canUnsend,
        onReply: onReply,
        onEdit: onEdit,
        onForward: onForward,
        onDelete: onDelete,
        onUnsend: onUnsend,
        onReact: onReact,
        onSaveToVault: onSaveToVault,
      ),
    );
  }

  bool _isStickerOrGifMessage(Message msg) {
    if (msg.type != MessageType.image) return false;
    if (msg.isViewOnce) return false;
    final url = (msg.mediaUrl ?? '').toLowerCase();
    final content = msg.content.toLowerCase();
    if (url.contains('gboard_') || content.contains('gboard_')) return true;
    if ((url.endsWith('.gif') ||
            url.endsWith('.webp') ||
            url.contains('.gif?') ||
            url.contains('.webp?')) &&
        (msg.content.isEmpty ||
            msg.content == msg.mediaUrl ||
            msg.isEncrypted)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatPref =
        ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();

    if (message.type == MessageType.system) {
      return Semantics(
        label: 'Pemberitahuan sistem: ${message.content}',
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: MekaarColors.textSecondaryOf(context),
                fontSize: 11 * chatPref.textScale,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final isDeleted = message.isDeleted;
    final isSticker = !isDeleted && _isStickerOrGifMessage(message);
    final emojiCount = (message.type == MessageType.text && !isDeleted)
        ? _getEmojiOnlyCount(message.content)
        : 0;
    final singleCustom = (message.type == MessageType.text && !isDeleted)
        ? isSingleCustomEmoji(message.content)
        : false;
    final isOnlyEmoji = emojiCount > 0 || singleCustom;

    final activeFontFamily = ref.watch(fontFamilyProvider).valueOrNull ??
        MekaarTypography.fontFamily;

    // Resolusi spesifikasi visual gelembung secara tersentralisasi via ChatPresetResolver
    final spec = ChatPresetResolver.getBubbleSpec(
      chatPref,
      context,
      isMe: isMe,
      fontFamily: activeFontFamily,
    );

    // Deteksi gambar & payload caption cerdas
    final isImage = message.type == MessageType.image && !isDeleted;
    final mediaPayload = isImage
        ? parseMediaPayload(message)
        : (fileKeyB64: '', caption: '');
    final hasImageCaption = isImage && mediaPayload.caption.trim().isNotEmpty;
    final hasReply = message.replyToId != null && !isDeleted;
    final hasHeader = spec.headerWidget != null && !isDeleted;
    final hasSenderName =
        !isMe && senderName != null && senderName!.isNotEmpty && !isDeleted;
    final isPureFramelessImage = isImage &&
        !hasImageCaption &&
        !hasReply &&
        !hasHeader &&
        !hasSenderName &&
        !message.isViewOnce;

    final isFrameless = isOnlyEmoji || isSticker || isPureFramelessImage;

    Color bubbleColor = spec.backgroundColor;
    Border? border = spec.border;
    Gradient? bubbleGradient = spec.gradient;
    BorderRadius radius = spec.borderRadius;
    List<BoxShadow>? shadows = spec.boxShadow;
    Color textColor = spec.textColor;
    String? fontFamily = spec.fontFamily ?? activeFontFamily;

    if (isDeleted) {
      bubbleColor = MekaarColors.surface3Of(context);
      textColor = MekaarColors.textMutedOf(context);
      border = null;
      bubbleGradient = null;
      shadows = null;
    } else if (isFrameless) {
      bubbleColor = Colors.transparent;
      border = null;
      bubbleGradient = null;
      shadows = null;
      textColor = isMe
          ? MekaarColors.outgoingTextOf(context)
          : MekaarColors.textPrimaryOf(context);
    }

    final receiptStatus = _getReceiptStatus();
    final entranceSpec = ChatPresetResolver.getEntranceAnimation(
      chatPref.preset,
    );

    return AnimatedPresetBubbleEntrance(
      spec: entranceSpec,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: isSelectionMode ? onSelectionTap : null,
          onLongPress: !isDeleted
              ? () {
                  if (onSelectionLongPress != null) {
                    onSelectionLongPress!();
                  } else {
                    _showContextMenu(context);
                  }
                }
              : null,
          onDoubleTap: (!isDeleted && onReact != null && !isSelectionMode)
              ? () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  onReact!(message, '❤️');
                }
              : null,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                padding: isPureFramelessImage
                    ? EdgeInsets.zero
                    : (isImage && hasImageCaption
                        ? EdgeInsets.zero
                        : (isOnlyEmoji
                            ? const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              )
                            : (isSticker
                                ? const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  )
                                : const EdgeInsets.only(
                                    left: 12,
                                    right: 10,
                                    top: 7,
                                    bottom: 6,
                                  )))),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                decoration: BoxDecoration(
                  color: isPureFramelessImage
                      ? Colors.transparent
                      : (isSelected
                          ? Color.alphaBlend(
                              MekaarColors.blue.withValues(
                                alpha: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.35
                                    : 0.22,
                              ),
                              bubbleColor,
                            )
                          : bubbleColor),
                  gradient: (isPureFramelessImage || isSelected)
                      ? null
                      : bubbleGradient,
                  border: isSelected
                      ? Border.all(color: MekaarColors.blue, width: 2)
                      : (isPureFramelessImage ? null : border),
                  borderRadius: radius,
                  boxShadow: isPureFramelessImage ? null : shadows,
                ),
                child: Builder(
                  builder: (context) {
                    final metaColor = isOnlyEmoji
                        ? MekaarColors.textMutedOf(context)
                        : (isMe
                            ? textColor.withValues(alpha: 0.7)
                            : MekaarColors.textMutedOf(context));

                    Widget buildTimestampWidget() {
                      if (isSticker && !isDeleted) {
                        return Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(
                              MekaarRadius.pill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('HH:mm')
                                    .format(message.createdAt.toLocal()),
                                style: const TextStyle(
                                  fontSize: 9.5,
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
                                const SizedBox(width: 4),
                                ReadReceiptIcon(
                                  status: receiptStatus,
                                  color: Colors.white,
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (message.isEdited && !isDeleted) ...[
                            Text(
                              'diedit ',
                              style: resolveBubbleTextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: metaColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ],
                          Text(
                            DateFormat('HH:mm')
                                .format(message.createdAt.toLocal()),
                            style: resolveBubbleTextStyle(
                              fontSize: 10.5,
                              color: metaColor,
                              fontWeight: FontWeight.w400,
                              fontFamily: fontFamily,
                            ),
                          ),
                          if (message.autoDeleteAt != null && !isDeleted) ...[
                            const SizedBox(width: 3),
                            Icon(
                              MekaarIcons.timerOutlined,
                              size: 10,
                              color: metaColor,
                            ),
                          ],
                          if (isMe && !isDeleted) ...[
                            const SizedBox(width: 3),
                            ReadReceiptIcon(
                              status: receiptStatus,
                              color: metaColor,
                            ),
                          ],
                        ],
                      );
                    }

                    // Mode Inline ala WhatsApp: jika pesan teks biasa tanpa kutipan balas,
                    // teks dan waktu mengalir berdampingan dalam satu baris.
                    final isNormalText = message.type == MessageType.text &&
                        !isOnlyEmoji &&
                        !isSticker &&
                        !isDeleted &&
                        message.replyToId == null &&
                        spec.headerWidget == null &&
                        (isMe || senderName == null || senderName!.isEmpty);

                    if (isNormalText) {
                      return Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          _buildContentWidget(
                            context,
                            textColor,
                            fontFamily,
                            spec.textStyle,
                            isSticker: isSticker,
                          ),
                          buildTimestampWidget(),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spec.headerWidget != null && !isDeleted)
                          spec.headerWidget!,
                        if (!isMe &&
                            senderName != null &&
                            senderName!.isNotEmpty &&
                            !isDeleted) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              senderName!,
                              style: resolveBubbleTextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: MekaarColors.accentOf(context),
                                fontFamily: fontFamily,
                              ),
                            ),
                          ),
                        ],
                        // Reply preview
                        if (message.replyToId != null && !isDeleted)
                          _buildQuotedReplyBox(context, fontFamily),
                        // Main content
                        _buildContentWidget(
                          context,
                          textColor,
                          fontFamily,
                          spec.textStyle,
                          isSticker: isSticker,
                          borderRadius: radius,
                          isPureFrameless: isPureFramelessImage,
                          isSelected: isSelected,
                          receiptStatus: receiptStatus,
                          caption: mediaPayload.caption,
                          metaWidget: buildTimestampWidget(),
                        ),
                        if (!isPureFramelessImage && !hasImageCaption) ...[
                          const SizedBox(height: 2),
                          buildTimestampWidget(),
                        ],
                      ],
                    );
                  },
                ),
              ),
              // Emoji reactions strip below bubble
              if (message.reactions.isNotEmpty && !isDeleted)
                ReactionsStrip(
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

  Widget _buildContentWidget(
    BuildContext context,
    Color textColor,
    String? fontFamily,
    TextStyle? customTextStyle, {
    bool isSticker = false,
    BorderRadius? borderRadius,
    bool isPureFrameless = false,
    bool isSelected = false,
    ReadReceiptStatus? receiptStatus,
    String caption = '',
    Widget? metaWidget,
  }) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MekaarIcons.block, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            'Pesan telah dihapus',
            style: resolveBubbleTextStyle(
              color: textColor,
              fontStyle: FontStyle.italic,
              fontSize: 13,
              fontFamily: fontFamily,
            ),
          ),
        ],
      );
    }

    switch (message.type) {
      case MessageType.text:
        if (!message.isDeleted &&
            (message.content.startsWith('📍 Auto Check-In') ||
                message.content.startsWith('⚠️ Peringatan Keterlambatan'))) {
          final isWarning = message.content.startsWith('⚠️');
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isWarning
                  ? MekaarColors.sosCoral.withValues(alpha: 0.15)
                  : MekaarColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWarning ? MekaarColors.sosCoral : MekaarColors.success,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isWarning
                      ? MekaarIcons.warningAmberRounded
                      : MekaarIcons.verifiedUserRounded,
                  color: isWarning
                      ? MekaarColors.sosCoral
                      : MekaarColors.success,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isWarning
                            ? 'Peringatan Check-In Tertunda'
                            : 'Status Auto Check-In',
                        style: TextStyle(
                          color: isWarning
                              ? MekaarColors.sosCoral
                              : MekaarColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.content,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final count = !message.isDeleted
            ? _getEmojiOnlyCount(message.content)
            : 0;
        final singleCustom =
            !message.isDeleted && isSingleCustomEmoji(message.content);
        if (singleCustom) {
          // Satu token custom emoji murni → glyph besar ala sticker emoji-only (128px).
          return CustomEmojiGlyph(
            slug: parseEmojiContent(
              message.content,
            ).whereType<CustomEmojiSegment>().first.slug,
            size: 128,
          );
        }
        if (count > 0) {
          return Text(
            message.content,
            style: TextStyle(fontSize: _getEmojiFontSize(count), height: 1.15),
          );
        }
        if (RegExp(r':([a-z0-9_]{2,32}):').hasMatch(message.content)) {
          return RichEmojiContent(
            content: message.content,
            baseStyle: customTextStyle ??
                resolveBubbleTextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.4,
                  fontFamily: fontFamily,
                ),
          );
        }
        return Text(
          message.content,
          style: customTextStyle ??
              resolveBubbleTextStyle(
                color: textColor,
                fontSize: 16,
                height: 1.4,
                fontFamily: fontFamily,
              ),
        );

      case MessageType.file:
        return FileBubbleCard(
          message: message,
          isMe: isMe,
          textColor: textColor,
          fontFamily: fontFamily,
          onSaveToVault:
              onSaveToVault != null ? () => onSaveToVault!(message) : null,
        );

      case MessageType.image:
        return ImageBubble(
          message: message,
          textColor: textColor,
          isSticker: isSticker,
          isMe: isMe,
          borderRadius:
              borderRadius ?? const BorderRadius.all(Radius.circular(16)),
          isPureFrameless: isPureFrameless,
          isSelected: isSelected,
          receiptStatus: receiptStatus,
          caption: caption,
          metaWidget: metaWidget,
          onViewOnceOpened: () => ViewOnceStore.markViewed(message.id),
          onSaveToVault:
              onSaveToVault != null ? () => onSaveToVault!(message) : null,
        );

      case MessageType.voice:
        return VoiceBubblePlayer(
          message: message,
          isMe: isMe,
          textColor: textColor,
        );

      case MessageType.location:
        final isLive = message.content.startsWith('LIVE:');
        final liveRemaining =
            isLive ? _parseLiveRemaining(message.content) : null;
        return InkWell(
          onTap: () => _handleLocationTap(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLive
                        ? MekaarColors.guardianTeal.withValues(alpha: 0.15)
                        : MekaarColors.sosRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MekaarIcons.locationPin,
                    color: isLive
                        ? MekaarColors.guardianTeal
                        : MekaarColors.sosRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: MekaarColors.guardianTeal.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LOKASI LIVE',
                            style: TextStyle(
                              color: MekaarColors.guardianTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      Text(
                        isLive ? 'Berbagi Lokasi Live' : 'Peta Terbagikan',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            MekaarIcons.mapOutlined,
                            size: 12,
                            color: isMe
                                ? textColor.withValues(alpha: 0.8)
                                : MekaarColors.textMutedOf(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLive
                                ? (liveRemaining != null
                                    ? 'Kedaluwarsa ${liveRemaining}s • Ketuk untuk buka'
                                    : 'Ketuk untuk buka peta')
                                : 'Ketuk untuk buka peta',
                            style: TextStyle(
                              color: isMe
                                  ? textColor.withValues(alpha: 0.8)
                                  : MekaarColors.textMutedOf(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case MessageType.video:
        if (message.isViewOnce) {
          return ImageBubble(
            message: message,
            textColor: textColor,
            isMe: isMe,
            borderRadius:
                borderRadius ?? const BorderRadius.all(Radius.circular(16)),
            isPureFrameless: false,
            isSelected: isSelected,
            receiptStatus: receiptStatus,
            caption: caption,
            onViewOnceOpened: () => ViewOnceStore.markViewed(message.id),
            onSaveToVault:
                onSaveToVault != null ? () => onSaveToVault!(message) : null,
          );
        }
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
                  child: const Icon(
                    MekaarIcons.videoLibrary,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              ),
            ),
            const Icon(
              MekaarIcons.playCircleOutline,
              color: Colors.white,
              size: 48,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuotedReplyBox(BuildContext context, [String? fontFamily]) {
    String senderTitle = replyToSenderName ?? 'Pengirim';
    String previewText = 'Pesan yang dibalas';

    if (replyToMessage != null) {
      final target = replyToMessage!;
      if (target.isDeleted) {
        previewText = '🚫 Pesan telah dihapus';
      } else {
        switch (target.type) {
          case MessageType.image:
            final imagePayload = parseMediaPayload(target);
            previewText = imagePayload.caption.isNotEmpty
                ? '📷 ${imagePayload.caption}'
                : '📷 Foto';
            break;
          case MessageType.voice:
            previewText = '🎙️ Pesan Suara';
            break;
          case MessageType.location:
            previewText = '📍 Lokasi Terbagikan';
            break;
          case MessageType.system:
            if (target.content.contains('auto_checkin')) {
              previewText = '🛡️ Auto Check-In Rute';
            } else if (target.content.contains('delayed_alert')) {
              previewText = 'Peringatan Keterlambatan Kedatangan';
            } else {
              previewText = target.content;
            }
            break;
          case MessageType.video:
            previewText = '🎥 Video';
            break;
          case MessageType.file:
            final fMeta = target.fileMeta;
            final fName = fMeta?.fileName ?? 'Dokumen';
            previewText = '📄 $fName';
            break;
          case MessageType.text:
            previewText = target.content.isNotEmpty ? target.content : 'Pesan';
            break;
        }
      }
      // Token custom emoji tidak dirender sebagai gambar di preview —
      // ganti dengan placeholder agar tidak bocor token mentah.
      previewText = replaceCustomEmojiTokens(previewText, (_) => '[emoji]');
    }

    final accentColor = isMe
        ? MekaarColors.accentOf(context)
        : (Theme.of(context).brightness == Brightness.dark
            ? MekaarColors.cyan
            : MekaarColors.guardianTeal);

    final quoteBg = isMe
        ? Colors.black.withValues(alpha: 0.15)
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.05));

    final titleColor = isMe ? Colors.white : accentColor;
    final bodyColor = isMe
        ? Colors.white.withValues(alpha: 0.85)
        : MekaarColors.textSecondaryOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: quoteBg,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderTitle,
            style: resolveBubbleTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: titleColor,
              fontFamily: fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            previewText,
            style: resolveBubbleTextStyle(
              fontSize: 11,
              color: bodyColor,
              fontFamily: fontFamily,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Emoji Detection & Dynamic Scaling Helpers
// ─────────────────────────────────────────
int _getEmojiOnlyCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;

  final chars = trimmed.characters;
  if (chars.length > 4) return 0;

  final emojiRegex = RegExp(
    r'^[\u{1F300}-\u{1F9FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1F3FB}-\u{1F3FF}\u{200D}\u{FE0F}\s]+$',
    unicode: true,
  );

  if (emojiRegex.hasMatch(trimmed)) {
    return chars.length;
  }
  return 0;
}

double _getEmojiFontSize(int count) {
  switch (count) {
    case 1:
      return 52.0;
    case 2:
      return 42.0;
    case 3:
      return 34.0;
    case 4:
      return 28.0;
    default:
      return 16.0;
  }
}
