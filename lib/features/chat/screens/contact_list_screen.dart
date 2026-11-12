import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_elastic_pull_scope.dart';
import '../../../core/widgets/mekaar_header_search_button.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/nearby_friends_provider.dart';
import '../providers/private_vault_provider.dart';
import '../widgets/nearby_friends_canvas.dart';
import '../widgets/private_vault_dialogs.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _contactsScrollController;
  Timer? _vaultDebounceTimer;
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  bool _isSearchActive = false;
  double _pullProgress = 0.0;
  bool _isRefreshing = false;
  double _collapseProgress = 0.0;
  int _selectedMainTabIndex = 0;
  final List<String> _mainTabs = const ['Semua Kontak', 'Teman Sekitar'];
  int _selectedSortIndex = 0;

  bool _isGridView = false;
  static const String _gridPrefKey = 'contact_list_is_grid_view';
  bool _awaitingLocationPermissionForNearby = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _contactsScrollController = ScrollController();
    _contactsScrollController.addListener(_onContactsScroll);
    _loadViewPreference();
  }

  void _onContactsScroll() {
    if (!_contactsScrollController.hasClients) return;
    final offset = _contactsScrollController.offset;
    final progress = (offset / 120.0).clamp(0.0, 1.0);
    if ((progress - _collapseProgress).abs() > 0.02) {
      setState(() {
        _collapseProgress = progress;
      });
    }
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isGridView = prefs.getBool(_gridPrefKey) ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _setViewMode(bool isGrid) async {
    if (_isGridView == isGrid) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _isGridView = isGrid;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gridPrefKey, isGrid);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vaultDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _contactsScrollController.removeListener(_onContactsScroll);
    _contactsScrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-sync kontak secara tenang di latar belakang
      ref.read(userContactsProvider.notifier).refreshContacts(forceLoading: false);

      // Auto-sync lokasi & teman sekitar saat aplikasi dibuka kembali
      if (ref.read(nearbyFriendsProvider).isEnabled) {
        ref.read(nearbyFriendsProvider.notifier).refreshNearby();
      } else if (_awaitingLocationPermissionForNearby) {
        _awaitingLocationPermissionForNearby = false;
        _checkAndAutoResumeNearby();
      }
    }
  }

  Future<void> _checkAndAutoResumeNearby() async {
    final isGranted = await Permission.location.isGranted;
    if (isGranted && mounted) {
      final success = await ref
          .read(nearbyFriendsProvider.notifier)
          .toggleSharing(true);
      if (success && mounted) {
        MekaarSnackbar.success(
          context,
          'Izin lokasi aktif. Teman Sekitar berhasil diaktifkan!',
        );
      }
    }
  }

  Future<void> _checkVaultPasscode(String query) async {
    if (query.trim().isEmpty) return;
    final repo = ref.read(privateContactRepositoryProvider);
    final matchedSlot = await repo.checkAnySlotPasscode(query.trim());
    if (matchedSlot != null && mounted) {
      // 1. Unfocus dan tutup keyboard seketika via platform channel
      _searchFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

      // 2. Bersihkan query dan kembalikan header ke mode normal
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _isSearchActive = false;
      });

      HapticService.trigger(MekaarHapticIntent.success);
      ref.read(unlockedVaultSlotsProvider.notifier).state = {matchedSlot};
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
      final slotName = await repo.getSlotName(matchedSlot);
      if (mounted) {
        MekaarSnackbar.success(
          context,
          '$slotName Terbuka',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final isDuress = authState.isDuressActive;
    final contactsAsync = ref.watch(userContactsProvider);
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final unlockedSlots = ref.watch(unlockedVaultSlotsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final nearbyState = ref.watch(nearbyFriendsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MekaarTabHeader(
              key: const ValueKey('contact_list_tab_header'),
              title: 'Kontak',
              isSearchActive: _isSearchActive,
              isSubHeaderSearch: true,
              pullProgress: _pullProgress,
              isRefreshing: _isRefreshing,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchHint: 'Cari nama, username, atau email...',
              onSearchChanged: (val) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer =
                    Timer(const Duration(milliseconds: 180), () {
                  if (mounted && _searchQuery != val.trim()) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  }
                });
                _vaultDebounceTimer?.cancel();
                if (val.trim().length >= 4) {
                  _vaultDebounceTimer = Timer(
                    const Duration(milliseconds: 400),
                    () {
                      _checkVaultPasscode(val);
                    },
                  );
                }
              },
              onSearchClosed: () {
                _searchDebounceTimer?.cancel();
                _vaultDebounceTimer?.cancel();
                setState(() {
                  _isSearchActive = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              action: isDuress
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MekaarHeaderSearchButton(
                          isSearchActive: _isSearchActive,
                          pullProgress: _pullProgress,
                          tooltip: 'Cari Kontak',
                          onPressed: () =>
                              setState(() => _isSearchActive = true),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            _selectedMainTabIndex == 0
                                ? SolarIconsOutline.sort
                                : SolarIconsOutline.tuningSquare,
                            color: MekaarColors.primaryOf(context),
                          ),
                          tooltip: _selectedMainTabIndex == 0
                              ? 'Filter & Tampilan Kontak'
                              : 'Filter & Radar Sekitar',
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: MekaarColors.surfaceOf(context),
                          onSelected: (value) async {
                            HapticService.trigger(
                              MekaarHapticIntent.selection,
                            );
                            switch (value) {
                              case 'sort_az':
                                if (_selectedSortIndex != 0) {
                                  setState(() => _selectedSortIndex = 0);
                                }
                                break;
                              case 'sort_recent':
                                if (_selectedSortIndex != 1) {
                                  setState(() => _selectedSortIndex = 1);
                                }
                                break;
                              case 'view_list':
                                await _setViewMode(false);
                                break;
                              case 'view_grid':
                                await _setViewMode(true);
                                break;
                              case 'nearby_everyone':
                                ref
                                    .read(nearbyFriendsProvider.notifier)
                                    .setVisibilityMode('everyone');
                                break;
                              case 'nearby_contacts':
                                ref
                                    .read(nearbyFriendsProvider.notifier)
                                    .setVisibilityMode('contacts_only');
                                break;
                              case 'nearby_refresh':
                                ref
                                    .read(nearbyFriendsProvider.notifier)
                                    .refreshNearby(force: true);
                                break;
                            }
                          },
                          itemBuilder: (ctx) {
                            if (_selectedMainTabIndex == 0) {
                              return [
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'sort_az',
                                  icon: SolarIconsOutline.sortByAlphabet,
                                  label: 'A - Z (Nama)',
                                  isSelected: _selectedSortIndex == 0,
                                ),
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'sort_recent',
                                  icon: SolarIconsOutline.sortByTime,
                                  label: 'Baru Ditambahkan',
                                  isSelected: _selectedSortIndex == 1,
                                ),
                                const PopupMenuDivider(height: 1),
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'view_list',
                                  icon: SolarIconsOutline.list,
                                  label: 'Tampilan Daftar (List)',
                                  isSelected: !_isGridView,
                                ),
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'view_grid',
                                  icon: SolarIconsOutline.menuDotsSquare,
                                  label: 'Tampilan Kotak (Grid)',
                                  isSelected: _isGridView,
                                ),
                              ];
                            } else {
                              return [
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'nearby_everyone',
                                  icon: SolarIconsOutline.usersGroupRounded,
                                  label: 'Semua Orang di Sekitar',
                                  isSelected:
                                      nearbyState.visibilityMode ==
                                      'everyone',
                                ),
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'nearby_contacts',
                                  icon: SolarIconsOutline.userCheck,
                                  label: 'Hanya Kontak Saya',
                                  isSelected:
                                      nearbyState.visibilityMode !=
                                      'everyone',
                                ),
                                const PopupMenuDivider(height: 1),
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'nearby_refresh',
                                  icon: SolarIconsOutline.restart,
                                  label: 'Segarkan Radar Sekitar',
                                  isSelected: false,
                                  enabled: !nearbyState.isLoading,
                                  trailing: nearbyState.isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color:
                                                MekaarColors.guardianTeal,
                                          ),
                                        )
                                      : null,
                                ),
                              ];
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            SolarIconsOutline.qrCode,
                            color: MekaarColors.primaryOf(context),
                          ),
                          tooltip: 'Kode QR & Pindai',
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.myQr),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            // Tab Atas Utama: ['Semua Kontak', 'Teman Sekitar']
            MekaarSlidingSegmentBar(
              tabs: _mainTabs,
              selectedIndex: _selectedMainTabIndex,
              onTabSelected: (index) {
                HapticService.trigger(MekaarHapticIntent.selection);
                setState(() => _selectedMainTabIndex = index);
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: MekaarElasticPullScope(
                isSearchActive: _isSearchActive,
                onSearchActiveChanged: (val) {
                  setState(() {
                    _isSearchActive = val;
                    if (!val) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onPullProgressChanged: (p) {
                  if (_pullProgress != p) {
                    setState(() => _pullProgress = p);
                  }
                },
                onRefreshingChanged: (r) {
                  if (mounted && _isRefreshing != r) {
                    setState(() => _isRefreshing = r);
                  }
                },
                onRefresh: () async {
                  try {
                    await ref
                        .read(userContactsProvider.notifier)
                        .refreshContacts(forceLoading: false);
                  } finally {
                    if (mounted && _isRefreshing) {
                      setState(() => _isRefreshing = false);
                    }
                  }
                },
                child: _selectedMainTabIndex == 0
                    ? contactsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: MekaarStateView(
                              pose: MikaPose.neutral,
                              title: 'Memuat Kontak',
                              message: 'Sedang mengambil daftar kontak Anda...',
                            ),
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: MekaarStateView(
                              illustration: ErrorResolver.resolveIllustration(err),
                              stateIcon: ErrorResolver.resolveIllustration(err) == null
                                  ? ErrorResolver.resolveIcon(err)
                                  : null,
                              stateIconColor: ErrorResolver.resolveIconColor(err, context),
                              title: 'Gagal Memuat Kontak',
                              message: ErrorResolver.resolve(err),
                              actionLabel: 'Coba Lagi',
                              onAction: () => ref
                                  .read(userContactsProvider.notifier)
                                  .refreshContacts(forceLoading: false),
                            ),
                          ),
                        ),
                        data: (items) {
                          final allContacts = isDuress ? <ContactItem>[] : items;

                          // Filter berdasarkan vault cloaking terisolasi & pencarian
                          final filteredContacts = allContacts.where((contact) {
                            // Cloaking Private Vault: sembunyikan kontak jika slot vault kontak terkait belum dibuka
                            if (contact.isVaulted) {
                              final isSlotOpen = unlockedSlots.contains(contact.vaultSlot);
                              if (!isSlotOpen) return false;
                            } else if (hiddenContactUserIds.contains(contact.contactUserId)) {
                              if (!isVaultUnlocked) return false;
                            }

                            final name = contact.effectiveName.toLowerCase();
                            final username = contact.username.toLowerCase();
                            final email = (contact.email ?? '').toLowerCase();
                            final q = _searchQuery.toLowerCase();
                            return name.contains(q) || username.contains(q) || email.contains(q);
                          }).toList();

                          // Urutkan berdasarkan tab pill filter aktif
                          if (_selectedSortIndex == 0) {
                            // A-Z: Urutkan secara alfabetis berdasarkan nama
                            filteredContacts.sort(
                              (a, b) => a.effectiveName.toLowerCase().compareTo(
                                b.effectiveName.toLowerCase(),
                              ),
                            );
                          } else {
                            // Baru Ditambahkan: Urutkan berdasarkan waktu penambahan kontak
                            filteredContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                          }

                          return filteredContacts.isEmpty
                              ? _buildEmptyState()
                              : _buildContactsCard(
                                  filteredContacts,
                                  hiddenContactUserIds,
                                  hiddenRoomIds,
                                  isVaultUnlocked,
                                );
                        },
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 110),
                        child: NearbyFriendsCanvas(
                          collapseProgress: 0.0,
                          showInternalHeader: false,
                          onSettingsOpened: () {
                            _awaitingLocationPermissionForNearby = true;
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(ContactItem contact) async {
    final isCloaked = VaultIsolationHelper.isContactCloaked(
      ref,
      contact.contactUserId,
      knownSlot: contact.vaultSlot,
    );

    if (isCloaked) {
      final unlocked = await PrivateVaultDialogs.showUnlockPasscodeDialog(
        context,
        ref,
        contact.vaultSlot,
      );
      if (!unlocked || !mounted) return;
    }

    try {
      final roomId = await ref.read(chatRoomsProvider.notifier).getOrCreateRoom(
        contact.contactUserId,
        contact.isGuardian ? 'guardian' : 'normal',
      );
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: {
          'chatId': roomId,
          'chatName': contact.effectiveName,
          'chatAvatar': contact.effectiveName.isNotEmpty
              ? contact.effectiveName[0].toUpperCase()
              : '?',
          'chatAvatarUrl': contact.avatarUrl,
          'isGuardian': contact.isGuardian,
          'otherUserId': contact.contactUserId,
        },
      );
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal membuka obrolan: $e');
      }
    }
  }

  void _confirmDeleteContact(BuildContext context, ContactItem contact) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Kontak ${contact.effectiveName}?',
      message:
          'Kontak ini akan dihapus dari daftar kontak Anda. Seluruh riwayat obrolan bilateral dengannya juga akan dibersihkan secara otomatis.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.sosRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(context);
            final isGuest = ref.read(authProvider).isGuestActive;
            if (isGuest) {
              // Silent Vaulting di mode tamu: sembunyikan ke vault master tanpa menghapus data asli
              await ref
                  .read(hiddenContactUserIdsProvider.notifier)
                  .toggleHide(contact.contactUserId);
              await ref
                  .read(userContactsProvider.notifier)
                  .updateVaultStatus(contact.contactUserId, true, vaultSlot: 1);
              if (contact.roomId != null && contact.roomId!.isNotEmpty) {
                await ref
                    .read(hiddenRoomIdsProvider.notifier)
                    .toggleHide(contact.roomId!);
              }
              if (context.mounted) {
                MekaarSnackbar.success(
                  context,
                  'Kontak dan obrolan berhasil dihapus.',
                );
              }
              return;
            }

            await ref
                .read(userContactsProvider.notifier)
                .deleteContact(contact.contactUserId);
            if (context.mounted) {
              MekaarSnackbar.success(
                context,
                'Kontak dan obrolan berhasil dihapus.',
              );
            }
          },
          child: const Text('Hapus Kontak & Chat'),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String label,
    required bool isSelected,
    Widget? trailing,
    bool enabled = true,
  }) {
    final activeColor = MekaarColors.primaryOf(context);
    final inactiveColor = MekaarColors.textSecondaryOf(context);
    final textColor = isSelected
        ? MekaarColors.textPrimaryOf(context)
        : MekaarColors.textSecondaryOf(context);

    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? activeColor : inactiveColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: MekaarTypography.bodyMD.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null)
            trailing
          else if (isSelected)
            Icon(
              SolarIconsOutline.checkCircle,
              color: activeColor,
              size: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildContactsCard(
    List<ContactItem> contacts,
    Set<String> hiddenContactUserIds,
    Set<String> hiddenRoomIds,
    bool isVaultUnlocked,
  ) {
    return _isGridView
        ? ListView(
            controller: _contactsScrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ).copyWith(bottom: 110),
            children: [
              _buildContactsGridContent(
                contacts,
                hiddenContactUserIds,
                hiddenRoomIds,
                isVaultUnlocked,
              ),
            ],
          )
        : _buildContactsListContent(
            contacts,
            hiddenContactUserIds,
            hiddenRoomIds,
            isVaultUnlocked,
          );
  }

  Widget _buildContactsGridContent(
    List<ContactItem> contacts,
    Set<String> hiddenContactUserIds,
    Set<String> hiddenRoomIds,
    bool isVaultUnlocked,
  ) {
    final primaryColor = MekaarColors.textPrimaryOf(context);
    final mutedColor = MekaarColors.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: contacts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final name = contact.effectiveName;
          final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';
          final isGuardian = contact.isGuardian;
          final isHidden = contact.isVaulted ||
              hiddenContactUserIds.contains(contact.contactUserId) ||
              (contact.roomId != null && hiddenRoomIds.contains(contact.roomId));
          final username = contact.username;
          final email = contact.email ?? '';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openChat(contact),
              onLongPress: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                _showContactContextMenu(context, contact);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Avatar(
                          imageUrl: contact.avatarUrl,
                          initial: avatar,
                          isGuardian: isGuardian,
                          size: 52,
                        ),
                        if (isHidden && isVaultUnlocked)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: MekaarColors.accentOf(context),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MekaarColors.surfaceOf(context),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              SolarIconsOutline.lockKeyhole,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: MekaarTypography.bodyMD.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username.isNotEmpty ? '@$username' : email,
                      style: MekaarTypography.bodySM.copyWith(
                        fontSize: 11,
                        color: mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilter = _searchQuery.isNotEmpty;
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MikaIllustration(
                  type: hasFilter
                      ? MikaIllustrationType.emptySearch
                      : MikaIllustrationType.emptyContacts,
                  size: 160,
                ),
                const SizedBox(height: 20),
                Text(
                  hasFilter ? 'Kontak Tidak Ditemukan' : 'Kontak Masih Kosong',
                  style: MekaarTypography.headingMD.copyWith(
                    color: MekaarColors.textPrimaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  hasFilter
                      ? 'Tidak ada kontak yang cocok dengan kata kunci pencarian.'
                      : 'Tambahkan teman baru untuk mulai berkirim pesan aman.',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!hasFilter) ...[
                  const SizedBox(height: MekaarSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.contactQrScan);
                    },
                    icon: const Icon(SolarIconsOutline.qrCode, size: 18),
                    label: const Text('Pindai Kode QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsListContent(
    List<ContactItem> contacts,
    Set<String> hiddenContactUserIds,
    Set<String> hiddenRoomIds,
    bool isVaultUnlocked,
  ) {
    final primaryColor = MekaarColors.textPrimaryOf(context);
    final mutedColor = MekaarColors.textSecondaryOf(context);

    return ListView.separated(
      controller: _contactsScrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 110),
      itemCount: contacts.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.8,
        indent: 78,
        endIndent: 0,
        color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final name = contact.effectiveName;
        final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final isGuardian = contact.isGuardian;
        final isHidden = contact.isVaulted ||
            hiddenContactUserIds.contains(contact.contactUserId) ||
            (contact.roomId != null && hiddenRoomIds.contains(contact.roomId));
        final username = contact.username;
        final email = contact.email ?? '';

        final isGuestActive = ref.watch(authProvider).isGuestActive;
        return Dismissible(
          key: ValueKey('contact_dismiss_${contact.contactUserId}'),
          direction: isGuestActive
              ? DismissDirection.startToEnd
              : DismissDirection.horizontal,
          // 1. Gestur kanan: Hapus Kontak
          background: Container(
            color: MekaarColors.sosRed,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  SolarIconsOutline.trashBinTrash,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hapus Kontak',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 2. Gestur kiri: Sembunyikan Kontak ke Private Vault (dinonaktifkan di mode tamu)
          secondaryBackground: isGuestActive
              ? null
              : Container(
                  color: MekaarColors.guardianTeal,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isHidden ? 'Tampilkan' : 'Sembunyikan',
                        style: MekaarTypography.bodyMD.copyWith(
                          color: MekaarColors.textOnTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isHidden
                            ? SolarIconsBold.eye
                            : SolarIconsBold.shieldKeyhole,
                        color: MekaarColors.textOnTeal,
                        size: 22,
                      ),
                    ],
                  ),
                ),
          confirmDismiss: (direction) async {
            HapticService.trigger(MekaarHapticIntent.selection);
            if (direction == DismissDirection.startToEnd) {
              // Geser kanan -> Hapus Kontak
              _confirmDeleteContact(context, contact);
              return false;
            } else {
              // Geser kiri -> Sembunyikan ke Private Vault
              await PrivateVaultDialogs.toggleContactHiddenWithAuth(
                context,
                ref,
                contactUserId: contact.contactUserId,
                contactName: name,
                roomId: contact.roomId,
              );
              return false;
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openChat(contact),
              onLongPress: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                _showContactContextMenu(
                  context,
                  contact,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Avatar(
                      imageUrl: contact.avatarUrl,
                      initial: avatar,
                      isGuardian: isGuardian,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: MekaarTypography.bodyMD.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isHidden && isVaultUnlocked) ...[
                                SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.accentOf(
                                      context,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        SolarIconsOutline.lockKeyhole,
                                        size: 11,
                                        color: MekaarColors.accentOf(context),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Vault',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: MekaarColors.accentOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (isGuardian) ...[
                                SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.safeTextOf(
                                      context,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Guardian',
                                    style: MekaarTypography.caption.copyWith(
                                      color: MekaarColors.safeTextOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            username.isNotEmpty ? '@$username' : email,
                            style: MekaarTypography.bodySM.copyWith(
                              fontSize: 13.5,
                              color: mutedColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        SolarIconsOutline.infoCircle,
                        color: mutedColor,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.contactSettings,
                          arguments: {
                            'roomId': contact.roomId ?? '',
                            'chatName': name,
                            'chatAvatar': avatar,
                            'otherUserId': contact.contactUserId,
                            'isGuardian': isGuardian,
                          },
                        );
                      },
                      tooltip: 'Info Kontak',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContactContextMenu(
    BuildContext context,
    ContactItem contact,
  ) {
    final name = contact.effectiveName;
    final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isGuardian = contact.isGuardian;
    final hiddenUsers = ref.read(hiddenContactUserIdsProvider);
    final hiddenRooms = ref.read(hiddenRoomIdsProvider);
    final isHidden = contact.isVaulted ||
        hiddenUsers.contains(contact.contactUserId) ||
        (contact.roomId != null && hiddenRooms.contains(contact.roomId));

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Avatar(
                      imageUrl: contact.avatarUrl,
                      initial: avatar,
                      isGuardian: isGuardian,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: MekaarTypography.bodyMD.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  SolarIconsOutline.chatRoundDots,
                  color: AppColors.blue,
                ),
                title: const Text('Buka Obrolan'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openChat(contact);
                },
              ),
              ListTile(
                leading: Icon(
                  SolarIconsOutline.userCircle,
                  color: MekaarColors.accentTextOf(context),
                ),
                title: const Text('Info & Pengaturan Kontak'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.contactSettings,
                    arguments: {
                      'roomId': contact.roomId ?? '',
                      'chatName': name,
                      'chatAvatar': avatar,
                      'otherUserId': contact.contactUserId,
                      'isGuardian': isGuardian,
                    },
                  );
                },
              ),
              if (!ref.read(authProvider).isGuestActive)
                ListTile(
                  leading: Icon(
                    isHidden
                        ? SolarIconsOutline.eye
                        : SolarIconsOutline.shieldKeyhole,
                    color: MekaarColors.guardianTeal,
                  ),
                  title: Text(
                    isHidden
                        ? 'Keluarkan dari Private Vault'
                        : 'Sembunyikan ke Private Vault',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    PrivateVaultDialogs.toggleContactHiddenWithAuth(
                      context,
                      ref,
                      contactUserId: contact.contactUserId,
                      contactName: name,
                      roomId: contact.roomId,
                    );
                  },
                ),
              ListTile(
                leading: const Icon(
                  SolarIconsOutline.userCross,
                  color: MekaarColors.sosRed,
                ),
                title: const Text(
                  'Hapus Kontak',
                  style: TextStyle(color: MekaarColors.sosRed),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteContact(context, contact);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
