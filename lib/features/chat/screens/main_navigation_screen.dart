import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/mekaar_canvas.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'chat_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ChatListScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Bottom nav background: surface.cardDark (#232A52) per design.md
    final navBgColor = MekaarColors.cardDark;
    final navBorderColor = isDark ? MekaarColors.border.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1);

    return MekaarCanvas(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Background handled by MekaarCanvas gradient
        body: Stack(
          children: [
            // Preserve scroll and state of each page using IndexedStack
            Padding(
              padding: const EdgeInsets.only(bottom: 90), // Spacing for floating navbar
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
            
            // Floating Bottom Navigation Bar
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: navBorderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
                    _buildNavItem(1, Icons.person_outline, Icons.person, 'Profil'),
                    _buildNavItem(2, Icons.settings_outlined, Icons.settings, 'Pengaturan'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? MekaarColors.softCoral : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: MekaarColors.softCoral.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? Colors.white : MekaarColors.textMuted,
          size: 24,
        ),
      ),
    );
  }
}
