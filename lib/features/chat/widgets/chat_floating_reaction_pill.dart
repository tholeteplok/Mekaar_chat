import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/services/haptic_service.dart';

/// Pill popup floating reaction emoji yang muncul saat pesan dipilih
class ChatFloatingReactionPill extends StatelessWidget {
  final bool isMe;
  final ValueChanged<String> onReact;

  const ChatFloatingReactionPill({
    super.key,
    required this.isMe,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(MekaarRadius.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: MekaarColors.borderOf(context),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((emoji) {
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                onReact(emoji);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
