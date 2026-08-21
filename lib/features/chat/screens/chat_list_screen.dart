import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_live_safety_pill.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/mika_animated.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../../guardian/providers/guardian_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/sos_button.dart';
import '../../../core/widgets/mekaar_frosted_action_button.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';
import '../widgets/private_vault_dialogs.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../settings/providers/block_provider.dart';
import '../../../data/repositories/chat_request_repository.dart';
import '../widgets/chat_list_tile.dart';
import '../widgets/send_chat_invite_dialog.dart';
import '../../../core/widgets/mekaar_update_bottom_sheet.dart';
import '../../../core/widgets/mekaar_update_dialog.dart';
import '../../../core/widgets/mekaar_permissions_bottom_sheet.dart';
import '../../../data/services/update_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  String _searchQuery = '';
  bool _isSearchActive = false;
  late final TextEditingController _searchController;
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Semua', 'Guardian', 'Arsip'];
  String get _selectedTab => _tabs[_selectedTabIndex];

  // Cache memoization untuk filter room
  int? _lastRoomsSignature;
  List<Map<String, dynamic>>? _cachedFiltered;
  String? _lastSearchQuery;
  int? _lastTabIndex;
  Set<String>? _lastBlockedIds;
  Set<String>? _lastHiddenIds;
  bool? _lastVaultUnlocked;

  int _computeRoomsSignature(List<Map<String, dynamic>> rooms) {
    if (rooms.isEmpty) return 0;
    int hash = rooms.length;
    for (final r in rooms) {
      hash = Object.hash(
        hash,
        r['id'],
        r['name'],
        r['last_message_at'],
        r['unread_count'],
        r['isArchived'],
        r['isGuardian'],
      );
    }
    return hash;
  }

  bool _isCheckingSOSGuardians = false;
  static bool _permissionPromptShownThisSession = false;
  static bool _updatePromptShownThisSession = false;
  Timer? _vaultDebounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    Future.microtask(() {
      ref.read(chatRoomsProvider.notifier).refreshRooms();
      _checkAndRequestPermissions();
      _checkForAppUpdate();
    });
  }

  Future<void> _checkForAppUpdate() async {
    if (_updatePromptShownThisSession) return;

    // Jeda 1.5 detik agar render awal percakapan selesai terlebih dahulu
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _updatePromptShownThisSession) return;

    try {
      final updateService = ref.read(updateServiceProvider);
      final info = await updateService.checkForUpdate();

      if (!mounted || _updatePromptShownThisSession) return;
      if (info.hasUpdate) {
        _updatePromptShownThisSession = true;
        if (mounted) {
          MekaarUpdateBottomSheet.show(
            context: context,
            info: info,
            onUpdate: () {
              showInAppUpdateDialog(
                context: context,
                info: info,
              );
            },
          );
        }
      }
    } catch (_) {
      // Abaikan jika offline / koneksi timeout pada silent auto-check
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vaultDebounceTimer?.cancel();
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
        _isSearchActive = false;
      });
      FocusScope.of(context).unfocus();
      HapticService.trigger(MekaarHapticIntent.success);
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
      MekaarSnackbar.success(
        context,
        'Koleksi Obrolan Tersembunyi Dibuka',
      );
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (_permissionPromptShownThisSession) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAll = await PermissionsHelper.hasAllSOSPermissions();

      if (hasAll) {
        await prefs.setBool('has_shown_sos_permissions_dialog', true);
        return;
      }

      await prefs.remove('has_shown_sos_permissions_dialog');
      _permissionPromptShownThisSession = true;

      if (!hasAll) {
        if (!mounted) return;

        await MekaarPermissionsBottomSheet.show(
          context: context,
          onGrant: () async {
            await PermissionsHelper.requestSOSPermissions();
            final granted = await PermissionsHelper.hasAllSOSPermissions();
            if (granted) {
              await prefs.setBool('has_shown_sos_permissions_dialog', true);
            }
          },
        );
      }
    } catch (_) {}
  }

  Future<void> _triggerSOS() async {
    if (_isCheckingSOSGuardians) return;
    _isCheckingSOSGuardians = true;

    try {
      var loadStatus = ref.read(guardianLoadStatusProvider);
      if (loadStatus != GuardianLoadStatus.data) {
        await ref.read(guardianProvider.notifier).refreshGuardians();
        loadStatus = ref.read(guardianLoadStatusProvider);
      }
      if (!mounted) return;

      if (loadStatus == GuardianLoadStatus.data &&
          activeGuardiansOf(ref.read(guardianProvider)).isEmpty) {
        final shouldContinue = await MekaarDialog.showNoActiveGuardianWarning(
          context: context,
        );
        if (!mounted || !shouldContinue) return;
      }

      Navigator.pushNamed(context, AppRoutes.sosActive);
    } finally {
      _isCheckingSOSGuardians = false;
    }
  }

  Future<void> _handleMuteRoom(Map<String, dynamic> room) async {
    final repo = ref.read(chatRepositoryProvider);
    final prefs = await repo.getRoomPreferences(room['id'] as String);
    final currentlyMuted = prefs?.isMuted ?? false;
    await repo.updateRoomMute(room['id'] as String, !currentlyMuted);
    if (!mounted) return;
    MekaarSnackbar.info(
      context,
      currentlyMuted ? 'Notifikasi diaktifkan' : 'Notifikasi dibisukan',
    );
    ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> _handleArchiveRoom(Map<String, dynamic> room) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.archiveRoom(room['id'] as String);
    if (!mounted) return;
    MekaarSnackbar.info(context, 'Chat diarsipkan');
    ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  void _confirmDeleteRoom(Map<String, dynamic> room) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Chat?',
      message: 'Obrolan akan hilang dari daftar chat Anda.',
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
            await ref.read(chatActionsProvider).deleteChat(room['id'] as String);
          },
          child: const Text('Hapus'),
        ),
      ],
    );
  }

  void _showNewChatDialog() {
    final searchController = TextEditingController();
    bool isSearching = false;
    String errorMessage = '';

    MekaarBottomSheet.show(
      context: context,
      title: 'Mulai Chat Baru',
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (stateCtx, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      SolarIconsOutline.usersGroupTwoRounded,
                      color: AppColors.blue,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Buat Grup Baru',
                    style: MekaarTypography.bodyMD.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  subtitle: Text(
                    'Obrolan bersama beberapa anggota',
                    style: MekaarTypography.bodySM,
                  ),
                  onTap: () {
                    Navigator.pop(stateCtx);
                    Navigator.pushNamed(context, AppRoutes.createGroupSelectMembers);
                  },
                ),
                const Divider(height: 24),
                Text(
                  'Masukkan username atau email teman Anda untuk obrolan 1-on-1.',
                  style: MekaarTypography.bodySM,
                ),
                const SizedBox(height: 16),
                MekaarSearchField(
                  controller: searchController,
                  hintText: 'Username atau Email',
                  errorText: errorMessage.isNotEmpty ? errorMessage : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(stateCtx),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSearching
                            ? null
                            : () async {
                                final query = searchController.text.trim();
                                if (query.isEmpty) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Input tidak boleh kosong',
                                  );
                                  return;
                                }

                                setSheetState(() {
                                  isSearching = true;
                                  errorMessage = '';
                                });

                                try {
                                  final Map<String, dynamic>? profile;
                                  final wasDuress = ref
                                      .read(authProvider)
                                      .lastUnlockWasDuress;

                                  if (wasDuress) {
                                    await Future.delayed(
                                      const Duration(milliseconds: 600),
                                    );
                                    profile = null;
                                  } else {
                                    profile = await ref
                                        .read(chatRepositoryProvider)
                                        .searchProfile(query);
                                  }

                                  if (profile == null) {
                                    setSheetState(() {
                                      isSearching = false;
                                      errorMessage =
                                          'Pengguna tidak ditemukan';
                                    });
                                    return;
                                  }

                                  final myId = ref
                                      .read(supabaseServiceProvider)
                                      .currentUserId;
                                  if (profile['id'] == myId) {
                                    setSheetState(() {
                                      isSearching = false;
                                      errorMessage =
                                          'Tidak bisa memulai chat dengan diri sendiri';
                                    });
                                    return;
                                  }

                                  // Cegah memulai chat dengan pengguna yang diblokir.
                                  final alreadyBlocked = await ref
                                      .read(blockRepositoryProvider)
                                      .isBlocked(
                                          profile['id'] as String);
                                  if (alreadyBlocked) {
                                    setSheetState(() {
                                      isSearching = false;
                                      errorMessage =
                                          'Pengguna ini telah Anda blokir';
                                    });
                                    return;
                                  }

                                  // Cek proteksi undangan chat
                                  final chatReqRepo = ref.read(chatRequestRepositoryProvider);
                                  final isApproved = await chatReqRepo.isChatApproved(profile['id'] as String);

                                  if (!isApproved) {
                                    if (!stateCtx.mounted) return;
                                    // Tampilkan dialog undangan
                                    await SendChatInviteDialog.show(
                                      stateCtx,
                                      receiverId: profile['id'] as String,
                                      receiverUsername: profile['username'] as String? ?? 'User',
                                    );
                                    if (stateCtx.mounted) {
                                      Navigator.pop(stateCtx);
                                      setSheetState(() {
                                        isSearching = false;
                                      });
                                    }
                                    return;
                                  }

                                  // Create or get chat room
                                  final roomId = await ref
                                      .read(chatRoomsProvider.notifier)
                                      .getOrCreateRoom(
                                        profile['id'],
                                        'normal',
                                        screenshotEnabled: ref.read(screenshotBlockProvider),
                                      );

                                  if (stateCtx.mounted) {
                                    Navigator.pop(stateCtx);
                                    Navigator.pushNamed(
                                      stateCtx,
                                      AppRoutes.chat,
                                      arguments: {
                                        'chatId': roomId,
                                        'chatName': (profile['display_name']
                                                        as String?)
                                                    ?.isNotEmpty ==
                                                true
                                            ? profile['display_name']
                                                as String
                                            : profile['full_name']
                                                    as String? ??
                                                profile['username']
                                                    as String? ??
                                                'User',
                                        'chatAvatar': ((profile['display_name']
                                                            as String?)
                                                        ?.isNotEmpty ==
                                                    true
                                                ? profile['display_name']
                                                    as String
                                                : profile['full_name']
                                                        as String? ??
                                                    profile['username']
                                                        as String? ??
                                                    'U')[0],
                                        'isGuardian': false,
                                        'otherUserId':
                                            profile['id'] as String?,
                                        'chatAvatarUrl':
                                            profile['avatar_url'] as String?,
                                      },
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() {
                                    isSearching = false;
                                    errorMessage =
                                        'Gagal membuat chat: $e';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Cari & Chat'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chatRoomsState = ref.watch(chatRoomsProvider);
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            MekaarTabHeader(
              title: 'Pesan',
              isSearchActive: _isSearchActive,
              searchController: _searchController,
              onSearchChanged: (value) {
                setState(() => _searchQuery = value);
                _vaultDebounceTimer?.cancel();
                if (value.trim().length >= 4) {
                  _vaultDebounceTimer =
                      Timer(const Duration(milliseconds: 400), () {
                    _checkVaultPasscode(value);
                  });
                }
              },
              onSearchClosed: () {
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
                        MekaarLiveSafetyPill(
                          activeGuardiansCount:
                              activeGuardiansOf(ref.watch(guardianProvider))
                                  .length,
                          isE2eeActive: true,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.guardian),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            SolarIconsOutline.shieldUser,
                            color: MekaarColors.guardianTeal,
                          ),
                          tooltip: 'Guardian Saya',
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.guardian),
                        ),
                        IconButton(
                          icon: Icon(
                            SolarIconsOutline.magnifier,
                            color: MekaarColors.primaryOf(context),
                          ),
                          tooltip: 'Cari Chat',
                          onPressed: () =>
                              setState(() => _isSearchActive = true),
                        ),
                      ],
                    ),
            ),
            // Banner Private Vault Aktif (jika vault sedang terbuka)
            Consumer(
              builder: (context, ref, _) {
                final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
                if (!isVaultUnlocked) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: MekaarColors.guardianTeal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                      border: Border.all(
                        color: MekaarColors.guardianTeal.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          SolarIconsBold.shieldKeyhole,
                          color: MekaarColors.guardianTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vault Obrolan Terbuka (Sesi Aktif)',
                            style: TextStyle(
                              color: MekaarColors.textPrimaryOf(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            ref.read(privateVaultUnlockedProvider.notifier).state = false;
                            MekaarSnackbar.info(context, 'Vault Obrolan Terkunci');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MekaarColors.guardianTeal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(SolarIconsOutline.lock, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Kunci',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Chat Requests Banner (jika ada permintaan pending)
            StreamBuilder<int>(
              stream: ref.watch(chatRequestRepositoryProvider).streamPendingRequestsCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.chatRequests),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(SolarIconsOutline.shieldUser, color: AppColors.blue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$count Permintaan Chat Masuk Baru',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.blue),
                            ),
                          ),
                          const Icon(SolarIconsOutline.altArrowRight, size: 16, color: AppColors.blue),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            // Sliding Segment Tabs Bar
            MekaarSlidingSegmentBar(
              tabs: _tabs,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) => setState(() => _selectedTabIndex = index),
            ),
            const SizedBox(height: 8),
            // Chat List Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(chatRoomsProvider.notifier).refreshRooms(),
                child: chatRoomsState.when(
                  data: (rooms) => _buildChatList(wasDuress ? [] : rooms),
                  loading: () => const ChatListSkeleton(),
                  error: (err, stack) => Center(
                    child: MekaarStateView(
                      pose: MikaPose.huft,
                      title: 'Gagal Memuat Chat',
                      message: ErrorResolver.resolve(err),
                      actionLabel: 'Coba Lagi',
                      onAction: () =>
                          ref.read(chatRoomsProvider.notifier).refreshRooms(),
                      icon: SolarIconsOutline.refresh,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ).copyWith(bottom: 90),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // SOS Button on the left
            SOSButton(onPressed: _triggerSOS, size: 72),
            // Add Message Frosted Action Button on the right
            MekaarFrostedActionButton(
              size: 56,
              onPressed: _showNewChatDialog,
              tooltip: 'Pesan Baru',
              icon: Icon(
                MekaarIcons.plusBold,
                color: MekaarColors.accentOf(context),
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(List<Map<String, dynamic>> rooms) {
    // Sembunyikan chat dengan pengguna yang diblokir oleh pengguna saat ini.
    final blockedIds = ref
        .watch(blockProvider)
        .maybeWhen(
          data: (list) => list.map((b) => b.blockedId).toSet(),
          orElse: () => <String>{},
        );

    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);

    // Memoized filter rooms by query, tab, blocked IDs, and hidden vault state
    final roomsSignature = _computeRoomsSignature(rooms);
    final bool isCacheValid = _cachedFiltered != null &&
        _lastRoomsSignature == roomsSignature &&
        _lastSearchQuery == _searchQuery &&
        _lastTabIndex == _selectedTabIndex &&
        setEquals(_lastBlockedIds, blockedIds) &&
        setEquals(_lastHiddenIds, hiddenRoomIds) &&
        _lastVaultUnlocked == isVaultUnlocked;

    final List<Map<String, dynamic>> filtered;
    if (isCacheValid) {
      filtered = _cachedFiltered!;
    } else {
      filtered = rooms.where((room) {
        final roomId = room['id'] as String;
        final name = room['name'] as String;
        final username = room['otherUsername'] as String? ?? '';
        final email = room['otherEmail'] as String? ?? '';
        final otherUserId = room['otherUserId'] as String?;

        // 1. Jangan tampilkan chat dengan pengguna yang diblokir.
        if (otherUserId != null && blockedIds.contains(otherUserId)) {
          return false;
        }

        // 2. Cloaking Private Vault: Sembunyikan obrolan jika vault terkunci
        if (!isVaultUnlocked && hiddenRoomIds.contains(roomId)) {
          return false;
        }

        final query = _searchQuery.toLowerCase();
        final matchQuery =
            name.toLowerCase().contains(query) ||
            username.toLowerCase().contains(query) ||
            email.toLowerCase().contains(query);

        if (!matchQuery) return false;

        if (_selectedTab == 'Guardian') {
          return room['isGuardian'] as bool;
        }
        if (_selectedTab == 'Arsip') {
          return room['isArchived'] as bool? ?? false;
        }
        // Tab 'Semua' / 'All': exclude archived
        final isArchived = room['isArchived'] as bool? ?? false;
        return !isArchived;
      }).toList();

      _lastRoomsSignature = roomsSignature;
      _cachedFiltered = filtered;
      _lastSearchQuery = _searchQuery;
      _lastTabIndex = _selectedTabIndex;
      _lastBlockedIds = Set<String>.from(blockedIds);
      _lastHiddenIds = Set<String>.from(hiddenRoomIds);
      _lastVaultUnlocked = isVaultUnlocked;
    }

    if (filtered.isEmpty) {
      final hasSearch = _searchQuery.trim().isNotEmpty;
      final isGuardianFilter = _selectedTab == 'Guardian';
      final isArchiveFilter = _selectedTab == 'Arsip';
      return _EmptyChats(
        onStart: _showNewChatDialog,
        title: hasSearch
            ? 'Chat tidak ditemukan'
            : isGuardianFilter
            ? 'Belum ada chat Guardian'
            : isArchiveFilter
            ? 'Tidak ada chat diarsipkan'
            : 'Belum ada obrolan',
        message: hasSearch
            ? 'Tidak ada chat yang cocok dengan "${_searchQuery.trim()}".'
            : isGuardianFilter
            ? 'Chat dengan Guardian akan muncul di filter ini.'
            : isArchiveFilter
            ? 'Chat yang diarsipkan akan muncul di sini.'
            : 'Mulai percakapan pertamamu dengan teman atau Guardian.',
        showStartButton: !hasSearch && !isGuardianFilter && !isArchiveFilter,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ).copyWith(bottom: 110),
      children: [
        CustomCard(
          margin: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MekaarRadius.lg),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                indent: 74,
                endIndent: 16,
                color: MekaarColors.cardBorderOf(context).withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final room = filtered[index];
                final roomId = room['id'] as String;
                final isHidden = hiddenRoomIds.contains(roomId);

                return GestureDetector(
                  onLongPress: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.contactSettings,
                      arguments: {
                        'roomId': room['id'],
                        'chatName': room['name'],
                        'chatAvatar': room['avatar'],
                        'otherUserId': room['otherUserId'],
                        'isGuardian': room['isGuardian'] as bool? ?? false,
                      },
                    );
                  },
                  child: ChatListTile(
                    room: room,
                    isHidden: isHidden,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.chat,
                        arguments: {
                          'chatId': room['id'],
                          'chatName': room['name'],
                          'chatAvatar': room['avatar'],
                          'chatAvatarUrl': room['avatarUrl'] as String?,
                          'isGuardian': room['isGuardian'] as bool? ?? false,
                          'otherUserId': room['otherUserId'] as String?,
                        },
                      );
                    },
                    onMute: () => _handleMuteRoom(room),
                    onDelete: () => _confirmDeleteRoom(room),
                    onArchive: () => _handleArchiveRoom(room),
                    onToggleHide: () => PrivateVaultDialogs.toggleRoomHiddenWithAuth(
                      context,
                      ref,
                      roomId: roomId,
                      chatName: room['name'] as String? ?? 'Obrolan',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final VoidCallback onStart;
  final String title;
  final String message;
  final bool showStartButton;

  const _EmptyChats({
    required this.onStart,
    required this.title,
    required this.message,
    required this.showStartButton,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              MikaAnimated(
                pose: MikaPose.sleep,
                size: 120,
                semanticLabel: 'Mika menyapa dari layar kosong',
              ),
              const SizedBox(height: MekaarSpacing.xl),
              Text(title, style: MekaarTypography.headingMD),
              const SizedBox(height: MekaarSpacing.sm),
              Padding(
                padding: MekaarSpacing.screen,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: MekaarTypography.bodyMD,
                ),
              ),
              if (showStartButton) ...[
                const SizedBox(height: MekaarSpacing.xl),
                ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(SolarIconsOutline.chatSquare, size: 18),
                  label: const Text('Mulai obrolan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
