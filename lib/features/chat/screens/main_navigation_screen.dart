import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/mekaar_bottom_nav.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../guardian/providers/trip_permission_provider.dart';
import 'chat_list_screen.dart';
import 'contact_list_screen.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';

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
      inactiveIcon: SolarIconsOutline.dialog,
      activeIcon: SolarIconsBold.dialog,
    ),
    MekaarNavItem(
      label: 'Kontak',
      inactiveIcon: SolarIconsOutline.usersGroupTwoRounded,
      activeIcon: SolarIconsBold.usersGroupTwoRounded,
    ),
    MekaarNavItem(
      label: 'Profil',
      inactiveIcon: SolarIconsOutline.userCircle,
      activeIcon: SolarIconsBold.userCircle,
    ),
    MekaarNavItem(
      label: 'Setelan',
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
    // (Abaikan room tersembunyi saat vault terkunci agar indikator tidak bocor)
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final chatRoomsState = ref.watch(chatRoomsProvider);
    final totalUnread = chatRoomsState.maybeWhen(
      data: (rooms) => rooms.fold<int>(
        0,
        (sum, r) {
          if (!isVaultUnlocked && hiddenRoomIds.contains(r['id'])) {
            return sum;
          }
          return sum + ((r['unreadCount'] as int?) ?? 0);
        },
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

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          if (animationsDisabled) {
            _pageController.jumpToPage(0);
          } else {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        }
      },
      child: MekaarScaffold(
        flat: true,
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _currentIndex = index);
              },
              children: _screens,
            ),
            MekaarBottomNav(
              items: items,
              currentIndex: _currentIndex,
              onTap: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
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
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Consumer(
                builder: (context, ref, _) {
                  final activeTrip = ref.watch(tripPermissionNotifierProvider);
                  if (activeTrip == null || !activeTrip.isActive) return const SizedBox.shrink();
                  final endTimeStr = '${activeTrip.endTime.hour.toString().padLeft(2, '0')}:${activeTrip.endTime.minute.toString().padLeft(2, '0')}';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: MekaarColors.guardianTeal,
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: MekaarColors.guardianTeal.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(SolarIconsOutline.mapPoint,
                            color: MekaarColors.textOnTeal, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Berbagi lokasi ke ${activeTrip.destinationName} hingga $endTimeStr',
                            style: const TextStyle(
                              color: MekaarColors.textOnTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            onTap: () async {
                              await ref
                                  .read(tripPermissionNotifierProvider.notifier)
                                  .cancelHangout();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Hentikan',
                                style: TextStyle(
                                  color: MekaarColors.sosDeep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
