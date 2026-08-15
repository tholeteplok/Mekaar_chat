import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

/// MekaarSlidingSegmentBar — Bar navigasi segmen tab dengan animasi sliding pill.
///
/// Menggunakan fisika pegas (Curves.easeOutBack) untuk menggeser kapsul
/// sorotan aktif secara halus, lengkap dengan dukungan counter badge.
class MekaarSlidingSegmentBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Map<int, int>? badges;
  final Color? activeColor;
  final double height;

  const MekaarSlidingSegmentBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.badges,
    this.activeColor,
    this.height = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = activeColor ?? Theme.of(context).colorScheme.primary;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    final trackColor = isDark
        ? MekaarColors.surface2Of(context).withValues(alpha: 0.60)
        : MekaarColors.surface2Of(context).withValues(alpha: 0.85);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabCount = tabs.length;
          if (tabCount == 0) return const SizedBox.shrink();

          final tabWidth = constraints.maxWidth / tabCount;
          final safeIndex = selectedIndex.clamp(0, tabCount - 1);

          return Stack(
            children: [
              // ── Active Sliding Pill Highlight ──
              AnimatedPositioned(
                duration: animationsDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                left: safeIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tab Labels Row ──
              Row(
                children: List.generate(tabCount, (index) {
                  final isSelected = safeIndex == index;
                  final label = tabs[index];
                  final badgeCount = badges?[index] ?? 0;

                  return Expanded(
                    child: Semantics(
                      selected: isSelected,
                      button: true,
                      label: badgeCount > 0
                          ? '$label ($badgeCount baru)'
                          : label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (selectedIndex != index) {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            onTabSelected(index);
                          }
                        },
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MekaarTypography.labelLG.copyWith(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : MekaarColors.textMutedOf(context),
                                  fontSize: 13,
                                ),
                              ),
                              if (badgeCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.28)
                                        : MekaarColors.softCoral,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    badgeCount > 99 ? '99+' : '$badgeCount',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
