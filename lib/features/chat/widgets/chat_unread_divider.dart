import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/typography.dart';

/// Widget pembatas visual "N pesan belum dibaca" yang disisipkan di atas pesan
/// belum dibaca tertua saat pengguna membuka percakapan.
class ChatUnreadDivider extends StatelessWidget {
  final int count;
  final Color? accentColor;

  const ChatUnreadDivider({super.key, required this.count, this.accentColor});

  String get _label =>
      count <= 1 ? '1 pesan belum dibaca' : '$count pesan belum dibaca';

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? MekaarColors.accentOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = effectiveAccent.withValues(alpha: isDark ? 0.35 : 0.25);
    final pillBg = isDark
        ? MekaarColors.surface2Of(context).withValues(alpha: 0.9)
        : MekaarColors.surfaceOf(context);

    final dividerContent = Semantics(
      label: _label,
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MekaarSpacing.md),
        child: Row(
          children: [
            Expanded(child: Container(height: 1, color: lineColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MekaarSpacing.md,
                  vertical: MekaarSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  border: Border.all(
                    color: effectiveAccent.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: effectiveAccent.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _label,
                  style: MekaarTypography.labelSM.copyWith(
                    color: effectiveAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: lineColor)),
          ],
        ),
      ),
    );

    if (context.reduceMotion) {
      return dividerContent;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: context.motion(MekaarMotion.normal),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: dividerContent,
    );
  }
}
