import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'avatar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? avatarInitial;
  final String? avatarUrl;
  final bool isGuardian;
  final bool showOnlineIndicator;
  final bool isOnline;
  final List<Widget>? actions;
  final VoidCallback? onBackPress;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarInitial,
    this.avatarUrl,
    this.isGuardian = false,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.actions,
    this.onBackPress,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: onBackPress ?? () => Navigator.pop(context),
            )
          : null,
      title: Row(
        children: [
          if (avatarInitial != null || avatarUrl != null) ...[
            const SizedBox(width: 8),
            Avatar(
              initial: avatarInitial,
              imageUrl: avatarUrl,
              size: 38,
              isGuardian: isGuardian,
            ),
            const SizedBox(width: 12),
          ] else if (Navigator.canPop(context)) ...[
            const SizedBox(width: 8),
          ] else ...[
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (showOnlineIndicator || subtitle != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showOnlineIndicator) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? MekaarColors.success : MekaarColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        subtitle ?? (isOnline ? 'Online' : 'Offline'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOnline && showOnlineIndicator
                              ? MekaarColors.success
                              : MekaarColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
