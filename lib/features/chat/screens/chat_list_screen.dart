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

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  String _selectedTab = 'All';
  bool _isCheckingSOSGuardians = false;
  static bool _permissionPromptShownThisSession = false;

  final List<String> _tabs = ['All', 'Guardian'];

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

  void _showNewChatDialog() {
    final searchController = TextEditingController();
    bool isSearching = false;
    String errorMessage = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Mulai Chat Baru',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan username atau email teman Anda untuk memulai obrolan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MekaarColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  MekaarSearchField(
                    controller: searchController,
                    hintText: 'Username atau Email',
                    errorText: errorMessage.isNotEmpty ? errorMessage : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: MekaarColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSearching
                      ? null
                      : () async {
                          final query = searchController.text.trim();
                          if (query.isEmpty) {
                            setDialogState(
                              () => errorMessage = 'Input tidak boleh kosong',
                            );
                            return;
                          }

                          setDialogState(() {
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
                              setDialogState(() {
                                isSearching = false;
                                errorMessage = 'Pengguna tidak ditemukan';
                              });
                              return;
                            }

                            final myId = ref
                                .read(supabaseServiceProvider)
                                .currentUserId;
                            if (profile['id'] == myId) {
                              setDialogState(() {
                                isSearching = false;
                                errorMessage =
                                    'Tidak bisa memulai chat dengan diri sendiri';
                              });
                              return;
                            }

                            // Cegah memulai chat dengan pengguna yang diblokir.
                            final alreadyBlocked = await ref
                                .read(blockRepositoryProvider)
                                .isBlocked(profile['id'] as String);
                            if (alreadyBlocked) {
                              setDialogState(() {
                                isSearching = false;
                                errorMessage = 'Pengguna ini telah Anda blokir';
                              });
                              return;
                            }

                            // Create or get chat room
                            final roomId = await ref
                                .read(chatRoomsProvider.notifier)
                                .getOrCreateRoom(profile['id'], 'normal');

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              Navigator.pushNamed(
                                context,
                                AppRoutes.chat,
                                arguments: {
                                  'chatId': roomId,
                                  'chatName':
                                      profile['full_name'] as String? ??
                                      profile['username'] as String? ??
                                      'User',
                                  'chatAvatar':
                                      (profile['full_name'] as String? ??
                                      profile['username'] as String? ??
                                      'U')[0],
                                  'isGuardian': false,
                                  'otherUserId': profile['id'] as String?,
                                },
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSearching = false;
                              errorMessage = 'Gagal membuat chat: $e';
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
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  : IconButton(
                      icon: const Icon(
                        SolarIconsOutline.shieldUser,
                        color: MekaarColors.guardianTeal,
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.guardian),
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
      return true;
    }).toList();

    if (filtered.isEmpty) {
      final hasSearch = _searchQuery.trim().isNotEmpty;
      final isGuardianFilter = _selectedTab == 'Guardian';
      return _EmptyChats(
        onStart: _showNewChatDialog,
        title: hasSearch
            ? 'Chat tidak ditemukan'
            : isGuardianFilter
            ? 'Belum ada chat Guardian'
            : 'Belum ada obrolan',
        message: hasSearch
            ? 'Tidak ada chat yang cocok dengan "${_searchQuery.trim()}".'
            : isGuardianFilter
            ? 'Chat dengan Guardian akan muncul di filter ini.'
            : 'Mulai percakapan pertamamu dengan teman atau Guardian.',
        showStartButton: !hasSearch && !isGuardianFilter,
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
                  'isGuardian': room['isGuardian'] as bool? ?? false,
                  'otherUserId': room['otherUserId'] as String?,
                },
              );
            },
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
