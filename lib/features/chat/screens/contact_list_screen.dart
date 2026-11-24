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
import '../../../core/widgets/mekaar_selection_header.dart';
import '../../../core/widgets/mekaar_selection_indicator.dart';
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
import '../widgets/add_contact_sheet.dart';
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
  bool _isSelectionMode = false;
  final Set<String> _selectedContactIds = <String>{};
  double _pullProgress = 0.0;
  bool _isRefreshing = false;
  double _collapseProgress = 0.0;
  int _selectedMainTabIndex = 0;
  final List<String> _mainTabs = const ['Kontak', 'Grup', 'Sekitar'];
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
    if (ref.read(authProvider).isDecoyActive) return;
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

  void _enterSelectionMode([String? initialContactId]) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _isSelectionMode = true;
      _selectedContactIds.clear();
      if (initialContactId != null && initialContactId.isNotEmpty) {
        _selectedContactIds.add(initialContactId);
      }
    });
  }

  void _exitSelectionMode() {
    if (!_isSelectionMode && _selectedContactIds.isEmpty) return;
    setState(() {
      _isSelectionMode = false;
      _selectedContactIds.clear();
    });
  }

  void _toggleContactSelection(String contactUserId) {
    if (contactUserId.isEmpty) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (_selectedContactIds.contains(contactUserId)) {
        _selectedContactIds.remove(contactUserId);
        if (_selectedContactIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedContactIds.add(contactUserId);
      }
    });
  }

  void _toggleSelectAllContacts(List<ContactItem> visibleContacts) {
    final visibleIds = visibleContacts
        .map((c) => c.contactUserId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selectedContactIds.contains);
    setState(() {
      if (allSelected) {
        _selectedContactIds.clear();
      } else {
        _selectedContactIds
          ..clear()
          ..addAll(visibleIds);
      }
    });
  }

  List<ContactItem> _computeVisibleContacts(
    List<ContactItem> items, {
    required bool isDuress,
    required Set<int> unlockedSlots,
    required Set<String> hiddenContactUserIds,
    required bool isVaultUnlocked,
  }) {
    final allContacts = isDuress ? <ContactItem>[] : items;
    final filteredContacts = allContacts.where((contact) {
      if (contact.isVaulted) {
        if (!unlockedSlots.contains(contact.vaultSlot)) return false;
      } else if (hiddenContactUserIds.contains(contact.contactUserId)) {
        if (!isVaultUnlocked) return false;
      }

      final name = contact.effectiveName.toLowerCase();
      final username = contact.username.toLowerCase();
      final email = (contact.email ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || username.contains(q) || email.contains(q);
    }).toList();

    if (_selectedSortIndex == 0) {
      filteredContacts.sort(
        (a, b) => a.effectiveName.toLowerCase().compareTo(
          b.effectiveName.toLowerCase(),
        ),
      );
    } else {
      filteredContacts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filteredContacts;
  }

  bool _isGroupRoom(Map<String, dynamic> room) =>
      room['isGroup'] == true ||
      room['roomType'] == 'group' ||
      room['room_type'] == 'group';

  List<Map<String, dynamic>> _computeVisibleGroups(
    List<Map<String, dynamic>> rooms, {
    required bool isDuress,
    required Set<int> unlockedSlots,
    required Set<String> hiddenRoomIds,
    required bool isVaultUnlocked,
  }) {
    if (isDuress) return const <Map<String, dynamic>>[];

    final isAnyVaultUnlocked = unlockedSlots.isNotEmpty || isVaultUnlocked;
    final query = _searchQuery.toLowerCase();

    final filtered = rooms.where((room) {
      if (!_isGroupRoom(room)) return false;

      final roomId = (room['id'] ?? room['room_id'] ?? '').toString();
      if (roomId.isEmpty) return false;
      if (hiddenRoomIds.contains(roomId) && !isAnyVaultUnlocked) return false;

      if (query.isNotEmpty) {
        final name = (room['name'] ?? '').toString().toLowerCase();
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();

    if (_selectedSortIndex == 0) {
      filtered.sort(
        (a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()),
      );
    } else {
      filtered.sort((a, b) {
        final aRaw = a['timestamp'];
        final bRaw = b['timestamp'];
        final aTime = aRaw is DateTime
            ? aRaw
            : DateTime.tryParse(aRaw?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = bRaw is DateTime
            ? bRaw
            : DateTime.tryParse(bRaw?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    }

    return filtered;
  }

  void _openCreateGroupFromSelection(List<ContactItem> selectedContacts) {
    if (selectedContacts.isEmpty) return;
    final ids = selectedContacts.map((c) => c.contactUserId).toList();
    final profiles = selectedContacts
        .map(
          (c) => <String, dynamic>{
            'id': c.contactUserId,
            'display_name': c.effectiveName,
            'full_name': c.effectiveName,
            'username': c.username,
            'avatar_url': c.avatarUrl,
          },
        )
        .toList();
    _exitSelectionMode();
    Navigator.pushNamed(
      context,
      AppRoutes.createGroupDetails,
      arguments: {
        'selectedUserIds': ids,
        'selectedUserProfiles': profiles,
      },
    );
  }

  void _confirmBulkVaultContacts(List<ContactItem> selectedContacts) {
    if (selectedContacts.isEmpty) return;
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Sembunyikan ${selectedContacts.length} Kontak ke Vault?',
      message:
          'Kontak terpilih akan disembunyikan ke Private Vault dan tidak tampil di daftar utama.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final hiddenNotifier = ref.read(
              hiddenContactUserIdsProvider.notifier,
            );
            final contactsNotifier = ref.read(userContactsProvider.notifier);
            for (final contact in selectedContacts) {
              await hiddenNotifier.hideContact(contact.contactUserId);
              try {
                await contactsNotifier.updateVaultStatus(
                  contact.contactUserId,
                  true,
                  vaultSlot: 1,
                );
              } catch (_) {}
            }
            if (!mounted) return;
            _exitSelectionMode();
            MekaarSnackbar.success(
              context,
              '${selectedContacts.length} kontak disembunyikan ke Private Vault.',
            );
          },
          child: const Text('Sembunyikan'),
        ),
      ],
    );
  }

  void _confirmBulkDeleteContacts(List<ContactItem> selectedContacts) {
    if (selectedContacts.isEmpty) return;
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus ${selectedContacts.length} Kontak?',
      message:
          'Kontak terpilih akan dihapus dari daftar kontak Anda beserta riwayat obrolan bilateralnya.',
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
            final count = selectedContacts.length;
            final isGuest = ref.read(authProvider).isGuestActive;
            if (isGuest) {
              for (final contact in selectedContacts) {
                await VaultIsolationHelper.silentVaultTarget(
                  ref,
                  roomId: contact.roomId,
                  contactUserId: contact.contactUserId,
                );
              }
              if (!mounted) return;
              _exitSelectionMode();
              MekaarSnackbar.success(context, '$count kontak berhasil dihapus.');
              return;
            }

            final notifier = ref.read(userContactsProvider.notifier);
            for (final contact in selectedContacts) {
              await notifier.deleteContact(contact.contactUserId);
            }
            if (!mounted) return;
            _exitSelectionMode();
            MekaarSnackbar.success(context, '$count kontak berhasil dihapus.');
          },
          child: const Text('Hapus Kontak & Chat'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final isDuress = authState.isDuressActive;
    final contactsAsync = ref.watch(userContactsProvider);
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final unlockedSlots = ref.watch(unlockedVaultSlotsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final nearbyState = ref.watch(nearbyFriendsProvider);

    final visibleContacts = contactsAsync.maybeWhen(
      data: (items) => _computeVisibleContacts(
        items,
        isDuress: isDuress,
        unlockedSlots: unlockedSlots,
        hiddenContactUserIds: hiddenContactUserIds,
        isVaultUnlocked: isVaultUnlocked,
      ),
      orElse: () => const <ContactItem>[],
    );
    final visibleGroups = chatRoomsAsync.maybeWhen(
      data: (rooms) => _computeVisibleGroups(
        rooms,
        isDuress: isDuress,
        unlockedSlots: unlockedSlots,
        hiddenRoomIds: hiddenRoomIds,
        isVaultUnlocked: isVaultUnlocked,
      ),
      orElse: () => const <Map<String, dynamic>>[],
    );
    final selectedContacts = _isSelectionMode
        ? visibleContacts
            .where((c) => _selectedContactIds.contains(c.contactUserId))
            .toList()
        : const <ContactItem>[];
    final allContactsSelected = _isSelectionMode &&
        visibleContacts.isNotEmpty &&
        visibleContacts.every(
          (c) => _selectedContactIds.contains(c.contactUserId),
        );

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSelectionMode && _selectedMainTabIndex == 0)
              MekaarSelectionHeader(
                key: const ValueKey('contact_list_selection_header'),
                selectedCount: _selectedContactIds.length,
                allSelected: allContactsSelected,
                onClose: _exitSelectionMode,
                onToggleSelectAll: () =>
                    _toggleSelectAllContacts(visibleContacts),
                actions: [
                  MekaarSelectionAction(
                    key: const ValueKey('contact_bulk_delete_btn'),
                    icon: SolarIconsOutline.userCross,
                    label: 'Hapus Kontak',
                    tooltip: 'Hapus Kontak',
                    isDestructive: true,
                    onPressed: selectedContacts.isEmpty
                        ? null
                        : () => _confirmBulkDeleteContacts(selectedContacts),
                  ),
                  MekaarSelectionAction(
                    key: const ValueKey('contact_bulk_create_group_btn'),
                    icon: SolarIconsOutline.usersGroupTwoRounded,
                    label: 'Buat Grup',
                    tooltip: 'Buat Grup dengan Kontak Terpilih',
                    onPressed: selectedContacts.isEmpty
                        ? null
                        : () => _openCreateGroupFromSelection(selectedContacts),
                  ),
                  if (!authState.isDecoyActive)
                    MekaarSelectionAction(
                      key: const ValueKey('contact_bulk_vault_btn'),
                      icon: SolarIconsOutline.shieldKeyhole,
                      label: 'Sembunyikan ke Vault',
                      tooltip: 'Sembunyikan ke Private Vault',
                      onPressed: selectedContacts.isEmpty
                          ? null
                          : () => _confirmBulkVaultContacts(selectedContacts),
                    ),
                ],
              )
            else
              MekaarTabHeader(
              key: const ValueKey('contact_list_tab_header'),
              title: 'Kontak',
              isSearchActive: _isSearchActive,
              isSubHeaderSearch: true,
              pullProgress: _pullProgress,
              isRefreshing: _isRefreshing,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchHint: _selectedMainTabIndex == 1
                  ? 'Cari nama grup...'
                  : (_selectedMainTabIndex == 2
                      ? 'Cari teman di sekitar...'
                      : 'Cari nama, username, atau email...'),
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
                            _selectedMainTabIndex == 2
                                ? SolarIconsOutline.tuningSquare
                                : SolarIconsOutline.sort,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                          tooltip: _selectedMainTabIndex == 0
                              ? 'Filter & Tampilan Kontak'
                              : (_selectedMainTabIndex == 1
                                  ? 'Filter & Tampilan Grup'
                                  : 'Filter & Radar Sekitar'),
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
                              case 'select_mode':
                                _enterSelectionMode();
                                break;
                            }
                          },
                          itemBuilder: (ctx) {
                            if (_selectedMainTabIndex == 0) {
                              return [
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'select_mode',
                                  icon: SolarIconsOutline.checkSquare,
                                  label: 'Pilih Beberapa',
                                  isSelected: false,
                                ),
                                const PopupMenuDivider(height: 1),
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
                            } else if (_selectedMainTabIndex == 1) {
                              return [
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'sort_az',
                                  icon: SolarIconsOutline.sortByAlphabet,
                                  label: 'A - Z (Nama Grup)',
                                  isSelected: _selectedSortIndex == 0,
                                ),
                                _buildFilterMenuItem(
                                  context: ctx,
                                  value: 'sort_recent',
                                  icon: SolarIconsOutline.sortByTime,
                                  label: 'Aktivitas Terbaru',
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
                          key: ValueKey(
                            _selectedMainTabIndex == 1
                                ? 'contact_header_create_group_btn'
                                : 'contact_header_add_contact_btn',
                          ),
                          icon: Icon(
                            _selectedMainTabIndex == 1
                                ? SolarIconsOutline.usersGroupTwoRounded
                                : SolarIconsOutline.userPlus,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                          tooltip: _selectedMainTabIndex == 1
                              ? 'Buat Grup Baru'
                              : 'Tambah Kontak Baru',
                          onPressed: () {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            if (_selectedMainTabIndex == 1) {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.createGroupSelectMembers,
                              );
                            } else {
                              AddContactSheet.show(context);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            SolarIconsOutline.qrCode,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                          tooltip: 'Kode QR & Pindai',
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.myQr),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            // Tab Atas Utama: ['Kontak', 'Grup', 'Sekitar']
            MekaarSlidingSegmentBar(
              tabs: _mainTabs,
              selectedIndex: _selectedMainTabIndex,
              onTabSelected: (index) {
                HapticService.trigger(MekaarHapticIntent.selection);
                if (index != 0 && _isSelectionMode) {
                  _exitSelectionMode();
                }
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
                    if (_selectedMainTabIndex == 1) {
                      await ref
                          .read(chatRoomsProvider.notifier)
                          .refreshRooms(forceLoading: false);
                    } else if (_selectedMainTabIndex == 2) {
                      await ref
                          .read(nearbyFriendsProvider.notifier)
                          .refreshNearby(force: true);
                    } else {
                      await ref
                          .read(userContactsProvider.notifier)
                          .refreshContacts(forceLoading: false);
                    }
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
                        data: (_) {
                          return visibleContacts.isEmpty
                              ? _buildEmptyState()
                              : _buildContactsCard(
                                  visibleContacts,
                                  hiddenContactUserIds,
                                  hiddenRoomIds,
                                  isVaultUnlocked,
                                );
                        },
                      )
                    : _selectedMainTabIndex == 1
                        ? _buildGroupsTabContent(
                            chatRoomsAsync,
                            visibleGroups,
                            hiddenRoomIds,
                            isVaultUnlocked,
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

  void _openGroupChat(Map<String, dynamic> group) {
    final roomId = (group['id'] ?? group['room_id'] ?? '').toString();
    if (roomId.isEmpty) return;
    final name = (group['name'] ?? 'Grup').toString();
    final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    final avatarUrl = group['avatarUrl'] as String?;

    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: {
        'chatId': roomId,
        'chatName': name,
        'chatAvatar': avatar,
        'chatAvatarUrl': avatarUrl,
        'isGuardian': false,
        'isGroup': true,
      },
    );
  }

  void _openGroupDetails(Map<String, dynamic> group) {
    final roomId = (group['id'] ?? group['room_id'] ?? '').toString();
    if (roomId.isEmpty) return;
    final name = (group['name'] ?? 'Grup').toString();
    final avatarUrl = group['avatarUrl'] as String?;

    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.pushNamed(
      context,
      AppRoutes.groupDetails,
      arguments: {
        'roomId': roomId,
        'groupName': name,
        'groupAvatarUrl': avatarUrl,
      },
    );
  }

  Widget _buildGroupsTabContent(
    AsyncValue<List<Map<String, dynamic>>> chatRoomsAsync,
    List<Map<String, dynamic>> visibleGroups,
    Set<String> hiddenRoomIds,
    bool isVaultUnlocked,
  ) {
    return chatRoomsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: MekaarStateView(
            pose: MikaPose.neutral,
            title: 'Memuat Grup',
            message: 'Sedang mengambil daftar grup Anda...',
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
            title: 'Gagal Memuat Grup',
            message: ErrorResolver.resolve(err),
            actionLabel: 'Coba Lagi',
            onAction: () => ref
                .read(chatRoomsProvider.notifier)
                .refreshRooms(forceLoading: false),
          ),
        ),
      ),
      data: (_) {
        return visibleGroups.isEmpty
            ? _buildGroupsEmptyState()
            : _buildGroupsCard(visibleGroups, hiddenRoomIds, isVaultUnlocked);
      },
    );
  }

  Widget _buildGroupsCard(
    List<Map<String, dynamic>> groups,
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
              _buildGroupsGridContent(groups, hiddenRoomIds, isVaultUnlocked),
            ],
          )
        : _buildGroupsListContent(groups, hiddenRoomIds, isVaultUnlocked);
  }

  String _formatGroupIdentitySubtitle(Map<String, dynamic> group) {
    final memberCount = group['memberCount'] as int? ?? 0;
    final encVer = group['encryptionVersion'] as int? ?? 0;
    if (memberCount > 0) {
      return encVer >= 1 ? '$memberCount Anggota • Terenkripsi' : '$memberCount Anggota';
    }
    return encVer >= 1 ? 'Grup Terenkripsi' : 'Grup';
  }

  Widget _buildGroupsGridContent(
    List<Map<String, dynamic>> groups,
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
        itemCount: groups.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          final group = groups[index];
          final roomId = (group['id'] ?? group['room_id'] ?? '').toString();
          final name = (group['name'] ?? 'Grup').toString();
          final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'G';
          final avatarUrl = group['avatarUrl'] as String?;
          final memberCount = group['memberCount'] as int? ?? 0;
          final isHidden = hiddenRoomIds.contains(roomId);

          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openGroupChat(group),
              onLongPress: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                _showGroupContextMenu(context, group);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(
                          imageUrl: avatarUrl,
                          initial: avatar,
                          isGuardian: false,
                          size: 52,
                        ),
                        if (isHidden && isVaultUnlocked)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
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
                      memberCount > 0 ? '$memberCount Anggota' : 'Grup',
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

  Widget _buildGroupsListContent(
    List<Map<String, dynamic>> groups,
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
      itemCount: groups.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.8,
        indent: 78,
        endIndent: 0,
        color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        final group = groups[index];
        final roomId = (group['id'] ?? group['room_id'] ?? '').toString();
        final name = (group['name'] ?? 'Grup').toString();
        final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'G';
        final avatarUrl = group['avatarUrl'] as String?;
        final isHidden = hiddenRoomIds.contains(roomId);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openGroupChat(group),
            onLongPress: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              _showGroupContextMenu(context, group);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Avatar(
                    imageUrl: avatarUrl,
                    initial: avatar,
                    isGuardian: false,
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
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isHidden && isVaultUnlocked) ...[
                              const SizedBox(width: 6),
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
                                    const SizedBox(width: 3),
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
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatGroupIdentitySubtitle(group),
                          style: MekaarTypography.subtitle.copyWith(
                            fontSize: 13,
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
                    onPressed: () => _openGroupDetails(group),
                    tooltip: 'Info & Anggota Grup',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsEmptyState() {
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
                  hasFilter ? 'Grup Tidak Ditemukan' : 'Belum Ada Grup',
                  style: MekaarTypography.headingMD.copyWith(
                    color: MekaarColors.textPrimaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  hasFilter
                      ? 'Tidak ada grup yang cocok dengan kata kunci pencarian.'
                      : 'Buat grup baru untuk berkomunikasi aman bersama keluarga atau tim Anda.',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!hasFilter) ...[
                  const SizedBox(height: MekaarSpacing.xl),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.createGroupSelectMembers,
                      );
                    },
                    icon: const Icon(
                      SolarIconsOutline.usersGroupTwoRounded,
                      size: 18,
                    ),
                    label: const Text('Buat Grup Baru'),
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

  void _showGroupContextMenu(
    BuildContext context,
    Map<String, dynamic> group,
  ) {
    final roomId = (group['id'] ?? group['room_id'] ?? '').toString();
    if (roomId.isEmpty) return;
    final name = (group['name'] ?? 'Grup').toString();
    final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    final avatarUrl = group['avatarUrl'] as String?;
    final memberCount = group['memberCount'] as int? ?? 0;
    final isHidden = ref.read(hiddenRoomIdsProvider).contains(roomId);

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
                      imageUrl: avatarUrl,
                      initial: avatar,
                      isGuardian: false,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: MekaarTypography.bodyMD.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (memberCount > 0)
                            Text(
                              '$memberCount Anggota',
                              style: MekaarTypography.caption.copyWith(
                                color: MekaarColors.textSecondaryOf(context),
                              ),
                            ),
                        ],
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
                title: const Text('Buka Obrolan Grup'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openGroupChat(group);
                },
              ),
              ListTile(
                leading: Icon(
                  SolarIconsOutline.usersGroupTwoRounded,
                  color: MekaarColors.accentTextOf(context),
                ),
                title: const Text('Info & Anggota Grup'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openGroupDetails(group);
                },
              ),
              if (!ref.read(authProvider).isDecoyActive)
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
                    PrivateVaultDialogs.toggleRoomHiddenWithAuth(
                      context,
                      ref,
                      roomId: roomId,
                      chatName: name,
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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

          final isSelected = _selectedContactIds.contains(contact.contactUserId);

          return Material(
            color: MekaarSelectionColors.rowHighlight(
              context,
              isSelected: _isSelectionMode && isSelected,
            ),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleContactSelection(contact.contactUserId);
                  return;
                }
                _openChat(contact);
              },
              onLongPress: () {
                if (_isSelectionMode) {
                  _toggleContactSelection(contact.contactUserId);
                  return;
                }
                HapticService.trigger(MekaarHapticIntent.selection);
                _showContactContextMenu(context, contact);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    MekaarSelectionAvatar(
                      imageUrl: contact.avatarUrl,
                      initial: avatar,
                      isGuardian: isGuardian,
                      size: 52,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      fallbackBadge: (isHidden && isVaultUnlocked)
                          ? Container(
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
                            )
                          : null,
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticService.trigger(MekaarHapticIntent.selection);
                          AddContactSheet.show(context);
                        },
                        icon: const Icon(SolarIconsOutline.userPlus, size: 18),
                        label: const Text('Tambah Kontak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.contactQrScan);
                        },
                        icon: const Icon(SolarIconsOutline.scanner, size: 18),
                        label: const Text('Pindai Kode QR'),
                      ),
                    ],
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

        final isSelected = _selectedContactIds.contains(contact.contactUserId);

        return Material(
          color: MekaarSelectionColors.rowHighlight(
            context,
            isSelected: _isSelectionMode && isSelected,
          ),
          child: InkWell(
            onTap: () {
              if (_isSelectionMode) {
                _toggleContactSelection(contact.contactUserId);
                return;
              }
              _openChat(contact);
            },
            onLongPress: () {
              if (_isSelectionMode) {
                _toggleContactSelection(contact.contactUserId);
                return;
              }
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
                    MekaarSelectionAvatar(
                      imageUrl: contact.avatarUrl,
                      initial: avatar,
                      isGuardian: isGuardian,
                      size: 48,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
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
                                    fontWeight: FontWeight.w600,
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
                            style: MekaarTypography.subtitle.copyWith(
                              fontSize: 13,
                              color: mutedColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!_isSelectionMode) ...[
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
                  ],
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
              ListTile(
                leading: Icon(
                  SolarIconsOutline.checkSquare,
                  color: MekaarColors.textPrimaryOf(context),
                ),
                title: const Text('Pilih Beberapa'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enterSelectionMode(contact.contactUserId);
                },
              ),
              if (!ref.read(authProvider).isDecoyActive)
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
