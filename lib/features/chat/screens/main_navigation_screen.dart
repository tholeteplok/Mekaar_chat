import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_bottom_nav.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../guardian/screens/guardian_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../guardian/providers/guardian_provider.dart';
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

  Widget _buildScreenTab(int index) {
    switch (index) {
      case 0:
        return const ChatListScreen();
      case 1:
        return const ContactListScreen();
      case 2:
        return const GuardianListScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

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
      label: 'Guardian',
      inactiveIcon: SolarIconsOutline.shieldUser,
      activeIcon: SolarIconsBold.shieldUser,
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
    // Pastikan tidak ada status ruangan aktif saat berada di tab navigasi utama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeRoomIdProvider.notifier).state = null;
      }
    });
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
    // (Abaikan room tersembunyi saat vault terkunci agar indikator tidak bocor - terisolasi per-slot)
    final cloakedRooms = ref.watch(cloakedRoomIdsProvider);
    final cloakedContacts = ref.watch(cloakedContactUserIdsProvider);
    final chatRoomsState = ref.watch(chatRoomsProvider);
    final totalUnread = chatRoomsState.maybeWhen(
      data: (rooms) => rooms.fold<int>(
        0,
        (sum, r) {
          final otherUserId = r['otherUserId'] as String?;
          if (cloakedRooms.contains(r['id']) ||
              (otherUserId != null && cloakedContacts.contains(otherUserId))) {
            return sum;
          }
          return sum + ((r['unreadCount'] as int?) ?? 0);
        },
      ),
      orElse: () => 0,
    );

    final hasPendingGuardian = ref.watch(hasPendingIncomingGuardiansProvider);

    // Salin items dan tempel unreadCount di item Pesan dan Guardian
    final items = _navItems.map((item) {
      if (item.label == 'Pesan') {
        return MekaarNavItem(
          label: item.label,
          inactiveIcon: item.inactiveIcon,
          activeIcon: item.activeIcon,
          unreadCount: totalUnread > 0 ? totalUnread : null,
        );
      }
      if (item.label == 'Guardian') {
        return MekaarNavItem(
          label: item.label,
          inactiveIcon: item.inactiveIcon,
          activeIcon: item.activeIcon,
          unreadCount: hasPendingGuardian ? 1 : null,
        );
      }
      return item;
    }).toList();

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
              duration: MekaarMotion.counter,
              curve: MekaarMotion.standard,
            );
          }
        }
      },
      child: MekaarScaffold(
        flat: true,
        extendBody: true,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: 4,
              onPageChanged: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) => _buildScreenTab(index),
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
                      duration: MekaarMotion.counter,
                      curve: MekaarMotion.standard,
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
                  final isTripActive = activeTrip != null && activeTrip.isActive;
                  final endTimeStr = isTripActive
                      ? '${activeTrip.endTime.hour.toString().padLeft(2, '0')}:${activeTrip.endTime.minute.toString().padLeft(2, '0')}'
                      : '';

                  return AnimatedSwitcher(
                    duration: MekaarMotion.counter,
                    switchInCurve: MekaarMotion.standard,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.4),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: !isTripActive
                        ? const SizedBox.shrink(key: ValueKey('trip_inactive'))
                        : Container(
                            key: const ValueKey('trip_active_banner'),
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
                            style: MekaarTypography.labelMD.copyWith(
                              color: MekaarColors.textOnTeal,
                              fontWeight: FontWeight.w700,
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
                              constraints: const BoxConstraints(
                                minHeight: 44,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(MekaarRadius.pill),
                              ),
                              child: Text(
                                'Hentikan',
                                style: MekaarTypography.labelMD.copyWith(
                                  color: MekaarColors.sosDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
