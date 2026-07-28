import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/motion.dart';
import '../constants/typography.dart';
import 'bounce_interactive.dart';

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

/// MekaarBottomNav — Floating pill bottom navigation bar dengan efek
/// frosted-glass ala Rhytmu: sliding active pill (gradient + specular
/// gloss), backdrop blur sigma 10, spring bounce scale 1.12.
///
/// Ukuran dan shape tetap Mekaar existing (height 72dp, corner pill 100,
/// width dinamis = items.length * 72). Warna aktif menggunakan
/// [MekaarColors.softCoral] sesuai brand.
class MekaarBottomNav extends StatelessWidget {
  final List<MekaarNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;
  final Color? inactiveColor;

  // Ukuran Mekaar existing (tidak diubah).
  static const double _tabDimension = 72.0;
  static const double _barHeight = _tabDimension; // 72.0
  static const double _tabWidth = _tabDimension; // 72.0

  // Sliding active pill ala Rhytmu (56×56, padding 8 dari cell 72).
  static const double _pillSize = 56.0;
  static const double _pillOffset = 8.0; // (72 - 56) / 2

  // Tipografi ala Rhytmu (lebih terbaca).
  static const double _iconSize = 20.0;
  static const double _fontSize = 12.0;

  // Outer pill radius Mekaar existing (tidak diubah).
  static const double _barCornerRadius = 100.0;

  const MekaarBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
  });

  /// Sliding active pill indicator — gradient + inner specular gloss.
  Widget _buildActivePill(BuildContext context, bool isDark, Color active) {
    final leftOffset = currentIndex * _tabWidth + _pillOffset;

    final gradientColors = isDark
        ? [
            active.withValues(alpha: 0.25), // Top highlight (convex glass)
            active.withValues(alpha: 0.12), // Mid body
            active.withValues(alpha: 0.03), // Bottom shadow
          ]
        : [
            active.withValues(alpha: 0.22), // Top highlight (warm)
            active.withValues(alpha: 0.12), // Mid body
            active.withValues(alpha: 0.04), // Bottom shadow
          ];

    final glossAlpha = isDark ? 0.35 : 0.65;

    return AnimatedPositioned(
      duration: MekaarMotion.normal,
      curve: MekaarMotion.standard,
      left: leftOffset,
      top: _pillOffset,
      bottom: _pillOffset,
      width: _pillSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Inner specular gloss — top half height 12, white fade.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: glossAlpha),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor =
        (isDark ? MekaarColors.cardDark : Colors.white).withValues(
      alpha: isDark ? 0.65 : 0.55,
    );
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final effectiveActive = activeColor ?? MekaarColors.softCoral;
    final effectiveInactive = inactiveColor ??
        (isDark ? MekaarColors.textMuted : Colors.black45);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    final totalWidth = items.length * _tabWidth;

    // Clamp currentIndex untuk safety.
    final safeIndex =
        currentIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          width: totalWidth,
          height: _barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_barCornerRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? 0.25 : 0.08,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_barCornerRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(_barCornerRadius),
                  border: Border.all(
                    color: navBorderColor,
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Sliding active pill.
                    if (items.isNotEmpty)
                      _buildActivePill(context, isDark, effectiveActive),
                    // Nav items row.
                    Row(
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isActive = safeIndex == index;
                        return Semantics(
                          button: true,
                          selected: isActive,
                          label: item.label,
                          child: BounceInteractive(
                            scaleFactor: 0.94,
                            duration: const Duration(milliseconds: 120),
                            onTap: () {
                              if (safeIndex != index) onTap(index);
                            },
                            child: SizedBox(
                              width: _tabWidth,
                              height: _barHeight,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AnimatedScale(
                                          scale: isActive ? 1.12 : 1.0,
                                          duration: animationsDisabled
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 250),
                                          curve: Curves.easeOutBack,
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
                                                  const BoxConstraints(
                                                      minWidth: 16),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    MekaarColors.softCoral,
                                                borderRadius:
                                                    BorderRadius.circular(
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
                                                style:
                                                    MekaarTypography.badge,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedDefaultTextStyle(
                                      duration: animationsDisabled
                                          ? Duration.zero
                                          : const Duration(
                                              milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w400,
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
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
