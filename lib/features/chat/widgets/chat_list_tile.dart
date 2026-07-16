import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';

class ChatListTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;

  const ChatListTile({super.key, required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGuardian = room['isGuardian'] as bool? ?? false;
    final timestamp = room['timestamp'] as DateTime? ?? DateTime.now();
    final unreadCount = room['unreadCount'] as int? ?? 0;
    final name = room['name'] as String? ?? 'User';

    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MekaarSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            Avatar(
              initial: room['avatar'] as String? ?? name[0],
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
                          style: MekaarTypography.headingSM
                              .copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: MekaarSpacing.sm),
                      Text(
                        DateFormat('HH:mm').format(timestamp),
                        style: MekaarTypography.bodySM,
                      ),
                    ],
                  ),
                  const SizedBox(height: MekaarSpacing.xs),
                  Row(
                    children: [
                      if (isGuardian) ...[
                        const Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: MekaarColors.guardianTeal,
                        ),
                        const SizedBox(width: MekaarSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          room['lastMessage'] as String? ??
                              'Mulai percakapan...',
                          style: MekaarTypography.labelLG.copyWith(
                            fontWeight: FontWeight.w400,
                            color: MekaarColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
        color: MekaarColors.yellow,
        borderRadius: BorderRadius.circular(MekaarRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: MekaarColors.textOnYellow,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
