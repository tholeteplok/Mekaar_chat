import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/strings.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/guest_session_guard.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/utils/permissions.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_elastic_pull_scope.dart';
import '../../../core/widgets/mekaar_header_search_button.dart';
import '../../../core/widgets/mekaar_selection_header.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sos/providers/sos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';
import '../providers/vault_provider.dart';
import '../../../data/services/database_key_service.dart';
import '../../../data/services/local_vault_database.dart';
import '../../guardian/widgets/guardian_sos_alert_banner.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../settings/providers/block_provider.dart';
import '../../../data/repositories/chat_request_repository.dart';
import '../widgets/chat_list_tile.dart';
import '../widgets/mekaar_share_target_dialog.dart';
import '../../../data/services/share_intent_service.dart';
import '../../../core/widgets/mekaar_update_bottom_sheet.dart';
import '../../../core/widgets/mekaar_permissions_bottom_sheet.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../data/services/update_service.dart';
import '../../guardian/widgets/active_trip_card.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  bool _isSearchActive = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedRoomIds = <String>{};
  double _pullProgress = 0.0;
  bool _isRefreshing = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounceTimer;

  // Cache memoization untuk filter room
  int? _lastRoomsSignature;
  List<Map<String, dynamic>>? _cachedFiltered;
  String? _lastSearchQuery;
  Set<String>? _lastBlockedIds;
  Set<String>? _lastCloakedRoomIds;
  Set<String>? _lastCloakedContactUserIds;

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
        r['otherLastReadAt'],
        r['lastMessageSenderId'],
        r['lastMessageIsSending'],
      );
    }
    return hash;
  }

  bool _isShareDialogActive = false;

  void _showShareTargetDialog(SharedPayload payload) {
    if (_isShareDialogActive || !mounted) return;
    _isShareDialogActive = true;
    MekaarShareTargetDialog.show(context, payload).whenComplete(() {
      if (mounted) {
        setState(() => _isShareDialogActive = false);
      } else {
        _isShareDialogActive = false;
      }
      ref.read(sharedPayloadProvider.notifier).clear();
    });
  }

  static bool _permissionPromptShownThisSession = false;
  static bool _updatePromptShownThisSession = false;
  Timer? _vaultDebounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    Future.microtask(() {
      ref.read(chatRoomsProvider.notifier).refreshRooms();
      _checkAndRequestPermissions();
      _checkForAppUpdate();
      final pendingShare = ref.read(sharedPayloadProvider);
      if (pendingShare != null && pendingShare.isNotEmpty) {
        _showShareTargetDialog(pendingShare);
      }
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
          );
        }
      }
    } catch (_) {
      // Abaikan jika offline / koneksi timeout pada silent auto-check
    }
  }

  @override
  void dispose() {
    _vaultDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
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
        MekaarSnackbar.success(context, '$slotName Terbuka');
      }
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

  Future<void> _handleMuteRoom(Map<String, dynamic> room) async {
    final roomId = (room['id'] ?? room['room_id'] ?? '') as String;
    final repo = ref.read(chatRepositoryProvider);
    final prefs = await repo.getRoomPreferences(roomId);
    final currentlyMuted = prefs?.isMuted ?? false;
    await repo.updateRoomMute(roomId, !currentlyMuted);
    if (!mounted) return;
    MekaarSnackbar.info(
      context,
      currentlyMuted ? 'Notifikasi diaktifkan' : 'Notifikasi dibisukan',
    );
    ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  Future<void> _handleMarkAsReadRoom(Map<String, dynamic> room) async {
    final roomId = (room['id'] ?? room['room_id'] ?? '') as String;
    await ref.read(chatActionsProvider).markRoomRead(roomId);
    if (!mounted) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    ref.read(chatRoomsProvider.notifier).refreshRooms();
  }

  bool _isGroupRoom(Map<String, dynamic> room) =>
      room['isGroup'] == true ||
      room['is_group'] == true ||
      room['room_type'] == 'group' ||
      room['type'] == 'group';

  String _roomIdOf(Map<String, dynamic> room) =>
      (room['id'] ?? room['room_id'] ?? '') as String;

  void _enterSelectionMode([String? initialRoomId]) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _isSelectionMode = true;
      _selectedRoomIds.clear();
      if (initialRoomId != null && initialRoomId.isNotEmpty) {
        _selectedRoomIds.add(initialRoomId);
      }
    });
  }

  void _exitSelectionMode() {
    if (!_isSelectionMode && _selectedRoomIds.isEmpty) return;
    setState(() {
      _isSelectionMode = false;
      _selectedRoomIds.clear();
    });
  }

  void _toggleRoomSelection(String roomId) {
    if (roomId.isEmpty) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (_selectedRoomIds.contains(roomId)) {
        _selectedRoomIds.remove(roomId);
        if (_selectedRoomIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedRoomIds.add(roomId);
      }
    });
  }

  void _toggleSelectAllRooms(List<Map<String, dynamic>> visibleRooms) {
    final visibleIds = visibleRooms
        .map(_roomIdOf)
        .where((id) => id.isNotEmpty)
        .toSet();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selectedRoomIds.contains);
    setState(() {
      if (allSelected) {
        _selectedRoomIds.clear();
      } else {
        _selectedRoomIds
          ..clear()
          ..addAll(visibleIds);
      }
    });
  }

  Future<void> _handleBulkMarkAsRead(
    List<Map<String, dynamic>> selectedRooms,
  ) async {
    final targets = selectedRooms.where((room) {
      final unread = (room['unreadCount'] ?? room['unread_count']) as int? ?? 0;
      return unread > 0;
    }).toList();
    if (targets.isEmpty) return;

    final actions = ref.read(chatActionsProvider);
    for (final room in targets) {
      final roomId = _roomIdOf(room);
      if (roomId.isNotEmpty) {
        await actions.markRoomRead(roomId);
      }
    }
    if (!mounted) return;
    _exitSelectionMode();
    ref.read(chatRoomsProvider.notifier).refreshRooms();
    MekaarSnackbar.success(
      context,
      '${targets.length} obrolan ditandai sudah dibaca.',
    );
  }

  Future<void> _handleBulkMute(
    List<Map<String, dynamic>> selectedRooms, {
    required bool mute,
  }) async {
    if (selectedRooms.isEmpty) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      for (final room in selectedRooms) {
        final roomId = _roomIdOf(room);
        if (roomId.isNotEmpty) {
          await repo.updateRoomMute(roomId, mute);
        }
      }
      if (!mounted) return;
      _exitSelectionMode();
      ref.read(chatRoomsProvider.notifier).refreshRooms();
      MekaarSnackbar.info(
        context,
        mute
            ? '${selectedRooms.length} notifikasi obrolan dibisukan.'
            : '${selectedRooms.length} notifikasi obrolan diaktifkan.',
      );
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal memperbarui notifikasi: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  Future<void> _handleBulkArchive(
    List<Map<String, dynamic>> selectedRooms,
  ) async {
    final ids = selectedRooms
        .map(_roomIdOf)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    final repo = ref.read(chatRepositoryProvider);
    for (final roomId in ids) {
      await repo.archiveRoom(roomId);
    }
    if (!mounted) return;
    _exitSelectionMode();
    ref.read(chatRoomsProvider.notifier).refreshRooms();
    MekaarSnackbar.undo(
      context,
      '${ids.length} obrolan diarsipkan',
      onUndo: () async {
        for (final roomId in ids) {
          await repo.unarchiveRoom(roomId);
        }
        ref.read(chatRoomsProvider.notifier).refreshRooms();
      },
    );
  }

  void _confirmBulkDeleteRooms(List<Map<String, dynamic>> selectedRooms) {
    if (selectedRooms.isEmpty) return;
    final hasGroups = selectedRooms.any(_isGroupRoom);
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus ${selectedRooms.length} Obrolan?',
      message:
          'Obrolan terpilih akan dihapus dari daftar pesan Anda.${hasGroups ? ' Untuk grup, Anda tetap menjadi anggota sampai memilih Keluar dari Grup.' : ''}',
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
            final count = selectedRooms.length;
            final isGuest = ref.read(authProvider).isGuestActive;
            if (isGuest) {
              for (final room in selectedRooms) {
                final rId = _roomIdOf(room);
                final isGroup = _isGroupRoom(room);
                final otherUserId =
                    (room['otherUserId'] ?? room['other_user_id']) as String?;
                await VaultIsolationHelper.silentVaultTarget(
                  ref,
                  roomId: rId,
                  contactUserId: isGroup ? null : otherUserId,
                );
              }
              if (!mounted) return;
              _exitSelectionMode();
              MekaarSnackbar.success(context, '$count obrolan dihapus.');
              return;
            }

            final actions = ref.read(chatActionsProvider);
            SharedPreferences? prefs;
            try {
              prefs = await SharedPreferences.getInstance();
            } catch (_) {}

            for (final room in selectedRooms) {
              final rId = _roomIdOf(room);
              if (rId.isEmpty) continue;
              await actions.deleteChat(rId);
              if (prefs != null) {
                try {
                  await prefs.remove('hidden_call_ids_$rId');
                } catch (_) {}
              }
            }
            if (!mounted) return;
            _exitSelectionMode();
            MekaarSnackbar.success(context, '$count obrolan dihapus.');
          },
          child: const Text('Hapus (Hanya Saya)'),
        ),
      ],
    );
  }

  void _confirmLeaveGroupFromList(Map<String, dynamic> room) {
    final roomId = _roomIdOf(room);
    final groupName =
        (room['name'] ?? room['chat_name']) as String? ?? 'Grup';
    final avatarUrl = (room['avatarUrl'] ?? room['avatar_url']) as String?;

    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Keluar dari Grup?',
      message:
          'Apakah Anda yakin ingin keluar dari "$groupName"? Anda tidak akan menerima pesan grup ini lagi.',
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
            if (GuestSessionGuard.isRestrictedSession(ref)) {
              await GuestSessionGuard.triggerSafeSilentClose(ref);
              return;
            }
            try {
              await ref.read(chatRepositoryProvider).leaveGroup(roomId);
              ref.invalidate(chatRoomsProvider);
              if (!mounted) return;
              MekaarSnackbar.info(context, 'Anda telah keluar dari grup.');
            } catch (e) {
              if (!mounted) return;
              final msg = e.toString().replaceAll('Exception: ', '');
              final isOwnerError = msg.toLowerCase().contains('owner') ||
                  msg.toLowerCase().contains('pemilik');
              if (isOwnerError) {
                MekaarDialog.showConfirmation<void>(
                  context: context,
                  title: 'Alihkan Kepemilikan Grup',
                  message:
                      'Anda adalah pemilik grup ini. Silakan alihkan kepemilikan grup ke salah satu anggota di Info Grup terlebih dahulu sebelum keluar.',
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.groupDetails,
                          arguments: {
                            'roomId': roomId,
                            'groupName': groupName,
                            'groupAvatarUrl': avatarUrl,
                          },
                        );
                      },
                      child: const Text('Buka Info Grup'),
                    ),
                  ],
                );
              } else {
                MekaarSnackbar.error(
                  context,
                  'Gagal keluar dari grup: ${ErrorResolver.resolve(e)}',
                );
              }
            }
          },
          child: const Text('Keluar'),
        ),
      ],
    );
  }

  void _showChatTileContextMenu(
    BuildContext context,
    Map<String, dynamic> room,
  ) {
    HapticService.trigger(MekaarHapticIntent.selection);
    final roomId = _roomIdOf(room);
    final chatName =
        (room['name'] ?? room['chat_name']) as String? ?? 'Obrolan';
    final chatAvatar =
        (room['avatar'] as String?) ?? (chatName.isNotEmpty ? chatName[0] : '');
    final chatAvatarUrl = (room['avatarUrl'] ?? room['avatar_url']) as String?;
    final otherUserId =
        (room['otherUserId'] ?? room['other_user_id']) as String?;
    final isGuardian =
        (room['isGuardian'] ?? room['is_guardian']) as bool? ?? false;
    final isGroup = _isGroupRoom(room);
    final isMuted = (room['isMuted'] ?? room['is_muted']) as bool? ?? false;
    final unreadCount =
        (room['unreadCount'] ?? room['unread_count']) as int? ?? 0;

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
                      Row(
                        children: [
                          if (isGroup) ...[
                            const Icon(
                              MekaarIcons.groupsOutline,
                              size: 16,
                              color: MekaarColors.softCoral,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              chatName,
                              style: MekaarTypography.headingSM.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
              leading: const Icon(
                SolarIconsOutline.checkCircle,
                color: AppColors.blue,
              ),
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
            leading: Icon(
              SolarIconsOutline.archive,
              color: MekaarColors.accentTextOf(context),
            ),
            title: const Text('Arsipkan Obrolan'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _handleArchiveRoom(room);
            },
          ),

          // 4. Info Grup / Info Kontak & Pengaturan
          ListTile(
            leading: Icon(
              isGroup
                  ? SolarIconsOutline.usersGroupTwoRounded
                  : SolarIconsOutline.infoCircle,
              color: AppColors.blue,
            ),
            title: Text(
              isGroup
                  ? 'Info & Pengaturan Grup'
                  : 'Info Kontak & Pengaturan',
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              if (isGroup) {
                Navigator.pushNamed(
                  context,
                  AppRoutes.groupDetails,
                  arguments: {
                    'roomId': roomId,
                    'groupName': chatName,
                    'groupAvatarUrl': chatAvatarUrl,
                  },
                );
              } else {
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
              }
            },
          ),

          // 5. Pilih Beberapa (Masuk Mode Multi-Select)
          ListTile(
            leading: Icon(
              SolarIconsOutline.checkSquare,
              color: MekaarColors.textPrimaryOf(context),
            ),
            title: const Text('Pilih Beberapa'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _enterSelectionMode(roomId);
            },
          ),

          const Divider(height: 1),

          // 6. Hapus Obrolan
          ListTile(
            leading: const Icon(
              SolarIconsOutline.trashBinTrash,
              color: MekaarColors.sosRed,
            ),
            title: const Text(
              'Hapus Chat',
              style: TextStyle(
                color: MekaarColors.sosRed,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmDeleteRoom(room);
            },
          ),

          // 7. Keluar dari Grup (Khusus Obrolan Grup)
          if (isGroup)
            ListTile(
              leading: const Icon(
                SolarIconsOutline.logout,
                color: MekaarColors.sosRed,
              ),
              title: const Text(
                'Keluar dari Grup',
                style: TextStyle(
                  color: MekaarColors.sosRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmLeaveGroupFromList(room);
              },
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _handleArchiveRoom(Map<String, dynamic> room) async {
    final roomId = (room['id'] ?? room['room_id'] ?? '') as String;
    final repo = ref.read(chatRepositoryProvider);
    await repo.archiveRoom(roomId);
    if (!mounted) return;
    ref.read(chatRoomsProvider.notifier).refreshRooms();
    MekaarSnackbar.undo(
      context,
      'Chat diarsipkan',
      onUndo: () async {
        await repo.unarchiveRoom(roomId);
        ref.read(chatRoomsProvider.notifier).refreshRooms();
      },
    );
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
            final roomId = _roomIdOf(room);
            final isGroup = _isGroupRoom(room);
            final otherUserId =
                (room['otherUserId'] ?? room['other_user_id']) as String?;

            final isGuest = ref.read(authProvider).isGuestActive;
            if (isGuest) {
              // Silent Vaulting di mode tamu: sembunyikan obrolan ke vault master tanpa menghapus data asli
              await VaultIsolationHelper.silentVaultTarget(
                ref,
                roomId: roomId,
                contactUserId: isGroup ? null : otherUserId,
              );
              if (mounted) {
                MekaarSnackbar.success(context, 'Obrolan berhasil dihapus.');
              }
              return;
            }

            await ref.read(chatActionsProvider).deleteChat(roomId);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('hidden_call_ids_$roomId');
            } catch (_) {}
          },
          child: const Text('Hapus (Hanya Saya)'),
        ),
      ],
    );
  }

  void _showNewChatDialog() {
    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.pushNamed(context, AppRoutes.newChat);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chatRoomsState = ref.watch(chatRoomsProvider);
    final authState = ref.watch(authProvider);
    final wasDuress = authState.lastUnlockWasDuress;

    final archivedUnreadCount = chatRoomsState.maybeWhen(
      data: (rooms) {
        final cloakedRooms = ref.watch(cloakedRoomIdsProvider);
        final cloakedContacts = ref.watch(cloakedContactUserIdsProvider);
        return rooms.where((room) {
          final isArchived = room['isArchived'] as bool? ?? false;
          if (!isArchived) return false;
          final roomId = room['id'] as String;
          final otherUserId = room['otherUserId'] as String?;
          if (cloakedRooms.contains(roomId)) return false;
          if (otherUserId != null && cloakedContacts.contains(otherUserId)) {
            return false;
          }
          return true;
        }).fold<int>(0, (sum, room) => sum + ((room['unreadCount'] as int?) ?? 0));
      },
      orElse: () => 0,
    );

    ref.listen<SharedPayload?>(sharedPayloadProvider, (prev, next) {
      if (next != null && next.isNotEmpty && mounted) {
        _showShareTargetDialog(next);
      }
    });

    final visibleRooms = chatRoomsState.maybeWhen(
      data: _computeVisibleRooms,
      orElse: () => const <Map<String, dynamic>>[],
    );
    final selectedRooms = _isSelectionMode
        ? visibleRooms
            .where((r) => _selectedRoomIds.contains(_roomIdOf(r)))
            .toList()
        : const <Map<String, dynamic>>[];
    final allVisibleSelected = _isSelectionMode &&
        visibleRooms.isNotEmpty &&
        visibleRooms.every((r) => _selectedRoomIds.contains(_roomIdOf(r)));
    final hasSelectedUnread = selectedRooms.any(
      (r) => ((r['unreadCount'] ?? r['unread_count']) as int? ?? 0) > 0,
    );
    final allSelectedMuted = selectedRooms.isNotEmpty &&
        selectedRooms.every(
          (r) => (r['isMuted'] ?? r['is_muted']) as bool? ?? false,
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (_isSelectionMode)
                  MekaarSelectionHeader(
                    key: const ValueKey('chat_list_selection_header'),
                    selectedCount: _selectedRoomIds.length,
                    allSelected: allVisibleSelected,
                    onClose: _exitSelectionMode,
                    onToggleSelectAll: () =>
                        _toggleSelectAllRooms(visibleRooms),
                    actions: [
                      MekaarSelectionAction(
                        key: const ValueKey('chat_bulk_delete_btn'),
                        icon: SolarIconsOutline.trashBinTrash,
                        label: 'Hapus',
                        tooltip: 'Hapus Obrolan',
                        isDestructive: true,
                        onPressed: selectedRooms.isEmpty
                            ? null
                            : () => _confirmBulkDeleteRooms(selectedRooms),
                      ),
                      MekaarSelectionAction(
                        key: const ValueKey('chat_bulk_archive_btn'),
                        icon: SolarIconsOutline.archive,
                        label: 'Arsipkan',
                        tooltip: 'Arsipkan Obrolan',
                        onPressed: selectedRooms.isEmpty
                            ? null
                            : () => _handleBulkArchive(selectedRooms),
                      ),
                      MekaarSelectionAction(
                        key: const ValueKey('chat_bulk_mute_btn'),
                        icon: allSelectedMuted
                            ? SolarIconsOutline.bell
                            : SolarIconsOutline.bellOff,
                        label: allSelectedMuted
                            ? 'Bunyikan Notifikasi'
                            : 'Bisukan Notifikasi',
                        tooltip: allSelectedMuted
                            ? 'Bunyikan Notifikasi'
                            : 'Bisukan Notifikasi',
                        onPressed: selectedRooms.isEmpty
                            ? null
                            : () => _handleBulkMute(
                                  selectedRooms,
                                  mute: !allSelectedMuted,
                                ),
                      ),
                      if (hasSelectedUnread)
                        MekaarSelectionAction(
                          key: const ValueKey('chat_bulk_mark_read_btn'),
                          icon: SolarIconsOutline.checkCircle,
                          label: 'Tandai Dibaca',
                          tooltip: 'Tandai Sudah Dibaca',
                          onPressed: () => _handleBulkMarkAsRead(selectedRooms),
                        ),
                    ],
                  )
                else
                  MekaarTabHeader(
                    key: const ValueKey('chat_list_tab_header'),
                    title: 'Mekaar',
                    isSearchActive: _isSearchActive,
                    isSubHeaderSearch: true,
                    pullProgress: _pullProgress,
                    isRefreshing: _isRefreshing,
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onSearchChanged: (value) {
                      _searchDebounceTimer?.cancel();
                      _searchDebounceTimer = Timer(
                        const Duration(milliseconds: 180),
                        () {
                          if (mounted && _searchQuery != value) {
                            setState(() => _searchQuery = value);
                          }
                        },
                      );
                      _vaultDebounceTimer?.cancel();
                      if (value.trim().length >= 4) {
                        _vaultDebounceTimer = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            _checkVaultPasscode(value);
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
                    action: (wasDuress || authState.isDuressActive)
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MekaarHeaderSearchButton(
                                isSearchActive: _isSearchActive,
                                pullProgress: _pullProgress,
                                tooltip: 'Cari Obrolan',
                                onPressed: () {
                                  setState(() => _isSearchActive = true);
                                },
                              ),
                              Badge.count(
                                count: archivedUnreadCount,
                                isLabelVisible: archivedUnreadCount > 0,
                                backgroundColor: MekaarColors.accentOf(context),
                                textColor: MekaarColors.textOnBlue,
                                child: IconButton(
                                  icon: Icon(
                                    SolarIconsOutline.archiveCheck,
                                    color: MekaarColors.textPrimaryOf(context),
                                  ),
                                  tooltip: 'Arsip Percakapan',
                                  onPressed: () {
                                    HapticService.trigger(
                                      MekaarHapticIntent.selection,
                                    );
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.archivedChats,
                                    );
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  SolarIconsOutline.safeSquare,
                                  color: MekaarColors.textPrimaryOf(context),
                                ),
                                tooltip: MekaarCopy.vaultTitle,
                                onPressed: () async {
                                  HapticService.trigger(
                                    MekaarHapticIntent.selection,
                                  );
                                  final authState = ref.read(authProvider);
                                  final isVaultPinEnabled =
                                      ref.read(vaultPinLockEnabledProvider);
                                  final canBypassPin = !isVaultPinEnabled &&
                                      authState.vaultSpace ==
                                          VaultSpace.master &&
                                      !authState.isDecoyActive &&
                                      !authState.isDuressActive;

                                  if (canBypassPin) {
                                    final unlockedKey = await DatabaseKeyService
                                        .instance
                                        .unlockMasterVaultFromKeystore();
                                    if (unlockedKey != null) {
                                      try {
                                        await LocalVaultDatabase.instance
                                            .openVault(
                                          key: unlockedKey,
                                          space: VaultSpace.master,
                                        );
                                        if (context.mounted) {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.vault,
                                          );
                                        }
                                        return;
                                      } catch (_) {}
                                    }
                                  }

                                  if (!context.mounted) return;
                                  final verified =
                                      await MekaarPinVerificationSheet.verify(
                                    context,
                                    title: MekaarCopy.vaultVerifyTitle,
                                    subtitle: MekaarCopy.vaultVerifySubtitle,
                                    bindToActiveSession: true,
                                  );
                                  if (verified && context.mounted) {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.vault,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                  ),
                // Banner Darurat SOS untuk Guardian (jika orang yang dijaga dalam bahaya)
                const GuardianSOSAlertBanner(),
                // Chat Requests Banner (jika ada permintaan pending)
                Consumer(
                  builder: (context, ref, _) {
                    final count =
                        ref
                            .watch(pendingRequestsCountStreamProvider)
                            .valueOrNull ??
                        0;
                    if (count == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.chatRequests,
                        ),
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        child: MekaarBanner(
                          color: AppColors.blue,
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          icon: SolarIconsOutline.userPlus,
                          content: Text(
                            '$count Permintaan Chat Masuk Baru',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.blue,
                            ),
                          ),
                          action: const Icon(
                            SolarIconsOutline.altArrowRight,
                            size: 16,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final isSosEnabled = ref.watch(sosFeatureEnabledProvider);
                    if (!isSosEnabled) return const SizedBox.shrink();
                    return const ActiveTripCard(
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    );
                  },
                ),
                // Chat List Content
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
                      if (_isRefreshing != r) {
                        setState(() => _isRefreshing = r);
                      }
                    },
                    onRefresh: () =>
                        ref.read(chatRoomsProvider.notifier).refreshRooms(),
                    child: chatRoomsState.when(
                      data: (_) => _buildChatList(visibleRooms),
                      loading: () => const ChatListSkeleton(),
                      error: (err, stack) => Center(
                        child: MekaarStateView(
                          illustration: ErrorResolver.resolveIllustration(err),
                          stateIcon:
                              ErrorResolver.resolveIllustration(err) == null
                              ? ErrorResolver.resolveIcon(err)
                              : null,
                          stateIconColor: ErrorResolver.resolveIconColor(
                            err,
                            context,
                          ),
                          title: 'Gagal Memuat Chat',
                          message: ErrorResolver.resolve(err),
                          actionLabel: 'Coba Lagi',
                          onAction: () => ref
                              .read(chatRoomsProvider.notifier)
                              .refreshRooms(),
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
      floatingActionButton: _isSelectionMode
          ? null
          : Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
        ).copyWith(bottom: 90),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pushNamed(context, AppRoutes.newChat);
                  },
                  child: const Center(
                    child: Icon(
                      MekaarIcons.newChat,
                      color: Colors.white,
                      size: 24,
                    ),
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

  DateTime _extractRoomTimestamp(dynamic timestamp) {
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      return DateTime.tryParse(timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _computeVisibleRooms(
    List<Map<String, dynamic>> rooms,
  ) {
    // Sembunyikan chat dengan pengguna yang diblokir oleh pengguna saat ini.
    final blockedIds = ref
        .watch(blockProvider)
        .maybeWhen(
          data: (list) => list.map((b) => b.blockedId).toSet(),
          orElse: () => <String>{},
        );

    final cloakedRoomIds = ref.watch(cloakedRoomIdsProvider);
    final cloakedContactUserIds = ref.watch(cloakedContactUserIdsProvider);

    // Memoized filter rooms by query, blocked IDs, and hidden vault state
    final roomsSignature = _computeRoomsSignature(rooms);
    final bool isCacheValid =
        _cachedFiltered != null &&
        _lastRoomsSignature == roomsSignature &&
        _lastSearchQuery == _searchQuery &&
        setEquals(_lastBlockedIds, blockedIds) &&
        setEquals(_lastCloakedRoomIds, cloakedRoomIds) &&
        setEquals(_lastCloakedContactUserIds, cloakedContactUserIds);

    if (isCacheValid) {
      return _cachedFiltered!;
    }

    // 1. Unifikasi 1 Kontak = 1 Percakapan untuk direct chats (mencegah duplikasi entri seperti Thole normal vs guardian)
    final Map<String, Map<String, dynamic>> unifiedByOtherUser = {};
    final List<Map<String, dynamic>> nonDirectRooms = [];

    for (final room in rooms) {
      final otherUserId = room['otherUserId'] as String?;
      final isGroup = _isGroupRoom(room);

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
          final dominantRoom = roomTime.isAfter(existingTime)
              ? room
              : existing;
          final isGuardian =
              (existing['isGuardian'] == true) ||
              (room['isGuardian'] == true);
          final totalUnread =
              (existing['unreadCount'] as int? ?? 0) +
              (room['unreadCount'] as int? ?? 0);
          final isArchived =
              (existing['isArchived'] == true) &&
              (room['isArchived'] == true);

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

    final filtered = unifiedRooms.where((room) {
      final roomId = _roomIdOf(room);
      final name = (room['name'] ?? room['chat_name'] ?? 'Obrolan') as String;
      final username = room['otherUsername'] as String? ?? '';
      final email = room['otherEmail'] as String? ?? '';
      final otherUserId =
          (room['otherUserId'] ?? room['other_user_id']) as String?;

      // 1. Jangan tampilkan chat dengan pengguna yang diblokir.
      if (otherUserId != null && blockedIds.contains(otherUserId)) {
        return false;
      }

      // 2. Cloaking Private Vault terisolasi: Sembunyikan obrolan jika kontak/room terselubung
      if (cloakedRoomIds.contains(roomId)) return false;
      if (otherUserId != null &&
          cloakedContactUserIds.contains(otherUserId)) {
        return false;
      }

      final query = _searchQuery.toLowerCase();
      final matchQuery =
          name.toLowerCase().contains(query) ||
          username.toLowerCase().contains(query) ||
          email.toLowerCase().contains(query);

      if (!matchQuery) return false;

      // Inbox utama: tampilkan semua obrolan aktif yang tidak diarsipkan
      final isArchived = room['isArchived'] as bool? ?? false;
      return !isArchived;
    }).toList();

    _lastRoomsSignature = roomsSignature;
    _cachedFiltered = filtered;
    _lastSearchQuery = _searchQuery;
    _lastBlockedIds = Set<String>.from(blockedIds);
    _lastCloakedRoomIds = Set<String>.from(cloakedRoomIds);
    _lastCloakedContactUserIds = Set<String>.from(cloakedContactUserIds);
    return filtered;
  }

  Widget _buildChatList(List<Map<String, dynamic>> filtered) {
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final contactsList =
        ref.watch(userContactsProvider).valueOrNull ?? const <ContactItem>[];
    final vaultedContactIds = contactsList
        .where((c) => c.isVaulted)
        .map((c) => c.contactUserId)
        .toSet();

    if (filtered.isEmpty) {
      final hasSearch = _searchQuery.trim().isNotEmpty;
      final MikaIllustrationType emptyIllustration = hasSearch
          ? MikaIllustrationType.emptySearch
          : MikaIllustrationType.emptyChat;

      return _EmptyChats(
        onStart: _showNewChatDialog,
        illustration: emptyIllustration,
        title: hasSearch ? 'Tidak Ditemukan' : 'Belum Ada Obrolan',
        message: hasSearch
            ? 'Tidak ada percakapan yang cocok dengan "${_searchQuery.trim()}".'
            : 'Mulai obrolan baru dengan kontak atau bagikan kode QR.',
        showStartButton: !hasSearch,
        searchQuery: hasSearch ? _searchQuery.trim() : null,
      );
    }

    final hasSearch = _searchQuery.trim().isNotEmpty;

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 110),
      itemCount: filtered.length + (hasSearch ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.messageSearch,
                  arguments: {'initialQuery': _searchQuery.trim()},
                );
              },
              borderRadius: BorderRadius.circular(MekaarRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: MekaarColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(MekaarRadius.md),
                  border: Border.all(
                    color: MekaarColors.borderOf(
                      context,
                    ).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.minimalisticMagnifier,
                      size: 18,
                      color: MekaarColors.primaryOf(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cari "${_searchQuery.trim()}" di seluruh isi pesan...',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.primaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      SolarIconsOutline.altArrowRight,
                      size: 16,
                      color: MekaarColors.primaryOf(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final room = filtered[index];
        final roomId = (room['id'] ?? room['room_id'] ?? '') as String;
        final otherUserId =
            (room['otherUserId'] ?? room['other_user_id']) as String?;
        final isHidden =
            hiddenRoomIds.contains(roomId) ||
            (otherUserId != null &&
                (hiddenContactUserIds.contains(otherUserId) ||
                    vaultedContactIds.contains(otherUserId)));

        final isLastItem = index == filtered.length - 1 && !hasSearch;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatListTile(
              room: room,
              isHidden: isHidden,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedRoomIds.contains(roomId),
              onTap: () {
                if (_isSelectionMode) {
                  _toggleRoomSelection(roomId);
                  return;
                }
                final chatName =
                    (room['name'] ?? room['chat_name']) as String? ??
                    'Obrolan';
                final chatAvatar =
                    (room['avatar'] as String?) ??
                    (chatName.isNotEmpty ? chatName[0] : '💬');
                final isGroup = _isGroupRoom(room);
                Navigator.pushNamed(
                  context,
                  AppRoutes.chat,
                  arguments: {
                    'chatId': roomId,
                    'chatName': chatName,
                    'chatAvatar': chatAvatar,
                    'chatAvatarUrl':
                        (room['avatarUrl'] ?? room['avatar_url'])
                            as String?,
                    'isGuardian':
                        (room['isGuardian'] ?? room['is_guardian'])
                            as bool? ??
                        false,
                    'isGroup': isGroup,
                    'otherUserId': isGroup ? null : otherUserId,
                    'initialLastReadAt': room['lastReadAt'] as DateTime?,
                  },
                );
              },
              onLongPress: () {
                if (_isSelectionMode) {
                  _toggleRoomSelection(roomId);
                  return;
                }
                _showChatTileContextMenu(context, room);
              },
              onMarkRead: () => _handleMarkAsReadRoom(room),
              onMute: () => _handleMuteRoom(room),
              onDelete: () => _confirmDeleteRoom(room),
              onArchive: () => _handleArchiveRoom(room),
            ),
            if (!isLastItem)
              Divider(
                height: 1,
                thickness: 0.8,
                indent: 76,
                endIndent: 0,
                color: MekaarColors.borderOf(
                  context,
                ).withValues(alpha: 0.35),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final VoidCallback onStart;
  final MikaIllustrationType illustration;
  final String title;
  final String message;
  final bool showStartButton;
  final String? searchQuery;

  const _EmptyChats({
    required this.onStart,
    this.illustration = MikaIllustrationType.emptyChat,
    required this.title,
    required this.message,
    required this.showStartButton,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery != null && searchQuery!.isNotEmpty;

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
              if (hasSearch) ...[
                const SizedBox(height: MekaarSpacing.xl),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.messageSearch,
                      arguments: {'initialQuery': searchQuery},
                    );
                  },
                  icon: const Icon(
                    SolarIconsOutline.minimalisticMagnifier,
                    size: 18,
                  ),
                  label: const Text('Cari di Seluruh Isi Pesan'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
