import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/motion.dart';
import '../constants/typography.dart';

/// Item untuk [MekaarBottomNav].
class MekaarNavItem {
  final String label;
  final IconData inactiveIcon;
  final IconData activeIcon;
  final int? unreadCount; // null = tidak tampil badge

  const MekaarNavItem({
    required this.label,
    required this.inactiveIcon,
    required this.activeIcon,
    this.unreadCount,
  });
}

/// MekaarBottomNav — Floating pill bottom navigation bar terpusat.
class MekaarBottomNav extends StatelessWidget {
  final List<MekaarNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;
  final Color? inactiveColor;

  static const double _tabDimension = 72.0; // 72.0 (lebar & tinggi simetris 1:1)
  static const double _barHeight = _tabDimension; // 72.0
  static const double _tabWidth = _tabDimension; // 72.0
  static const double _containerSize = 56.0; // 72.0 * (40.0 / 64.0)
  static const double _iconSize = 24.0;
  static const double _fontSize = 10.0;

  const MekaarBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = (isDark ? MekaarColors.cardDark : Colors.white).withValues(alpha: 0.82);
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final effectiveActive = activeColor ?? MekaarColors.softCoral;
    final effectiveInactive = inactiveColor ??
        (isDark ? MekaarColors.textMuted : Colors.black45);

    final totalWidth = items.length * _tabWidth;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        width: totalWidth,
        height: _barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.35 : 0.12,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: navBgColor,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: navBorderColor, width: 1.5),
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isActive = currentIndex == index;
                  final animationsDisabled =
                      MediaQuery.disableAnimationsOf(context);

                  return Semantics(
                    button: true,
                    selected: isActive,
                    label: item.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () {
                        if (currentIndex != index) onTap(index);
                      },
                      child: SizedBox(
                        width: _tabWidth,
                        height: _barHeight,
                        child: Center(
                          child: AnimatedContainer(
                            duration: animationsDisabled
                                ? Duration.zero
                                : MekaarMotion.fast,
                            curve: MekaarMotion.standard,
                            width: _containerSize,
                            height: _containerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? effectiveActive.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedScale(
                                      scale: isActive ? 1.08 : 1.0,
                                      duration: animationsDisabled
                                          ? Duration.zero
                                          : MekaarMotion.fast,
                                      child: Icon(
                                        isActive
                                            ? item.activeIcon
                                            : item.inactiveIcon,
                                        color: isActive
                                            ? effectiveActive
                                            : effectiveInactive,
                                        size: _iconSize,
                                      ),
                                    ),
                                    // Unread badge
                                    if (item.unreadCount != null &&
                                        item.unreadCount! > 0)
                                      Positioned(
                                        top: -4,
                                        right: -8,
                                        child: Container(
                                          constraints:
                                              const BoxConstraints(minWidth: 16),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: MekaarColors.softCoral,
                                            borderRadius: BorderRadius.circular(
                                                MekaarRadius.pill),
                                            border: Border.all(
                                              color: navBgColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            item.unreadCount! > 99
                                                ? '99+'
                                                : '${item.unreadCount}',
                                            textAlign: TextAlign.center,
                                            style: MekaarTypography.badge,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: animationsDisabled
                                      ? Duration.zero
                                      : MekaarMotion.fast,
                                  style: TextStyle(
                                    fontSize: _fontSize,
                                    fontWeight:
                                        isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive
                                        ? effectiveActive
                                        : effectiveInactive,
                                    letterSpacing: -0.2,
                                  ),
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    softWrap: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
