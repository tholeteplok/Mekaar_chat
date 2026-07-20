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
///
/// Ekstraksi dari [MainNavigationScreen] agar bisa dipakai ulang dan memiliki
/// dukungan badge unread.
///
/// Contoh:
/// ```dart
/// MekaarBottomNav(
///   items: const [
///     MekaarNavItem(label: 'Pesan', inactiveIcon: ..., activeIcon: ..., unreadCount: 3),
///     MekaarNavItem(label: 'Kontak', inactiveIcon: ..., activeIcon: ...),
///   ],
///   currentIndex: _index,
///   onTap: (i) => setState(() => _index = i),
/// )
/// ```
class MekaarBottomNav extends StatelessWidget {
  final List<MekaarNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;
  final Color? inactiveColor;

  static const double _iconSize = 24.0; // z
  static const double _activeSize = _iconSize + 16.0; // z + 16 = 40
  static const double _barHeight = _iconSize + 32.0; // z + 32 = 56
  static const double _tabWidth = _barHeight; // 56px per tab

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
    final navBgColor = isDark ? MekaarColors.cardDark : Colors.white;
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
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
          color: navBgColor,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: navBorderColor, width: 1.5),
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
              child: InkResponse(
                onTap: () {
                  if (currentIndex != index) onTap(index);
                },
                radius: _barHeight / 2,
                child: SizedBox(
                  width: _tabWidth,
                  height: _barHeight,
                  child: Center(
                    child: AnimatedContainer(
                      duration: animationsDisabled
                          ? Duration.zero
                          : MekaarMotion.fast,
                      curve: MekaarMotion.standard,
                      width: isActive ? _activeSize : _iconSize,
                      height: isActive ? _activeSize : _iconSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isActive ? effectiveActive : Colors.transparent,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color:
                                      effectiveActive.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Icon(
                              isActive
                                  ? item.activeIcon
                                  : item.inactiveIcon,
                              color:
                                  isActive ? Colors.white : effectiveInactive,
                              size: _iconSize,
                            ),
                          ),
                          // Unread badge
                          if (item.unreadCount != null &&
                              item.unreadCount! > 0)
                            Positioned(
                              top: -2,
                              right: -4,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minWidth: 18),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: MekaarColors.softCoral,
                                  borderRadius:
                                      BorderRadius.circular(MekaarRadius.pill),
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
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
