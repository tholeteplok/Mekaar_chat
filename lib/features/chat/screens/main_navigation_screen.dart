import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/mekaar_canvas.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'chat_list_screen.dart';
import 'contact_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = const [
    ChatListScreen(),
    ContactListScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const double z = 24.0; // Icon size (z)
  static const double activeSize = z + 16.0; // Active container (z + 16 = 40)
  static const double barHeight = z + 32.0; // Height (z + 32 = 56)
  static const double barWidth = 4.0 * (z + 32.0); // Total width (4 * 56 = 224)

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-adaptive bar background and border per requirements
    final navBgColor = isDark ? MekaarColors.cardDark : Colors.white;
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return MekaarCanvas(
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Background handled by MekaarCanvas gradient
        body: Stack(
          children: [
            // PageView allows swipe transition between tabs
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              children: _screens,
            ),

            // Floating Compact Bottom Navigation Bar
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: barWidth,
                height: barHeight,
                padding: EdgeInsets.zero,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      0,
                      SolarIconsOutline.chatSquare,
                      SolarIconsBold.chatSquare,
                    ),
                    _buildNavItem(
                      1,
                      SolarIconsOutline.usersGroupRounded,
                      SolarIconsBold.usersGroupRounded,
                    ),
                    _buildNavItem(
                      2,
                      SolarIconsOutline.user,
                      SolarIconsBold.user,
                    ),
                    _buildNavItem(
                      3,
                      SolarIconsOutline.settings,
                      SolarIconsBold.settings,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon) {
    final isActive = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    const labels = ['Pesan', 'Kontak', 'Profil', 'Pengaturan'];

    final inactiveColor = isDark ? MekaarColors.textMuted : Colors.black45;

    return Semantics(
      button: true,
      selected: isActive,
      label: labels[index],
      child: InkResponse(
        onTap: () {
          if (_currentIndex != index) {
            setState(() {
              _currentIndex = index;
            });
            if (animationsDisabled) {
              _pageController.jumpToPage(index);
            } else {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          }
        },
        radius: barHeight / 2,
        child: SizedBox(
          width: z + 32.0, // Exactly 56px width per tab
          height: barHeight, // Exactly 56px height per tab
          child: Center(
            child: AnimatedContainer(
              duration: animationsDisabled
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: isActive ? activeSize : z,
              height: isActive ? activeSize : z,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? MekaarColors.softCoral : Colors.transparent,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: MekaarColors.softCoral.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  isActive ? activeIcon : inactiveIcon,
                  color: isActive ? Colors.white : inactiveColor,
                  size: z,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
