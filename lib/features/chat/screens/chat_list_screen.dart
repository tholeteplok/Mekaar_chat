import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_notification_dot.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../../guardian/providers/guardian_provider.dart';
import '../../sos/providers/sos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/sos_button.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';
import '../widgets/private_vault_dialogs.dart';
import '../widgets/private_vault_active_banner.dart';
import '../../guardian/widgets/guardian_sos_alert_banner.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../settings/providers/block_provider.dart';
import '../../../data/repositories/chat_request_repository.dart';
import '../widgets/chat_list_tile.dart';
import '../widgets/send_chat_invite_dialog.dart';
import '../../../core/widgets/mekaar_update_bottom_sheet.dart';
import '../../../core/widgets/mekaar_update_dialog.dart';
import '../../../core/widgets/mekaar_permissions_bottom_sheet.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
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
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounceTimer;
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Semua', 'Guardian'];
  String get _selectedTab => _tabs[_selectedTabIndex];

  // Cache memoization untuk filter room
  int? _lastRoomsSignature;
  List<Map<String, dynamic>>? _cachedFiltered;
  String? _lastSearchQuery;
  int? _lastTabIndex;
  Set<String>? _lastBlockedIds;
  Set<String>? _lastHiddenIds;
  Set<String>? _lastHiddenContactIds;
  Set<String>? _lastVaultedContactIds;
  bool? _lastVaultUnlocked;

  int _computeRoomsSignature(List<Map<String, dynamic>> rooms) {
    if (rooms.isEmpty) return 0;
    int hash = rooms.length;
    for (final r in rooms) {
      hash = Object.hash(
        hash,
        r['id'],
        r['name'],
        r['timestamp'],
        r['unreadCount'],
        r['lastMessage'],
        r['isArchived'],
        r['isGuardian'],
        r['isMuted'],
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
    _searchFocusNode = FocusNode();
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
    _searchDebounceTimer?.cancel();
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
    final isSosActive = ref.read(sosProvider).status == SOSStatus.active ||
        ref.read(sosProvider).status == SOSStatus.queuedOffline;
    if (isSosActive) {
      Navigator.pushNamed(context, AppRoutes.sosActive);
      return;
    }

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

  Future<void> _handleMarkAsReadRoom(Map<String, dynamic> room) async {
    final roomId = room['id'] as String;
    await ref.read(chatActionsProvider).markRoomRead(roomId);
    if (!mounted) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  void _showChatTileContextMenu(BuildContext context, Map<String, dynamic> room) {
    HapticService.trigger(MekaarHapticIntent.selection);
    final roomId = room['id'] as String;
    final chatName = room['name'] as String? ?? 'Obrolan';
    final chatAvatar = room['avatar'] as String? ?? '';
    final chatAvatarUrl = room['avatarUrl'] as String?;
    final otherUserId = room['otherUserId'] as String?;
    final isGuardian = room['isGuardian'] as bool? ?? false;
    final isMuted = room['isMuted'] as bool? ?? false;
    final unreadCount = room['unreadCount'] as int? ?? 0;

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info obrolan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Avatar(
                  initial: chatAvatar.isNotEmpty ? chatAvatar : chatName[0],
                  imageUrl: chatAvatarUrl,
                  size: 44,
                  isGuardian: isGuardian,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chatName,
                        style: MekaarTypography.headingSM.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        room['lastMessage'] as String? ?? 'Tidak ada pesan',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textMutedOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 1. Tandai Sudah Dibaca
          if (unreadCount > 0)
            ListTile(
              leading: const Icon(SolarIconsOutline.checkCircle, color: AppColors.blue),
              title: const Text('Tandai Sudah Dibaca'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _handleMarkAsReadRoom(room);
              },
            ),

          // 2. Bisukan / Bunyikan Notifikasi
          ListTile(
            leading: Icon(
              isMuted ? SolarIconsOutline.bell : SolarIconsOutline.bellOff,
              color: isMuted ? AppColors.blue : MekaarColors.warnAmber,
            ),
            title: Text(isMuted ? 'Bunyikan Notifikasi' : 'Bisukan Notifikasi'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _handleMuteRoom(room);
            },
          ),

          // 3. Arsipkan Obrolan
          ListTile(
            leading: Icon(SolarIconsOutline.archive, color: MekaarColors.accentTextOf(context)),
            title: const Text('Arsipkan Obrolan'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _handleArchiveRoom(room);
            },
          ),

          // 4. Info Kontak & Pengaturan
          ListTile(
            leading: const Icon(SolarIconsOutline.infoCircle, color: AppColors.blue),
            title: const Text('Info Kontak & Pengaturan'),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.pushNamed(
                context,
                AppRoutes.contactSettings,
                arguments: {
                  'roomId': roomId,
                  'chatName': chatName,
                  'chatAvatar': chatAvatar,
                  'otherUserId': otherUserId,
                  'isGuardian': isGuardian,
                },
              );
            },
          ),

          const Divider(height: 1),

          // 6. Hapus Obrolan
          ListTile(
            leading: const Icon(SolarIconsOutline.trashBinTrash, color: MekaarColors.sosRed),
            title: const Text(
              'Hapus Chat',
              style: TextStyle(color: MekaarColors.sosRed, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmDeleteRoom(room);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
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
      title: 'Hapus Chat dari Daftar Anda?',
      message:
          'Obrolan ini hanya akan dihapus dari daftar pesan Anda. Rekan obrolan tetap dapat melihat percakapan ini.',
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
          child: const Text('Hapus (Hanya Saya)'),
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

                                  // Proteksi Private Vault: jika user tujuan disembunyikan & vault terkunci, verifikasi PIN terlebih dahulu
                                  if (!stateCtx.mounted) return;
                                  final targetUserId = profile['id'] as String;
                                  final isTargetVaulted = ref.read(hiddenContactUserIdsProvider).contains(targetUserId) ||
                                      (ref.read(userContactsProvider).value?.any((c) => c.contactUserId == targetUserId && c.isVaulted) ?? false);
                                  final isVaultUnlocked = ref.read(privateVaultUnlockedProvider);

                                  if (isTargetVaulted && !isVaultUnlocked) {
                                    final unlocked = await PrivateVaultDialogs.showUnlockPasscodeDialog(stateCtx, ref);
                                    if (!unlocked || !stateCtx.mounted) return;
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
              key: const ValueKey('chat_list_tab_header'),
              title: 'Mekaar',
              isSearchActive: _isSearchActive,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearchChanged: (value) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer =
                    Timer(const Duration(milliseconds: 180), () {
                  if (mounted && _searchQuery != value) {
                    setState(() => _searchQuery = value);
                  }
                });
                _vaultDebounceTimer?.cancel();
                if (value.trim().length >= 4) {
                  _vaultDebounceTimer =
                      Timer(const Duration(milliseconds: 400), () {
                    _checkVaultPasscode(value);
                  });
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
                  : Consumer(
                      builder: (context, ref, _) {
                        final activeGuardians =
                            activeGuardiansOf(ref.watch(guardianProvider));
                        final hasPending =
                            ref.watch(hasPendingIncomingGuardiansProvider);
                        final activeCount = activeGuardians.length;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: MekaarNotificationDot(
                                badgeCount: activeCount > 0 ? activeCount : null,
                                badgeColor: MekaarColors.primaryOf(context),
                                show: hasPending,
                                showDot: hasPending,
                                color: MekaarColors.warnAmber,
                                offset: const Offset(0, -2),
                                child: const Icon(
                                  SolarIconsOutline.shieldUser,
                                  color: MekaarColors.guardianTeal,
                                ),
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
                            PopupMenuButton<String>(
                              icon: Icon(
                                SolarIconsOutline.menuDotsCircle,
                                color: MekaarColors.primaryOf(context),
                              ),
                              tooltip: 'Menu Rahasia & Arsip',
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: MekaarColors.surfaceOf(context),
                              onSelected: (value) async {
                                if (value == 'vault') {
                                  final verified =
                                      await MekaarPinVerificationSheet.verify(
                                    context,
                                    title: 'Buka Brankas Berkas',
                                    subtitle:
                                        'Masukkan PIN untuk mengakses berkas rahasia',
                                  );
                                  if (verified && context.mounted) {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.vault,
                                    );
                                  }
                                } else if (value == 'archive') {
                                  final verified =
                                      await MekaarPinVerificationSheet.verify(
                                    context,
                                    title: 'Buka Arsip Percakapan',
                                    subtitle:
                                        'Masukkan PIN untuk mengakses obrolan terarsip',
                                  );
                                  if (verified && context.mounted) {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.archivedChats,
                                    );
                                  }
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem<String>(
                                  value: 'vault',
                                  child: Row(
                                    children: [
                                      Icon(
                                        SolarIconsOutline.safeSquare,
                                        color: MekaarColors.primaryOf(context),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Brankas Berkas',
                                        style: MekaarTypography.bodyMD.copyWith(
                                          color: MekaarColors.textPrimaryOf(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'archive',
                                  child: Row(
                                    children: [
                                      Icon(
                                        SolarIconsOutline.archiveCheck,
                                        color: MekaarColors.primaryOf(context),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Arsip Percakapan',
                                        style: MekaarTypography.bodyMD.copyWith(
                                          color: MekaarColors.textPrimaryOf(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
            // Banner Darurat SOS untuk Guardian (jika orang yang dijaga dalam bahaya)
            const GuardianSOSAlertBanner(),
            // Banner Private Vault Aktif (jika vault sedang terbuka)
            const PrivateVaultActiveBanner(),
            // Chat Requests Banner (jika ada permintaan pending)
            Consumer(
              builder: (context, ref, _) {
                final count =
                    ref.watch(pendingRequestsCountStreamProvider).valueOrNull ??
                        0;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: InkWell(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.chatRequests),
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                    child: MekaarBanner(
                      color: AppColors.blue,
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      icon: SolarIconsOutline.shieldUser,
                      content: Text(
                        '$count Permintaan Chat Masuk Baru',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.blue),
                      ),
                      action: const Icon(SolarIconsOutline.altArrowRight,
                          size: 16, color: AppColors.blue),
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
                      illustration: ErrorResolver.resolveIllustration(err),
                      stateIcon: ErrorResolver.resolveIllustration(err) == null
                          ? ErrorResolver.resolveIcon(err)
                          : null,
                      stateIconColor:
                          ErrorResolver.resolveIconColor(err, context),
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
            Consumer(
              builder: (context, ref, _) {
                final isSosActive = ref.watch(sosProvider).status == SOSStatus.active;
                return SOSButton(
                  onPressed: _triggerSOS,
                  isActive: isSosActive,
                  size: 72,
                );
              },
            ),
            // Add Message Action Button on the right (Clean Solid FAB)
            Container(
              width: MekaarSizes.fab,
              height: MekaarSizes.fab,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  customBorder: const CircleBorder(),
                  onTap: _showNewChatDialog,
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.addCircle,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _extractRoomTimestamp(dynamic timestamp) {
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
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
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final contactsList = ref.watch(userContactsProvider).value ?? const <ContactItem>[];
    final vaultedContactIds = contactsList.where((c) => c.isVaulted).map((c) => c.contactUserId).toSet();

    // Memoized filter rooms by query, tab, blocked IDs, and hidden vault state
    final roomsSignature = _computeRoomsSignature(rooms);
    final bool isCacheValid = _cachedFiltered != null &&
        _lastRoomsSignature == roomsSignature &&
        _lastSearchQuery == _searchQuery &&
        _lastTabIndex == _selectedTabIndex &&
        setEquals(_lastBlockedIds, blockedIds) &&
        setEquals(_lastHiddenIds, hiddenRoomIds) &&
        setEquals(_lastHiddenContactIds, hiddenContactUserIds) &&
        setEquals(_lastVaultedContactIds, vaultedContactIds) &&
        _lastVaultUnlocked == isVaultUnlocked;

    final List<Map<String, dynamic>> filtered;
    if (isCacheValid) {
      filtered = _cachedFiltered!;
    } else {
      // 1. Unifikasi 1 Kontak = 1 Percakapan untuk direct chats (mencegah duplikasi entri seperti Thole normal vs guardian)
      final Map<String, Map<String, dynamic>> unifiedByOtherUser = {};
      final List<Map<String, dynamic>> nonDirectRooms = [];

      for (final room in rooms) {
        final otherUserId = room['otherUserId'] as String?;
        final isGroup = room['isGroup'] as bool? ?? false;

        if (isGroup || otherUserId == null || otherUserId.isEmpty) {
          nonDirectRooms.add(room);
        } else {
          if (!unifiedByOtherUser.containsKey(otherUserId)) {
            unifiedByOtherUser[otherUserId] = Map<String, dynamic>.from(room);
          } else {
            final existing = unifiedByOtherUser[otherUserId]!;
            final existingTime = _extractRoomTimestamp(existing['timestamp']);
            final roomTime = _extractRoomTimestamp(room['timestamp']);

            // Prioritaskan room dengan pesan & aktivitas paling mutakhir
            final dominantRoom = roomTime.isAfter(existingTime) ? room : existing;
            final isGuardian = (existing['isGuardian'] == true) || (room['isGuardian'] == true);
            final totalUnread = (existing['unreadCount'] as int? ?? 0) + (room['unreadCount'] as int? ?? 0);
            final isArchived = (existing['isArchived'] == true) && (room['isArchived'] == true);

            final merged = Map<String, dynamic>.from(dominantRoom);
            merged['isGuardian'] = isGuardian;
            merged['unreadCount'] = totalUnread;
            merged['isArchived'] = isArchived;
            unifiedByOtherUser[otherUserId] = merged;
          }
        }
      }

      final unifiedRooms = [...unifiedByOtherUser.values, ...nonDirectRooms];
      unifiedRooms.sort((a, b) {
        final tA = _extractRoomTimestamp(a['timestamp']);
        final tB = _extractRoomTimestamp(b['timestamp']);
        return tB.compareTo(tA);
      });

      filtered = unifiedRooms.where((room) {
        final roomId = room['id'] as String;
        final name = room['name'] as String;
        final username = room['otherUsername'] as String? ?? '';
        final email = room['otherEmail'] as String? ?? '';
        final otherUserId = room['otherUserId'] as String?;

        // 1. Jangan tampilkan chat dengan pengguna yang diblokir.
        if (otherUserId != null && blockedIds.contains(otherUserId)) {
          return false;
        }

        // 2. Cloaking Private Vault: Sembunyikan obrolan jika vault terkunci (berdasarkan roomId atau contactUserId)
        final isDirectHidden = otherUserId != null &&
            (hiddenContactUserIds.contains(otherUserId) || vaultedContactIds.contains(otherUserId));
        final isRoomHidden = hiddenRoomIds.contains(roomId);
        if (!isVaultUnlocked && (isDirectHidden || isRoomHidden)) {
          return false;
        }

        final query = _searchQuery.toLowerCase();
        final matchQuery =
            name.toLowerCase().contains(query) ||
            username.toLowerCase().contains(query) ||
            email.toLowerCase().contains(query);

        if (!matchQuery) return false;

        if (_selectedTab == 'Guardian') {
          return (room['isGuardian'] as bool? ?? false) &&
              !(room['isArchived'] as bool? ?? false);
        }
        // Tab 'Pesan' (inbox utama): tampilkan semua obrolan aktif yang tidak diarsipkan
        final isArchived = room['isArchived'] as bool? ?? false;
        return !isArchived;
      }).toList();

      _lastRoomsSignature = roomsSignature;
      _cachedFiltered = filtered;
      _lastSearchQuery = _searchQuery;
      _lastTabIndex = _selectedTabIndex;
      _lastBlockedIds = Set<String>.from(blockedIds);
      _lastHiddenIds = Set<String>.from(hiddenRoomIds);
      _lastHiddenContactIds = Set<String>.from(hiddenContactUserIds);
      _lastVaultedContactIds = Set<String>.from(vaultedContactIds);
      _lastVaultUnlocked = isVaultUnlocked;
    }

    if (filtered.isEmpty) {
      final hasSearch = _searchQuery.trim().isNotEmpty;
      final isGuardianFilter = _selectedTab == 'Guardian';
      final isArchiveFilter = _selectedTab == 'Arsip';
      final MikaIllustrationType emptyIllustration = hasSearch
          ? MikaIllustrationType.emptySearch
          : isGuardianFilter
              ? MikaIllustrationType.emptyGuardian
              : isArchiveFilter
                  ? MikaIllustrationType.emptyArchive
                  : MikaIllustrationType.emptyChat;

      return _EmptyChats(
        onStart: _showNewChatDialog,
        illustration: emptyIllustration,
        title: hasSearch
            ? 'Tidak Ditemukan'
            : isGuardianFilter
            ? 'Belum Ada Chat Guardian'
            : isArchiveFilter
            ? 'Arsip Bersih'
            : 'Belum Ada Obrolan',
        message: hasSearch
            ? 'Tidak ada percakapan yang cocok dengan "${_searchQuery.trim()}".'
            : isGuardianFilter
            ? 'Chat dengan Guardian tepercaya akan muncul di filter ini.'
            : isArchiveFilter
            ? 'Belum ada obrolan yang diarsipkan.'
            : 'Mulai obrolan baru dengan kontak atau bagikan kode QR.',
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
          borderRadius: MekaarRadius.card,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MekaarRadius.card),
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
                final otherUserId = room['otherUserId'] as String?;
                final isHidden = hiddenRoomIds.contains(roomId) ||
                    (otherUserId != null &&
                        (hiddenContactUserIds.contains(otherUserId) ||
                            vaultedContactIds.contains(otherUserId)));

                return ChatListTile(
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
                  onLongPress: () => _showChatTileContextMenu(context, room),
                  onMarkRead: () => _handleMarkAsReadRoom(room),
                  onMute: () => _handleMuteRoom(room),
                  onDelete: () => _confirmDeleteRoom(room),
                  onArchive: () => _handleArchiveRoom(room),
                  onToggleHide: () => PrivateVaultDialogs.toggleRoomHiddenWithAuth(
                    context,
                    ref,
                    roomId: roomId,
                    chatName: room['name'] as String? ?? 'Obrolan',
                    otherUserId: otherUserId,
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
  final MikaIllustrationType illustration;
  final String title;
  final String message;
  final bool showStartButton;

  const _EmptyChats({
    required this.onStart,
    this.illustration = MikaIllustrationType.emptyChat,
    required this.title,
    required this.message,
    required this.showStartButton,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              MikaIllustration(
                type: illustration,
                size: 160,
                semanticLabel: title,
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
                  icon: const Icon(SolarIconsOutline.pen, size: 18),
                  label: const Text('Mulai Chat Baru'),
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