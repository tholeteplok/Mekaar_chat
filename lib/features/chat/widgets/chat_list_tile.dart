import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/icons.dart';
import '../../../core/utils/message_preview_resolver.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/models/message_model.dart';
import '../../settings/providers/privacy_provider.dart';
import '../providers/chat_draft_provider.dart';

class ChatListTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMute;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final bool isHidden;

  const ChatListTile({
    super.key,
    required this.room,
    required this.onTap,
    this.onLongPress,
    this.onMarkRead,
    this.onMute,
    this.onDelete,
    this.onArchive,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final roomId = (room['id'] ?? room['room_id'] ?? '') as String;
    final isGuardian = (room['isGuardian'] ?? room['is_guardian']) as bool? ?? false;
    final isGroup = (room['isGroup'] ?? room['is_group']) as bool? ?? false;
    final rawTimestamp = room['timestamp'];
    final DateTime? timestamp = rawTimestamp is DateTime
        ? rawTimestamp
        : (rawTimestamp is String ? DateTime.tryParse(rawTimestamp) : null);
    final unreadCount = (room['unreadCount'] ?? room['unread_count']) as int? ?? 0;
    final name = (room['name'] ?? room['chat_name']) as String? ?? 'User';
    final isMuted = (room['isMuted'] ?? room['is_muted']) as bool? ?? false;
    final nameColor = MekaarColors.textPrimaryOf(context);

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              Avatar(
                initial: (room['avatar'] as String?)?.isNotEmpty == true
                    ? room['avatar'] as String
                    : (name.isNotEmpty ? name[0] : 'U'),
                imageUrl: (room['avatarUrl'] ?? room['avatar_url']) as String?,
                size: MekaarSizes.avatarLg,
                isGuardian: isGuardian,
              ),
              const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: MekaarTypography.headingSM.copyWith(
                            fontWeight: FontWeight.w800,
                            color: nameColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timestamp != null) ...[
                        SizedBox(width: MekaarSpacing.sm),
                        Text(
                          _formatTimestamp(timestamp),
                          style: MekaarTypography.bodySM.copyWith(
                            color: unreadCount > 0
                                ? MekaarColors.accentOf(context)
                                : MekaarColors.textMutedOf(context),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MekaarSpacing.xs),
                  Row(
                    children: [
                      if (isGuardian) ...[
                        const Icon(
                          MekaarIcons.shieldOutline,
                          size: 13,
                          color: MekaarColors.guardianTeal,
                        ),
                        const SizedBox(width: MekaarSpacing.xs),
                      ] else if (isGroup) ...[
                        const Icon(
                          MekaarIcons.groupsOutline,
                          size: 14,
                          color: MekaarColors.softCoral,
                        ),
                        const SizedBox(width: MekaarSpacing.xs),
                      ] else if (isMuted) ...[
                        const Icon(
                          MekaarIcons.notificationsOff,
                          size: 13,
                          color: MekaarColors.warnAmber,
                        ),
                        const SizedBox(width: MekaarSpacing.xs),
                      ],
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final isStealth =
                                ref.watch(stealthChatPreviewProvider);
                            final draft = ref.watch(chatDraftsProvider)[roomId];
                            final hasDraft = draft != null && draft.content.trim().isNotEmpty;

                            if (hasDraft) {
                              final draftText = draft.content.trim().replaceAll('\n', ' ');
                              final displayDraftSnippet = isStealth ? '••••••••' : draftText;

                              return Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Draf: ',
                                      style: TextStyle(
                                        color: MekaarColors.softCoral,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: displayDraftSnippet,
                                      style: TextStyle(
                                        color: MekaarColors.textMutedOf(context),
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: isStealth ? 2.0 : null,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MekaarTypography.labelLG.copyWith(
                                  color: MekaarColors.textMutedOf(context),
                                ),
                              );
                            }

                            final rawLast = room['lastMessage'] ?? room['last_message'];
                            final String? rawLastMsg = rawLast is Message
                                ? rawLast.content
                                : rawLast?.toString();
                            final hasMessages = timestamp != null;

                            final displayLastMsg =
                                MessagePreviewResolver.sanitizeLastMessage(
                              rawLastMsg,
                              isStealth: isStealth && hasMessages,
                            );

                            final isDots = displayLastMsg == '••••••••';

                            return Text(
                              displayLastMsg,
                              style: MekaarTypography.labelLG.copyWith(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                letterSpacing: isDots ? 2.0 : null,
                                color: unreadCount > 0
                                    ? MekaarColors.textPrimaryOf(context)
                                    : MekaarColors.textMutedOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: MekaarSpacing.sm),
                        _UnreadBadge(count: unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

    // Bungkus dengan Slidable untuk swipe actions
    return Slidable(
      key: ValueKey(roomId),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          if (onMute != null)
            SlidableAction(
              onPressed: (_) => onMute!(),
              backgroundColor: MekaarColors.warnAmber,
              foregroundColor: MekaarColors.textOnYellow,
              icon: MekaarIcons.notificationsOff,
              label: 'Bisukan',
            ),
          if (onArchive != null)
            SlidableAction(
              onPressed: (_) => onArchive!(),
              backgroundColor: MekaarColors.textMutedOf(context),
              foregroundColor: MekaarColors.textPrimaryOf(context),
              icon: MekaarIcons.archive,
              label: 'Arsip',
            ),
        ],
      ),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          if (onMarkRead != null && unreadCount > 0)
            SlidableAction(
              onPressed: (_) => onMarkRead!(),
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              icon: SolarIconsOutline.checkCircle,
              label: 'Dibaca',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete!(),
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
              icon: MekaarIcons.delete,
              label: 'Hapus',
            ),
        ],
      ),
      child: tile,
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: MekaarColors.accentOf(context),
        borderRadius: BorderRadius.circular(MekaarRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: MekaarColors.textOnBlue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime dt) {
  try {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(localDt.year, localDt.month, localDt.day);

    if (msgDate == today) return DateFormat('HH:mm').format(localDt);
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Kemarin';

    final diff = today.difference(msgDate).inDays;
    if (diff < 7) {
      const days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      return days[msgDate.weekday % 7];
    }

    if (localDt.year == now.year) {
      return DateFormat('d MMM', 'id_ID').format(localDt);
    }
    return DateFormat('d MMM yy', 'id_ID').format(localDt);
  } catch (_) {
    // Fallback defensif jika terjadi kendala format lokal
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}