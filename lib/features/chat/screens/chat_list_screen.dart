import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/sos_button.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_list_tile.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  String _selectedTab = 'All';

  final List<String> _tabs = ['All', 'Guardian', 'Groups'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatRoomsProvider.notifier).refreshRooms();
      _checkAndRequestPermissions();
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      final hasAll = await PermissionsHelper.hasAllSOSPermissions();

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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await PermissionsHelper.requestSOSPermissions();
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

  void _triggerSOS() {
    Navigator.pushNamed(context, AppRoutes.sosActive);
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
                            final profile = await ref
                                .read(chatRepositoryProvider)
                                .searchProfile(query);

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

    return Scaffold(
      backgroundColor: MekaarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: MekaarColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.shield_outlined,
                      color: MekaarColors.guardianTeal,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.guardian),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: MekaarColors.textSecondary,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
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
                            ? MekaarColors.textPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : MekaarColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
                  data: (rooms) => _buildChatList(rooms),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('Gagal memuat chat: $err')),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
              child: const Icon(Icons.add_comment_outlined, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(List<Map<String, dynamic>> rooms) {
    // Filter rooms by query and selected tab
    final filtered = rooms.where((room) {
      final name = room['name'] as String;
      final username = room['otherUsername'] as String? ?? '';
      final email = room['otherEmail'] as String? ?? '';

      final query = _searchQuery.toLowerCase();
      final matchQuery =
          name.toLowerCase().contains(query) ||
          username.toLowerCase().contains(query) ||
          email.toLowerCase().contains(query);

      if (!matchQuery) return false;

      if (_selectedTab == 'Guardian') {
        return room['isGuardian'] as bool;
      } else if (_selectedTab == 'Groups') {
        return false; // Groups not implemented in Phase 1
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: MekaarColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada chat',
              style: TextStyle(
                color: MekaarColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final room = filtered[index];

        return ChatListTile(
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
              },
            );
          },
        );
      },
    );
  }
}
