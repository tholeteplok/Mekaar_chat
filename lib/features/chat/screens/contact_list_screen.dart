import 'dart:async';
import 'package:flutter/material.dart';
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
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
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
import '../widgets/private_vault_active_banner.dart';
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
  double _collapseProgress = 0.0;
  int _selectedMainTabIndex = 0;
  final List<String> _mainTabs = const ['Semua Kontak', 'Teman Sekitar'];
  int _selectedSortIndex = 0;
  final List<String> _sortTabs = const ['A-Z', 'Baru Ditambahkan'];

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

  Future<void> _toggleViewMode() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final next = !_isGridView;
    setState(() {
      _isGridView = next;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gridPrefKey, next);
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Auto-relock vault seketika saat aplikasi diminimize atau background
      if (ref.read(privateVaultUnlockedProvider)) {
        ref.read(privateVaultUnlockedProvider.notifier).state = false;
      }
    } else if (state == AppLifecycleState.resumed) {
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
    final isMatch = await repo.verifyPasscode(query.trim());
    if (isMatch && mounted) {
      _searchController.clear();
      setState(() {
        _searchQuery = '';
      });
      FocusScope.of(context).unfocus();
      HapticService.trigger(MekaarHapticIntent.success);
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
      MekaarSnackbar.success(
        context,
        'Koleksi Kontak & Obrolan Tersembunyi Dibuka',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final wasDuress = authState.lastUnlockWasDuress;
    final contactsAsync = ref.watch(userContactsProvider);
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final nearbyState = ref.watch(nearbyFriendsProvider);

    return contactsAsync.when(
      loading: () => const MekaarStateView(
        pose: MikaPose.neutral,
        title: 'Memuat Kontak',
        message: 'Sedang mengambil daftar kontak Anda...',
      ),
      error: (err, stack) => MekaarStateView(
        illustration: ErrorResolver.resolveIllustration(err),
        stateIcon: ErrorResolver.resolveIllustration(err) == null
            ? ErrorResolver.resolveIcon(err)
            : null,
        stateIconColor: ErrorResolver.resolveIconColor(err, context),
        title: 'Gagal Memuat Kontak',
        message: ErrorResolver.resolve(err),
        actionLabel: 'Coba Lagi',
        onAction: () => ref.read(userContactsProvider.notifier).refreshContacts(forceLoading: true),
      ),
      data: (items) {
        final allContacts = wasDuress ? <ContactItem>[] : items;

        // Filter berdasarkan vault cloaking & pencarian
        final filteredContacts = allContacts.where((contact) {
          // Cloaking Private Vault: sembunyikan kontak jika vault terkunci
          if (!isVaultUnlocked && hiddenContactUserIds.contains(contact.contactUserId)) {
            return false;
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
                  action: wasDuress
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                SolarIconsOutline.qrCode,
                                color: MekaarColors.primaryOf(context),
                              ),
                              tooltip: 'Kode QR & Pindai',
                              onPressed: () =>
                                  Navigator.pushNamed(context, AppRoutes.myQr),
                            ),
                            IconButton(
                              icon: Icon(
                                SolarIconsOutline.magnifier,
                                color: MekaarColors.primaryOf(context),
                              ),
                              tooltip: 'Cari Kontak',
                              onPressed: () =>
                                  setState(() => _isSearchActive = true),
                            ),
                          ],
                        ),
                ),
                // Banner Private Vault Aktif (jika vault sedang terbuka)
                const PrivateVaultActiveBanner(),
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
                // Baris Kontrol Luar Kartu (Identik & Simetris)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (_selectedMainTabIndex == 0) ...[
                        MekaarSlidingSegmentBar(
                          tabs: _sortTabs,
                          selectedIndex: _selectedSortIndex,
                          onTabSelected: (index) {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            setState(() => _selectedSortIndex = index);
                          },
                          height: 32,
                          width: 175,
                          margin: EdgeInsets.zero,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isGridView
                                ? SolarIconsOutline.list
                                : SolarIconsOutline.menuDotsSquare,
                            color: MekaarColors.primaryOf(context),
                            size: 20,
                          ),
                          tooltip: _isGridView
                              ? 'Tampilan Daftar'
                              : 'Tampilan Grid',
                          onPressed: _toggleViewMode,
                        ),
                      ] else ...[
                        MekaarSlidingSegmentBar(
                          tabs: const ['Semua', 'Kontak'],
                          selectedIndex:
                              nearbyState.visibilityMode == 'everyone' ? 0 : 1,
                          onTabSelected: (index) {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            ref
                                .read(nearbyFriendsProvider.notifier)
                                .setVisibilityMode(
                                  index == 0 ? 'everyone' : 'contacts_only',
                                );
                          },
                          height: 32,
                          width: 175,
                          margin: EdgeInsets.zero,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: nearbyState.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MekaarColors.guardianTeal,
                                  ),
                                )
                              : Icon(
                                  SolarIconsOutline.restart,
                                  color: MekaarColors.primaryOf(context),
                                  size: 20,
                                ),
                          tooltip: 'Sinkronisasi Teman Sekitar',
                          onPressed: nearbyState.isLoading
                              ? null
                              : () {
                                  HapticService.trigger(
                                    MekaarHapticIntent.selection,
                                  );
                                  ref
                                      .read(nearbyFriendsProvider.notifier)
                                      .refreshNearby(force: true);
                                },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _selectedMainTabIndex == 0
                      ? (filteredContacts.isEmpty
                          ? _buildEmptyState()
                          : _buildContactsCard(
                              filteredContacts,
                              hiddenContactUserIds,
                              hiddenRoomIds,
                              isVaultUnlocked,
                            ))
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChat(ContactItem contact) async {
    final hiddenUsers = ref.read(hiddenContactUserIdsProvider);
    final hiddenRooms = ref.read(hiddenRoomIdsProvider);
    final isVaultUnlocked = ref.read(privateVaultUnlockedProvider);
    final isContactVaulted = hiddenUsers.contains(contact.contactUserId) ||
        (contact.roomId != null && hiddenRooms.contains(contact.roomId));

    if (isContactVaulted && !isVaultUnlocked) {
      final unlocked =
          await PrivateVaultDialogs.showUnlockPasscodeDialog(context, ref);
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

  Widget _buildContactsCard(
    List<ContactItem> contacts,
    Set<String> hiddenContactUserIds,
    Set<String> hiddenRoomIds,
    bool isVaultUnlocked,
  ) {
    return ListView(
      controller: _contactsScrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ).copyWith(bottom: 110),
      children: [
        CustomCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          borderRadius: MekaarRadius.card,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MekaarRadius.card),
            child: _isGridView
                ? _buildContactsGridContent(
                    contacts,
                    hiddenContactUserIds,
                    hiddenRoomIds,
                    isVaultUnlocked,
                  )
                : _buildContactsListContent(
                    contacts,
                    hiddenContactUserIds,
                    hiddenRoomIds,
                    isVaultUnlocked,
                  ),
          ),
        ),
      ],
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
          final isHidden = hiddenContactUserIds.contains(contact.contactUserId) ||
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
    return Center(
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: contacts.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        indent: 72,
        endIndent: 16,
        color: MekaarColors.cardBorderOf(context).withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final name = contact.effectiveName;
        final avatar = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final isGuardian = contact.isGuardian;
        final isHidden = hiddenContactUserIds.contains(contact.contactUserId) ||
            (contact.roomId != null && hiddenRoomIds.contains(contact.roomId));
        final username = contact.username;
        final email = contact.email ?? '';

        return Dismissible(
          key: ValueKey('contact_dismiss_${contact.contactUserId}'),
          direction: DismissDirection.horizontal,
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
          // 2. Gestur kiri: Sembunyikan Kontak ke Private Vault
          secondaryBackground: Container(
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
                  isHidden ? SolarIconsBold.eye : SolarIconsBold.shieldKeyhole,
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
    final isHidden = hiddenUsers.contains(contact.contactUserId) ||
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
                  isHidden ? SolarIconsOutline.eye : SolarIconsOutline.shieldKeyhole,
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
