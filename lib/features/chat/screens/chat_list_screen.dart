import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../../guardian/providers/guardian_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/sos_button.dart';
import '../providers/chat_provider.dart';
import '../../settings/providers/block_provider.dart';
import '../widgets/chat_list_tile.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _selectedTab = 'All';
  bool _isCheckingSOSGuardians = false;
  static bool _permissionPromptShownThisSession = false;

  final List<String> _tabs = ['All', 'Guardian', 'Arsip'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatRoomsProvider.notifier).refreshRooms();
      _checkAndRequestPermissions();
    });
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

        MekaarDialog.showConfirmation<void>(
          context: context,
          barrierDismissible: false,
          icon: const Icon(Icons.security, color: MekaarColors.softCoral),
          title: 'Izin Sensor Darurat',
          message:
              'Untuk perlindungan maksimal, MEKAAR memerlukan izin akses:\n\n'
              '• Lokasi: Mengirim koordinat GPS saat SOS aktif.\n'
              '• Kamera: Merekam bukti video kondisi darurat.\n'
              '• Mikrofon: Mengirim suara sekitar ke Guardian.\n\n'
              'Ponsel Anda akan memicu pop-up sistem setelah ini.',
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: MekaarColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await PermissionsHelper.requestSOSPermissions();
                final granted = await PermissionsHelper.hasAllSOSPermissions();
                if (granted) {
                  await prefs.setBool('has_shown_sos_permissions_dialog', true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.softCoral,
                foregroundColor: Colors.white,
              ),
              child: const Text('Berikan Izin'),
            ),
          ],
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
                Text(
                  'Masukkan username atau email teman Anda untuk memulai obrolan.',
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
                          backgroundColor: MekaarColors.softCoral,
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
      body: SafeArea(
        child: Column(
          children: [
            MekaarTabHeader(
              title: 'Pesan',
              action: wasDuress
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            SolarIconsOutline.camera,
                            color: MekaarColors.cyan,
                          ),
                          tooltip: 'Pindai QR Code Teman',
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.contactQrScan),
                        ),
                        IconButton(
                          icon: const Icon(
                            SolarIconsOutline.qrCode,
                            color: MekaarColors.yellow,
                          ),
                          tooltip: 'Tampilkan QR Saya',
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.myQr),
                        ),
                        IconButton(
                          icon: const Icon(
                            SolarIconsOutline.shieldUser,
                            color: MekaarColors.guardianTeal,
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.guardian),
                        ),
                      ],
                    ),
            ),
            // Search Input
            Padding(
              padding: MekaarSpacing.screen,
              child: MekaarSearchField(
                hintText: 'Cari chat atau teman...',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 12),
            // Tabs Bar
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isActive = _selectedTab == tab;
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = tab),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? MekaarColors.yellow
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tab,
                        style: MekaarTypography.labelLG.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? MekaarColors.textOnYellow
                              : (isDark
                                    ? MekaarColors.textMuted
                                    : Colors.black54),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
                    child: Text(
                      'Gagal memuat chat: $err',
                      style: MekaarTypography.bodyMD,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
            // Add Message FAB on the right
            FloatingActionButton(
              onPressed: _showNewChatDialog,
              backgroundColor: MekaarColors.softCoral,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(SolarIconsOutline.chatSquare, size: 24),
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

    // Filter rooms by query and selected tab
    final filtered = rooms.where((room) {
      final name = room['name'] as String;
      final username = room['otherUsername'] as String? ?? '';
      final email = room['otherEmail'] as String? ?? '';
      final otherUserId = room['otherUserId'] as String?;

      // Jangan tampilkan chat dengan pengguna yang diblokir.
      if (otherUserId != null && blockedIds.contains(otherUserId)) {
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
      // Tab 'All': exclude archived
      final isArchived = room['isArchived'] as bool? ?? false;
      return !isArchived;
    }).toList();

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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ).copyWith(bottom: 110),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final room = filtered[index];

        return AnimatedAppear(
          delay: Duration(milliseconds: (index * 40).clamp(0, 300)),
          child: GestureDetector(
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
            ),
          ),
        );
      },
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
    return AnimatedAppear(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                const MikaIllustration(
                  pose: MikaPose.phone,
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
                      backgroundColor: MekaarColors.softCoral,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
