import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../../data/models/message_model.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/e2ee_room_status_provider.dart';
import 'chat_composer.dart';

/// Sub-komponen modular untuk Floating Bottom Docking Area pada ChatScreen.
/// Mengisolasi integrasi komposer, status kesiapan E2EE kamar, pengetikan realtime lawan,
/// dan pengiriman media/lokasi/audio.
class ChatBottomArea extends ConsumerWidget {
  final String chatId;
  final bool isGroup;
  final GlobalKey<ChatComposerState> composerKey;
  final TextEditingController textController;
  final FocusNode composerFocusNode;
  final Message? replyMessage;
  final String? replySenderName;
  final Message? editingMessage;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final Future<void> Function(
    File file,
    MessageType type, {
    String? caption,
    bool? isViewOnce,
  }) onSendMedia;
  final Future<void> Function()? onSendLocation;
  final Future<void> Function(int durationMinutes)? onShareLiveLocation;
  final bool isAnnouncementOnly;
  final bool canSendInAnnouncement;
  final ValueChanged<bool>? onEmojiPanelVisibilityChanged;
  final VoidCallback onRestoreE2ee;

  const ChatBottomArea({
    super.key,
    required this.chatId,
    required this.isGroup,
    this.isAnnouncementOnly = false,
    this.canSendInAnnouncement = true,
    required this.composerKey,
    required this.textController,
    required this.composerFocusNode,
    this.replyMessage,
    this.replySenderName,
    this.editingMessage,
    required this.onSend,
    required this.onCancelReply,
    required this.onCancelEdit,
    required this.onSendMedia,
    this.onSendLocation,
    this.onShareLiveLocation,
    this.onEmojiPanelVisibilityChanged,
    required this.onRestoreE2ee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatPref = ref.watch(chatThemeProvider).valueOrNull ??
        const ChatThemePreference();
    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
      chatPref,
      context,
    );
    final e2eeStatus = ref.watch(e2eeRoomStatusProvider(chatId));
    final isComposerEnabled = isGroup || (e2eeStatus == E2eeRoomStatus.ready);
    final isOtherTyping = ref.watch(typingStateProvider(chatId));

    if (isGroup && isAnnouncementOnly && !canSendInAnnouncement) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
          border: Border.all(
            color: MekaarColors.borderOf(context).withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              SolarIconsBold.lock,
              size: 16,
              color: MekaarColors.textMutedOf(context),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Hanya admin yang dapat mengirim pesan di grup ini.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MekaarColors.textMutedOf(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ChatComposer(
      key: composerKey,
      isOtherTyping: isOtherTyping,
      e2eeStatus: isGroup ? null : e2eeStatus,
      onRetryE2ee: () => ref
          .read(e2eeRoomStatusProvider(chatId).notifier)
          .retry(isGroup: isGroup),
      onRestoreE2ee: onRestoreE2ee,
      controller: textController,
      focusNode: composerFocusNode,
      replyMessage: replyMessage,
      replySenderName: replySenderName,
      editingMessage: editingMessage,
      enabled: true,
      canSend: isComposerEnabled,
      roomThemeSpec: roomThemeSpec,
      onEmojiPanelVisibilityChanged: onEmojiPanelVisibilityChanged,
      onSend: onSend,
      onCancelReply: onCancelReply,
      onCancelEdit: onCancelEdit,
      onSendMedia: onSendMedia,
      onSendLocation: onSendLocation,
      onShareLiveLocation: onShareLiveLocation,
    );
  }
}
