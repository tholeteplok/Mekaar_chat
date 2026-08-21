import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
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

  // Tipografi ala Rhytmu (lebih terbaca).
  static const double _iconSize = 24.0;
  static const double _fontSize = 14.0;

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
    final effectiveActive = activeColor ?? Theme.of(context).colorScheme.primary;
    final effectiveInactive = inactiveColor ??
        (isDark ? MekaarColors.textMutedOf(context) : Colors.black45);
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
                    // Nav items row.
                    Row(
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isActive = safeIndex == index;
                        final unreadLabel = (item.unreadCount != null && item.unreadCount! > 0)
                            ? ', ${item.unreadCount! > 99 ? 'lebih dari 99' : item.unreadCount} belum dibaca'
                            : '';
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isActive,
                            label: '${item.label}$unreadLabel',
                            hint: 'Ketuk untuk membuka menu ${item.label}',
                            child: BounceInteractive(
                              scaleFactor: 0.94,
                              duration: const Duration(milliseconds: 120),
                              onTap: () {
                                if (safeIndex != index) onTap(index);
                              },
                              child: SizedBox(
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
                                                  color: AppColors.blue,
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
