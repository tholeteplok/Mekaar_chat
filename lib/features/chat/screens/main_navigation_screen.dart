import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/widgets/mekaar_bottom_nav.dart';
import '../../../core/widgets/mekaar_canvas.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'chat_list_screen.dart';
import 'contact_list_screen.dart';
import '../providers/chat_provider.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = const [
    ChatListScreen(),
    ContactListScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const List<MekaarNavItem> _navItems = [
    MekaarNavItem(
      label: 'Pesan',
      inactiveIcon: SolarIconsOutline.chatSquare,
      activeIcon: SolarIconsBold.chatSquare,
    ),
    MekaarNavItem(
      label: 'Kontak',
      inactiveIcon: SolarIconsOutline.usersGroupRounded,
      activeIcon: SolarIconsBold.usersGroupRounded,
    ),
    MekaarNavItem(
      label: 'Profil',
      inactiveIcon: SolarIconsOutline.user,
      activeIcon: SolarIconsBold.user,
    ),
    MekaarNavItem(
      label: 'Pengaturan',
      inactiveIcon: SolarIconsOutline.settings,
      activeIcon: SolarIconsBold.settings,
    ),
  ];

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
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    // Hitung total unread di semua room untuk badge ikon Pesan
    final chatRoomsState = ref.watch(chatRoomsProvider);
    final totalUnread = chatRoomsState.maybeWhen(
      data: (rooms) => rooms.fold<int>(
        0,
        (sum, r) => sum + ((r['unreadCount'] as int?) ?? 0),
      ),
      orElse: () => 0,
    );

    // Salin items dan tempel unreadCount di item Pesan
    final items = _navItems
        .map((item) => item.label == 'Pesan'
            ? MekaarNavItem(
                label: item.label,
                inactiveIcon: item.inactiveIcon,
                activeIcon: item.activeIcon,
                unreadCount: totalUnread,
              )
            : item)
        .toList();

    return MekaarCanvas(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              children: _screens,
            ),
            MekaarBottomNav(
              items: items,
              currentIndex: _currentIndex,
              onTap: (index) {
                if (_currentIndex != index) {
                  setState(() => _currentIndex = index);
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
            ),
          ],
        ),
      ),
    );
  }
}
