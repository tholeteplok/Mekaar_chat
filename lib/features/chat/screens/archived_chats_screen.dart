import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_list_tile.dart';

/// Layar Arsip Percakapan terproteksi PIN.
///
/// Menyimpan obrolan yang diarsipkan secara aman dan tersembunyi
/// dari beranda utama (ChatListScreen).
class ArchivedChatsScreen extends ConsumerStatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  ConsumerState<ArchivedChatsScreen> createState() =>
      _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends ConsumerState<ArchivedChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleUnarchiveRoom(Map<String, dynamic> room) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.unarchiveRoom(room['id'] as String);
      if (!mounted) return;
      MekaarSnackbar.info(context, 'Obrolan dikembalikan ke kotak masuk');
      ref.read(chatRoomsProvider.notifier).refreshRooms();
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal membatalkan arsip: $e');
    }
  }

  void _confirmDeleteRoom(Map<String, dynamic> room) {
    HapticService.trigger(MekaarHapticIntent.warning);
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Chat?',
      message: 'Obrolan ini akan dihapus permanen dari daftar pesan Anda.',
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
            if (!mounted) return;
            MekaarSnackbar.success(context, 'Obrolan berhasil dihapus');
            ref.read(chatRoomsProvider.notifier).refreshRooms();
          },
          child: const Text('Hapus'),
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, Map<String, dynamic> room) {
    HapticService.trigger(MekaarHapticIntent.selection);
    final roomName = room['name'] as String? ?? 'Obrolan';

    MekaarBottomSheet.show(
      context: context,
      title: roomName,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              SolarIconsOutline.inboxIn,
              color: MekaarColors.primaryOf(context),
            ),
            title: Text(
              'Keluarkan dari Arsip',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
              ),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              _handleUnarchiveRoom(room);
            },
          ),
          ListTile(
            leading: const Icon(
              SolarIconsOutline.trashBinTrash,
              color: MekaarColors.sosRed,
            ),
            title: Text(
              'Hapus Chat',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.sosRed,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmDeleteRoom(room);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomsAsync = ref.watch(chatRoomsProvider);

    return MekaarScaffold(
      appBar: CustomAppBar(
        title: 'Arsip Percakapan',
        actions: [
          IconButton(
            icon: Icon(
              _isSearchActive
                  ? SolarIconsOutline.closeCircle
                  : SolarIconsOutline.magnifier,
              color: MekaarColors.primaryOf(context),
            ),
            tooltip: _isSearchActive ? 'Tutup Pencarian' : 'Cari Arsip',
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari dalam arsip percakapan...',
                  prefixIcon: const Icon(SolarIconsOutline.magnifier),
                  filled: true,
                  fillColor: MekaarColors.surface2Of(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: chatRoomsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Center(
                child: MekaarStateView(
                  illustration: ErrorResolver.resolveIllustration(err),
                  stateIcon: ErrorResolver.resolveIllustration(err) == null
                      ? ErrorResolver.resolveIcon(err)
                      : null,
                  stateIconColor: ErrorResolver.resolveIconColor(err, context),
                  title: 'Gagal Memuat Arsip',
                  message: ErrorResolver.resolve(err),
                  actionLabel: 'Coba Lagi',
                  onAction: () =>
                      ref.read(chatRoomsProvider.notifier).refreshRooms(),
                ),
              ),
              data: (rooms) {
                // Filter hanya room yang diarsipkan
                final archivedRooms = rooms.where((room) {
                  final isArchived = room['isArchived'] as bool? ?? false;
                  if (!isArchived) return false;

                  if (_searchQuery.isNotEmpty) {
                    final name =
                        (room['name'] as String? ?? '').toLowerCase();
                    final lastMsg =
                        (room['lastMessage'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        lastMsg.contains(_searchQuery);
                  }
                  return true;
                }).toList();

                if (archivedRooms.isEmpty) {
                  return Center(
                    child: MekaarStateView(
                      illustration: _searchQuery.isNotEmpty
                          ? MikaIllustrationType.emptySearch
                          : MikaIllustrationType.emptyArchive,
                      title: _searchQuery.isNotEmpty
                          ? 'Tidak Ditemukan'
                          : 'Arsip Bersih',
                      message: _searchQuery.isNotEmpty
                          ? 'Tidak ada arsip yang cocok dengan "$_searchQuery".'
                          : 'Belum ada obrolan yang diarsipkan.',
                      actionLabel: _searchQuery.isNotEmpty ? null : 'Kembali ke Obrolan',
                      onAction: _searchQuery.isNotEmpty
                          ? null
                          : () => Navigator.pop(context),
                      icon: SolarIconsOutline.arrowLeft,
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(chatRoomsProvider.notifier).refreshRooms();
                  },
                  child: ListView.builder(
                    itemCount: archivedRooms.length,
                    itemBuilder: (context, index) {
                      final room = archivedRooms[index];
                      return ChatListTile(
                        room: room,
                        onTap: () {
                          HapticService.trigger(MekaarHapticIntent.selection);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.chat,
                            arguments: {
                              'chatId': room['id'],
                              'chatName': room['name'],
                              'chatAvatar': room['avatar'] ??
                                  'assets/images/default_avatar.png',
                              'chatAvatarUrl': room['avatarUrl'],
                              'isGuardian': room['isGuardian'] ?? false,
                              'isGroup': room['isGroup'] ?? false,
                              'otherUserId': room['otherUserId'],
                            },
                          );
                        },
                        onLongPress: () => _showContextMenu(context, room),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
