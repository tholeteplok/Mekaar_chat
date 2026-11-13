import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/add_group_members_sheet.dart';
import '../widgets/chat_room_privacy_sheet.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String groupName;
  final String? groupAvatarUrl;

  const GroupDetailsScreen({
    super.key,
    required this.roomId,
    required this.groupName,
    this.groupAvatarUrl,
  });

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  Map<String, dynamic>? _groupData;
  List<dynamic> _participants = [];
  bool _isLoading = true;
  bool _isMuted = false;
  String _memberSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _groupData = {
      'id': widget.roomId,
      'name': widget.groupName,
      'avatar_url': widget.groupAvatarUrl,
    };
    _loadDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final details = await chatRepo.getGroupDetails(widget.roomId);
      final prefs = await chatRepo.getRoomPreferences(widget.roomId);
      if (mounted) {
        setState(() {
          if (details != null) {
            _groupData = details['room'] as Map<String, dynamic>? ?? _groupData;
            _participants = (details['participants'] as List?) ?? [];
          }
          if (prefs != null) {
            _isMuted = prefs.isMuted;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal menyinkronkan detail grup.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? get _currentUserId =>
      ref.read(authProvider).user?.id ??
      ref.read(authProvider).profile?.id ??
      ref.read(chatRepositoryProvider).currentUserId;

  String get _currentUserRole {
    for (final p in _participants) {
      if (p['profile_id'] == _currentUserId) {
        return p['role'] as String? ?? 'member';
      }
    }
    return 'member';
  }

  bool get _isOwner => _currentUserRole == 'owner';
  bool get _isAdmin => _currentUserRole == 'admin' || _isOwner;
  bool get _membersCanEditInfo =>
      _groupData?['members_can_edit_info'] as bool? ?? false;
  bool get _membersCanInvite =>
      _groupData?['members_can_invite'] as bool? ?? false;
  bool get _isAnnouncementOnly =>
      _groupData?['is_announcement_only'] as bool? ?? false;

  bool get _canEditGroupInfo => _isAdmin || _membersCanEditInfo;
  bool get _canInviteMembers => _isAdmin || _membersCanInvite;

  Future<void> _toggleMute(bool muted) async {
    final prev = _isMuted;
    setState(() => _isMuted = muted);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateRoomMute(widget.roomId, muted);
      if (mounted) {
        MekaarSnackbar.info(
          context,
          muted ? 'Notifikasi grup dibisukan.' : 'Notifikasi grup dibunyikan.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isMuted = prev);
        MekaarSnackbar.error(context, 'Gagal mengubah status notifikasi.');
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (!_canEditGroupInfo) return;
    HapticService.trigger(MekaarHapticIntent.selection);

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    try {
      MekaarSnackbar.info(context, 'Mengunggah foto grup...');
      final chatRepo = ref.read(chatRepositoryProvider);
      final publicUrl = await chatRepo.uploadGroupAvatar(
        File(image.path),
        widget.roomId,
      );

      if (publicUrl != null) {
        await chatRepo.updateGroupInfo(
          roomId: widget.roomId,
          avatarUrl: publicUrl,
        );
        await _loadDetails();
        if (mounted) {
          MekaarSnackbar.success(context, 'Foto grup berhasil diperbarui!');
        }
      }
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mengunggah foto grup.');
      }
    }
  }

  Future<void> _editGroupInfoDialog() async {
    if (!_canEditGroupInfo) return;
    final currentName = _groupData?['name'] as String? ?? widget.groupName;
    final currentDesc = _groupData?['description'] as String? ?? '';

    final nameController = TextEditingController(text: currentName);
    final descController = TextEditingController(text: currentDesc);

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MekaarColors.surfaceOf(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        title: const Text('Edit Info Grup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Grup',
                  hintText: 'Masukkan nama grup',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Grup (Opsional)',
                  hintText: 'Tambahkan deskripsi atau topik grup...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      final newName = nameController.text.trim();
      final newDesc = descController.text.trim();
      if (newName.isEmpty) {
        MekaarSnackbar.error(context, 'Nama grup tidak boleh kosong.');
        return;
      }
      try {
        await ref.read(chatRepositoryProvider).updateGroupInfo(
              roomId: widget.roomId,
              name: newName,
              description: newDesc,
            );
        await _loadDetails();
        if (mounted) {
          MekaarSnackbar.success(context, 'Info grup berhasil diperbarui.');
        }
      } catch (_) {
        if (mounted) {
          MekaarSnackbar.error(context, 'Gagal memperbarui info grup.');
        }
      }
    }
  }

  Future<void> _updatePermission({
    bool? isAnnouncementOnly,
    bool? membersCanEditInfo,
    bool? membersCanInvite,
  }) async {
    if (!_isAdmin) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    try {
      await ref.read(chatRepositoryProvider).updateGroupPermissions(
            roomId: widget.roomId,
            isAnnouncementOnly: isAnnouncementOnly ?? _isAnnouncementOnly,
            membersCanEditInfo: membersCanEditInfo ?? _membersCanEditInfo,
            membersCanInvite: membersCanInvite ?? _membersCanInvite,
          );
      await _loadDetails();
      if (mounted) {
        MekaarSnackbar.success(context, 'Pengaturan grup diperbarui.');
      }
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal mengubah pengaturan grup.');
      }
    }
  }

  void _openAddMembers() async {
    if (!_canInviteMembers) {
      MekaarSnackbar.info(
        context,
        'Hanya admin yang dapat menambah anggota grup ini.',
      );
      return;
    }
    final existingIds = _participants
        .map<String>((p) => p['profile_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final added = await AddGroupMembersSheet.show(
      context,
      roomId: widget.roomId,
      existingMemberUserIds: existingIds,
    );
    if (added == true) {
      _loadDetails();
    }
  }

  Future<void> _showMemberOptionsSheet(Map<String, dynamic> participant) async {
    final targetUserId = participant['profile_id'] as String;
    final targetRole = participant['role'] as String? ?? 'member';
    final profile = participant['public_profiles'] as Map<String, dynamic>? ?? {};
    final targetName = (profile['display_name'] as String?)?.isNotEmpty == true
        ? profile['display_name'] as String
        : profile['full_name'] as String? ??
            profile['username'] as String? ??
            'Anggota';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(ctx),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MekaarRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Member Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Avatar(
                      size: 48,
                      imageUrl: profile['avatar_url'] as String?,
                      initial: targetName.isNotEmpty ? targetName[0] : 'A',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetName,
                            style: MekaarTypography.headingMD.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            targetRole == 'owner'
                                ? 'Pemilik Grup'
                                : targetRole == 'admin'
                                    ? 'Admin Grup'
                                    : 'Anggota Grup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: targetRole == 'owner'
                                  ? MekaarColors.warnAmber
                                  : targetRole == 'admin'
                                      ? AppColors.blue
                                      : MekaarColors.textMutedOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const MekaarCardDivider(),

              // 1. Direct Chat
              ListTile(
                leading: const Icon(SolarIconsOutline.chatRoundDots, size: 22),
                title: Text('Kirim Pesan Pribadi ke $targetName'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final chatRepo = ref.read(chatRepositoryProvider);
                    final dmRoomId = await chatRepo.createRoom(
                      targetUserId,
                      'normal',
                    );
                    if (mounted) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.chat,
                        arguments: {
                          'chatId': dmRoomId,
                          'chatName': targetName,
                          'chatAvatar':
                              targetName.isNotEmpty ? targetName[0] : 'K',
                          'otherUserId': targetUserId,
                          'isGroup': false,
                        },
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      MekaarSnackbar.error(
                        context,
                        'Gagal membuka obrolan pribadi.',
                      );
                    }
                  }
                },
              ),

              // 2. Owner-only actions
              if (_isOwner) ...[
                if (targetRole == 'member')
                  ListTile(
                    leading: const Icon(
                      SolarIconsOutline.shieldCheck,
                      color: AppColors.blue,
                      size: 22,
                    ),
                    title: const Text('Jadikan Admin'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .promoteGroupAdmin(widget.roomId, targetUserId);
                        await _loadDetails();
                        if (mounted) {
                          MekaarSnackbar.success(
                            context,
                            '$targetName sekarang adalah Admin.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          MekaarSnackbar.error(
                            context,
                            'Gagal mengangkat Admin.',
                          );
                        }
                      }
                    },
                  ),
                if (targetRole == 'admin')
                  ListTile(
                    leading: const Icon(
                      SolarIconsOutline.shieldCross,
                      color: MekaarColors.warnAmber,
                      size: 22,
                    ),
                    title: const Text('Turunkan dari Admin'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .demoteGroupAdmin(widget.roomId, targetUserId);
                        await _loadDetails();
                        if (mounted) {
                          MekaarSnackbar.info(
                            context,
                            'Hak Admin $targetName telah dicabut.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          MekaarSnackbar.error(
                            context,
                            'Gagal mencabut hak Admin.',
                          );
                        }
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    SolarIconsOutline.crown,
                    color: MekaarColors.warnAmber,
                    size: 22,
                  ),
                  title: const Text('Jadikan Pemilik Grup (Transfer)'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => MekaarDialog(
                        title: 'Alihkan Kepemilikan Grup?',
                        message:
                            'Anda akan mengalihkan hak pemilik grup kepada $targetName. Peran Anda akan berubah menjadi Admin.',
                        isDestructive: false,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MekaarColors.warnAmber,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Alihkan'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .transferGroupOwnership(
                              widget.roomId,
                              targetUserId,
                            );
                        await _loadDetails();
                        if (mounted) {
                          MekaarSnackbar.success(
                            context,
                            'Kepemilikan grup berhasil dialihkan ke $targetName.',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          MekaarSnackbar.error(
                            context,
                            'Gagal mengalihkan kepemilikan.',
                          );
                        }
                      }
                    }
                  },
                ),
              ],

              // 3. Remove Member (Owner can kick anyone non-owner; Admin can kick normal members)
              if ((_isOwner && targetRole != 'owner') ||
                  (_isAdmin && !_isOwner && targetRole == 'member'))
                ListTile(
                  leading: const Icon(
                    SolarIconsOutline.userCross,
                    color: MekaarColors.sosRed,
                    size: 22,
                  ),
                  title: Text(
                    'Keluarkan dari Grup',
                    style: TextStyle(
                      color: MekaarColors.sosRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => MekaarDialog(
                        title: 'Keluarkan Anggota?',
                        message:
                            'Apakah Anda yakin ingin mengeluarkan $targetName dari grup ini?',
                        isDestructive: true,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MekaarColors.sosRed,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Keluarkan'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .removeGroupParticipant(
                              widget.roomId,
                              targetUserId,
                            );
                        await _loadDetails();
                        if (mounted) {
                          MekaarSnackbar.info(
                            context,
                            '$targetName telah dikeluarkan dari grup.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          MekaarSnackbar.error(
                            context,
                            'Gagal mengeluarkan anggota.',
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    HapticService.trigger(MekaarHapticIntent.selection);

    // Proteksi Opsi 1: Jika Owner dan masih ada peserta lain, wajib alihkan kepemilikan dulu!
    if (_isOwner) {
      final otherActiveCount = _participants
          .where((p) => p['profile_id'] != _currentUserId)
          .length;
      if (otherActiveCount > 0) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => MekaarDialog(
            title: 'Alihkan Kepemilikan Terlebih Dahulu',
            message:
                'Anda adalah pemilik grup ini. Silakan alihkan kepemilikan grup ke salah satu anggota terlebih dahulu sebelum keluar.',
            isDestructive: false,
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        title: 'Keluar dari Grup?',
        message: 'Apakah Anda yakin ingin keluar dari "${widget.groupName}"?',
        isDestructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.leaveGroup(widget.roomId);
        ref.invalidate(chatRoomsProvider);
        if (mounted) {
          MekaarSnackbar.info(context, 'Anda telah keluar dari grup.');
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          MekaarSnackbar.error(
            context,
            'Gagal keluar dari grup: ${e.toString().replaceAll('Exception: ', '')}',
          );
        }
      }
    }
  }

  Future<void> _disbandGroup() async {
    if (!_isOwner) return;
    HapticService.trigger(MekaarHapticIntent.selection);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        title: 'Bubarkan Grup Permanen?',
        message:
            'Grup "${widget.groupName}" akan dibubarkan secara permanen dan seluruh anggota akan dikeluarkan. Tindakan ini tidak dapat dibatalkan.',
        isDestructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bubarkan Grup'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.disbandGroup(widget.roomId);
        ref.invalidate(chatRoomsProvider);
        if (mounted) {
          MekaarSnackbar.info(context, 'Grup telah dibubarkan.');
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (_) {
        if (mounted) {
          MekaarSnackbar.error(context, 'Gagal membubarkan grup.');
        }
      }
    }
  }

  Widget _buildActionHubItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
  }) {
    final isDark = MekaarColors.isDarkContext(context);
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.65);
    final glassBorder = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.07),
      width: 1.0,
    );

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MekaarGlassBlurContainer(
            isFloating: true,
            height: 52,
            borderRadius: BorderRadius.circular(MekaarRadius.lg),
            padding: EdgeInsets.zero,
            border: glassBorder,
            customColor: isActive
                ? AppColors.blue.withValues(alpha: 0.20)
                : glassBg,
            child: InkWell(
              borderRadius: BorderRadius.circular(MekaarRadius.lg),
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor ??
                      (isActive
                          ? AppColors.blue
                          : MekaarColors.textPrimaryOf(context)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: MekaarTypography.labelSM.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppColors.blue
                  : MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _groupData?['name'] as String? ?? widget.groupName;
    final description = _groupData?['description'] as String? ?? '';
    final avatarUrl =
        _groupData?['avatar_url'] as String? ?? widget.groupAvatarUrl;

    final filteredParticipants = _participants.where((p) {
      if (_memberSearchQuery.isEmpty) return true;
      final profile = p['public_profiles'] as Map<String, dynamic>? ?? {};
      final displayName =
          (profile['display_name'] as String?)?.toLowerCase() ?? '';
      final fullName = (profile['full_name'] as String?)?.toLowerCase() ?? '';
      final username = (profile['username'] as String?)?.toLowerCase() ?? '';
      final q = _memberSearchQuery.toLowerCase();
      return displayName.contains(q) ||
          fullName.contains(q) ||
          username.contains(q);
    }).toList();

    return MekaarScaffold(
      flat: true,
      appBar: MekaarTopBar(
        title: 'Info Grup',
        subtitle: '${_participants.length} Anggota',
      ),
      body: _isLoading
          ? const MekaarStateView(
              pose: MikaPose.hi,
              title: 'Memuat Detail Grup',
              message: 'Mengambil informasi dan anggota grup...',
              semanticLabel: 'Memuat detail grup',
            )
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                // ──── 1. Header Profil Grup Interaktif ────
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Avatar(
                            size: 88,
                            imageUrl: avatarUrl,
                            initial: name.isNotEmpty ? name[0] : 'G',
                            heroTag: 'avatar-room-${widget.roomId}',
                          ),
                          if (_canEditGroupInfo)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: MekaarColors.surfaceOf(context),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    SolarIconsBold.camera,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: MekaarTypography.headingMD.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: MekaarColors.textPrimaryOf(context),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_canEditGroupInfo) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _editGroupInfoDialog,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    SolarIconsOutline.pen,
                                    size: 16,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dibuat untuk koordinasi & keamanan',
                        style: TextStyle(
                          fontSize: 12,
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                      if (description.isNotEmpty || _canEditGroupInfo) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: InkWell(
                            onTap: _canEditGroupInfo
                                ? _editGroupInfoDialog
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                description.isNotEmpty
                                    ? description
                                    : 'Tambahkan deskripsi atau catatan grup...',
                                style: MekaarTypography.bodySM.copyWith(
                                  color: description.isNotEmpty
                                      ? MekaarColors.textSecondaryOf(context)
                                      : MekaarColors.textMutedOf(context),
                                  fontStyle: description.isNotEmpty
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ──── 2. Quick Action Hub (Cari, Mute, Tambah, Privasi) ────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildActionHubItem(
                        icon: SolarIconsOutline.magnifier,
                        label: 'Cari',
                        onTap: () => Navigator.pop(context, 'search'),
                      ),
                      const SizedBox(width: 10),
                      _buildActionHubItem(
                        icon: _isMuted
                            ? SolarIconsBold.bellOff
                            : SolarIconsOutline.bell,
                        label: _isMuted ? 'Dibisukan' : 'Bisukan',
                        isActive: _isMuted,
                        iconColor: _isMuted ? MekaarColors.warnAmber : null,
                        onTap: () => _toggleMute(!_isMuted),
                      ),
                      if (_canInviteMembers) ...[
                        const SizedBox(width: 10),
                        _buildActionHubItem(
                          icon: SolarIconsOutline.userPlus,
                          label: 'Tambah',
                          onTap: _openAddMembers,
                        ),
                      ],
                      const SizedBox(width: 10),
                      _buildActionHubItem(
                        icon: SolarIconsBold.shieldKeyhole,
                        label: 'Privasi',
                        iconColor: AppColors.blue,
                        onTap: () {
                          ChatRoomPrivacySheet.show(
                            context,
                            roomId: widget.roomId,
                            isGroup: true,
                            onSettingsChanged: _loadDetails,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ──── 3. Card Pengaturan & Izin Grup (Khusus Admin/Owner) ────
                if (_isAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Izin & Tata Kelola Grup',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: MekaarColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(MekaarRadius.lg),
                        border: Border.all(
                          color: MekaarColors.borderOf(
                            context,
                          ).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(
                              SolarIconsBold.volumeLoud,
                              color: AppColors.blue,
                            ),
                            title: const Text(
                              'Mode Siaran Darurat',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Hanya admin yang dapat mengirim pesan di grup ini',
                              style: TextStyle(
                                fontSize: 12,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            value: _isAnnouncementOnly,
                            activeTrackColor: AppColors.blue,
                            onChanged: (val) =>
                                _updatePermission(isAnnouncementOnly: val),
                          ),
                          const MekaarCardDivider(),
                          SwitchListTile(
                            secondary: const Icon(
                              SolarIconsOutline.pen,
                              color: AppColors.blue,
                            ),
                            title: const Text(
                              'Edit Info Grup',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Izinkan anggota biasa mengubah nama, foto & deskripsi',
                              style: TextStyle(
                                fontSize: 12,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            value: _membersCanEditInfo,
                            activeTrackColor: AppColors.blue,
                            onChanged: (val) =>
                                _updatePermission(membersCanEditInfo: val),
                          ),
                          const MekaarCardDivider(),
                          SwitchListTile(
                            secondary: const Icon(
                              SolarIconsOutline.userPlus,
                              color: AppColors.blue,
                            ),
                            title: const Text(
                              'Tambah Anggota',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Izinkan anggota biasa mengundang kontak lain ke grup',
                              style: TextStyle(
                                fontSize: 12,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            value: _membersCanInvite,
                            activeTrackColor: AppColors.blue,
                            onChanged: (val) =>
                                _updatePermission(membersCanInvite: val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ──── 4. Daftar Anggota Grup ────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Anggota (${_participants.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                      if (_canInviteMembers)
                        InkWell(
                          onTap: _openAddMembers,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  SolarIconsOutline.userPlus,
                                  size: 14,
                                  color: AppColors.blue,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Tambah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_participants.length >= 5) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: MekaarSearchField(
                      controller: _searchController,
                      hintText: 'Cari nama anggota...',
                      onChanged: (val) {
                        setState(() => _memberSearchQuery = val.trim());
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: MekaarColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(MekaarRadius.lg),
                      border: Border.all(
                        color: MekaarColors.borderOf(
                          context,
                        ).withValues(alpha: 0.15),
                      ),
                    ),
                    child: filteredParticipants.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: Text(
                                _memberSearchQuery.isNotEmpty
                                    ? 'Tidak ada anggota yang cocok dengan pencarian.'
                                    : 'Belum ada data anggota yang dimuat.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MekaarColors.textMutedOf(context),
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredParticipants.length,
                            separatorBuilder: (ctx, idx) => Divider(
                              height: 1,
                              thickness: 0.6,
                              indent: 64,
                              color: MekaarColors.borderOf(
                                context,
                              ).withValues(alpha: 0.2),
                            ),
                            itemBuilder: (context, index) {
                        final p = filteredParticipants[index];
                        final role = p['role'] as String? ?? 'member';
                        final profile =
                            p['public_profiles'] as Map<String, dynamic>? ?? {};
                        final memberId = p['profile_id'] as String;
                        final isSelf = memberId == _currentUserId;

                        final memberName =
                            (profile['display_name'] as String?)?.isNotEmpty ==
                                    true
                                ? profile['display_name'] as String
                                : profile['full_name'] as String? ??
                                    profile['username'] as String? ??
                                    'Anggota';
                        final username = profile['username'] as String? ?? '';
                        final memberAvatar = profile['avatar_url'] as String?;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          leading: Avatar(
                            size: 40,
                            imageUrl: memberAvatar,
                            initial: memberName.isNotEmpty
                                ? memberName[0]
                                : 'A',
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  memberName,
                                  style: MekaarTypography.bodyMD.copyWith(
                                    color: MekaarColors.textPrimaryOf(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.guardianTeal
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Anda',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: MekaarColors.guardianTeal,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: username.isNotEmpty
                              ? Text(
                                  '@$username',
                                  style: MekaarTypography.bodySM.copyWith(
                                    color: MekaarColors.textMutedOf(context),
                                  ),
                                )
                              : null,
                          trailing: role == 'owner' || role == 'admin'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: role == 'owner'
                                        ? MekaarColors.warnAmber
                                            .withValues(alpha: 0.15)
                                        : AppColors.blue
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      MekaarRadius.sm,
                                    ),
                                  ),
                                  child: Text(
                                    role == 'owner' ? 'Pemilik' : 'Admin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: role == 'owner'
                                          ? MekaarColors.warnAmber
                                          : AppColors.blue,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: isSelf
                              ? null
                              : () => _showMemberOptionsSheet(p),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ──── 5. Danger Zone (Keluar & Bubarkan Grup) ────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _leaveGroup,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MekaarColors.sosRed,
                            side: const BorderSide(color: MekaarColors.sosRed),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(SolarIconsOutline.logout, size: 20),
                          label: const Text(
                            'Keluar dari Grup',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_isOwner) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _disbandGroup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MekaarColors.sosRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              SolarIconsOutline.trashBinTrash,
                              size: 20,
                            ),
                            label: const Text(
                              'Bubarkan Grup Ini',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }
}
