import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/services/image_picker_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/bubbles/full_screen_image_viewer.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/services/haptic_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/settings_tiles.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isEditingDisplayName = false;
  bool _isEditingBio = false;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  bool _isUploadingAvatar = false;

  final ImagePickerService _imagePickerService = ImagePickerService();

  Future<void> _handlePickAndUploadAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;

    setState(() => _isUploadingAvatar = true);

    final file = await _imagePickerService.pickAndProcessImage(
      source,
      context: context,
    );
    if (file == null) {
      if (mounted) setState(() => _isUploadingAvatar = false);
      return; // User cancelled or error
    }

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.uploadAndUpdateAvatar(file);
      await ref.read(authProvider.notifier).loadProfile();

      if (mounted) {
        MekaarSnackbar.success(context, 'Foto profil berhasil diperbarui.');
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal memperbarui foto profil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _handleDeleteAvatar() async {
    if (_isUploadingAvatar) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.deleteAvatar();
      await ref.read(authProvider.notifier).loadProfile();

      if (mounted) {
        MekaarSnackbar.success(context, 'Foto profil berhasil dihapus.');
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal menghapus foto profil: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _confirmDeleteAvatar() {
    MekaarDialog.show(
      context: context,
      title: 'Hapus Foto Profil?',
      body:
          'Foto profil Anda akan dihapus dan kembali menampilkan inisial krayon MEKAAR.',
      confirmLabel: 'Hapus',
      confirmColor: MekaarColors.sosRed,
      isDestructive: true,
      onConfirm: _handleDeleteAvatar,
    );
  }

  void _showAvatarOptions() {
    final hasCustomAvatar =
        ref.read(authProvider).profile?.avatarUrl?.isNotEmpty ?? false;

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(SolarIconsOutline.camera),
            title: const Text('Kamera'),
            onTap: () {
              Navigator.pop(ctx);
              _handlePickAndUploadAvatar(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(SolarIconsOutline.gallery),
            title: const Text('Galeri'),
            onTap: () {
              Navigator.pop(ctx);
              _handlePickAndUploadAvatar(ImageSource.gallery);
            },
          ),
          if (hasCustomAvatar) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                SolarIconsOutline.trashBinTrash,
                color: MekaarColors.sosRed,
              ),
              title: const Text(
                'Hapus Foto Profil',
                style: TextStyle(
                  color: MekaarColors.sosRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteAvatar();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openFullAvatar() {
    final avatarUrl = ref.read(authProvider).profile?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      HapticService.trigger(MekaarHapticIntent.selection);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(
            imageProvider: NetworkImage(avatarUrl),
            heroTag: 'profile_full_avatar',
          ),
        ),
      );
    } else {
      _showAvatarOptions();
    }
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    _displayNameController = TextEditingController(
      text: profile?.displayName ?? profile?.fullName ?? '',
    );
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final newName = _displayNameController.text.trim();
    setState(() => _isEditingDisplayName = false);
    try {
      await ref.read(authProvider.notifier).updateDisplayName(newName);
      if (mounted) {
        MekaarSnackbar.success(context, 'Nama tampilan berhasil diperbarui.');
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal memperbarui nama tampilan.');
      }
      _displayNameController.text =
          ref.read(authProvider).profile?.displayName ??
          ref.read(authProvider).profile?.fullName ??
          '';
    }
  }

  Future<void> _saveBio() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final newBio = _bioController.text.trim();
    if (newBio.length > 160) {
      if (mounted) MekaarSnackbar.error(context, 'Bio maksimal 160 karakter.');
      return;
    }
    setState(() => _isEditingBio = false);
    try {
      await ref.read(authProvider.notifier).updateBio(newBio);
      if (mounted) {
        MekaarSnackbar.success(context, 'Bio berhasil diperbarui.');
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal memperbarui bio: $e');
      }
      _bioController.text = ref.read(authProvider).profile?.bio ?? '';
    }
  }

  void _confirmLogout() {
    MekaarDialog.show(
      context: context,
      title: 'Keluar Aplikasi?',
      body: 'PIN keamanan lokal akan dihapus demi privasi.',
      confirmLabel: 'Keluar',
      confirmColor: MekaarColors.sosRed,
      onConfirm: () async {
        final nav = Navigator.of(context);
        await ref.read(authProvider.notifier).logout();
        nav.pushNamedAndRemoveUntil('/login', (route) => false);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _saveAllChanges() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isEditingDisplayName) {
      await _saveDisplayName();
    }
    if (_isEditingBio) {
      await _saveBio();
    }
    if (mounted) {
      MekaarSnackbar.success(context, 'Perubahan profil tersimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profile = authState.profile;

    final userName =
        profile?.displayName ??
        profile?.fullName ??
        profile?.username ??
        'User';
    final userEmail = user?.email ?? '';
    final username = profile?.username ?? '';
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    final saveActionButton =
        (_isEditingDisplayName || _isEditingBio)
        ? IconButton(
            onPressed: _saveAllChanges,
            icon: Icon(
              SolarIconsBold.checkCircle,
              color: MekaarColors.primaryOf(context),
              size: 24,
            ),
            tooltip: 'Simpan Perubahan',
          )
        : null;

    final logoutActionButton = IconButton(
      tooltip: 'Keluar dari Akun',
      icon: const Icon(
        SolarIconsOutline.logout,
        color: MekaarColors.sosRed,
        size: 22,
      ),
      onPressed: _confirmLogout,
    );

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          children: [
            if (canPop)
              SettingsTopBar(
                title: 'Profil',
                actions: [
                  ?saveActionButton,
                  logoutActionButton,
                ],
              )
            else
              MekaarTabHeader(
                title: 'Profil',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?saveActionButton,
                    logoutActionButton,
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── Centered Avatar Section ──
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isUploadingAvatar
                                ? null
                                : _openFullAvatar,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Avatar(
                                  initial: userName,
                                  imageUrl: profile?.avatarUrl,
                                  size: 168,
                                  heroTag: 'profile_full_avatar',
                                ),
                                if (_isUploadingAvatar)
                                  Container(
                                    width: 168,
                                    height: 168,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _isUploadingAvatar
                                ? null
                                : () {
                                    HapticService.trigger(
                                      MekaarHapticIntent.selection,
                                    );
                                    _showAvatarOptions();
                                  },
                            icon: Icon(
                              SolarIconsOutline.camera,
                              size: 16,
                              color: MekaarColors.accentTextOf(context),
                            ),
                            label: Text(
                              'Ubah Foto',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.accentTextOf(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Clean Parameter Form Rows (Borderless) ──
                    Column(
                      children: [
                        // 1. Nama Tampilan
                        _buildCleanRow(
                          label: 'Nama',
                          isEditing: _isEditingDisplayName,
                          controller: _displayNameController,
                          value:
                              profile?.displayName ??
                              profile?.fullName ??
                              profile?.username ??
                              'Belum diatur',
                          onToggle: () =>
                              setState(() => _isEditingDisplayName = true),
                          onSave: _saveDisplayName,
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.8,
                          indent: 90,
                          endIndent: 0,
                          color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
                        ),

                        // 2. Username (Permanen / Read-only)
                        _buildCleanRow(
                          label: 'Username',
                          value: username.isNotEmpty
                              ? '@$username'
                              : 'Belum diatur',
                          isLocked: true,
                          lockedTooltip: 'Username bersifat permanen',
                          onLockedTap: () {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            MekaarSnackbar.info(
                              context,
                              'Username bersifat permanen dan tidak dapat diubah.',
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.8,
                          indent: 90,
                          endIndent: 0,
                          color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
                        ),

                        // 3. Bio / Status
                        _buildCleanRow(
                          label: 'Bio',
                          isEditing: _isEditingBio,
                          controller: _bioController,
                          value: (profile?.bio != null && profile!.bio!.isNotEmpty)
                              ? profile.bio!
                              : 'Tambah bio / status...',
                          onToggle: () => setState(() => _isEditingBio = true),
                          onSave: _saveBio,
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.8,
                          indent: 90,
                          endIndent: 0,
                          color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
                        ),

                        // 4. Email (Permanen / Terhubung)
                        _buildCleanRow(
                          label: 'Email',
                          value: userEmail.isNotEmpty
                              ? userEmail
                              : 'Belum terhubung',
                          isLocked: true,
                          lockedTooltip: 'Email terhubung ke sesi autentikasi',
                          onLockedTap: () {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            MekaarSnackbar.info(
                              context,
                              'Email akun terhubung dan tidak dapat diubah di sini.',
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanRow({
    required String label,
    required String value,
    bool isEditing = false,
    TextEditingController? controller,
    VoidCallback? onToggle,
    VoidCallback? onSave,
    String? subtitle,
    bool isLocked = false,
    String? lockedTooltip,
    VoidCallback? onLockedTap,
  }) {
    return InkWell(
      onTap: isLocked ? onLockedTap : null,
      borderRadius: BorderRadius.circular(MekaarRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment:
              subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              child: Padding(
                padding: EdgeInsets.only(top: subtitle != null ? 2 : 0),
                child: Text(
                  label,
                  style: MekaarTypography.bodySM.copyWith(
                    color: MekaarColors.textMutedOf(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: (isEditing && controller != null && onSave != null)
                  ? TextField(
                      controller: controller,
                      autofocus: true,
                      onSubmitted: (_) => onSave(),
                      style: MekaarTypography.bodyMD.copyWith(
                        color: MekaarColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: MekaarColors.accentTextOf(context),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: MekaarColors.accentTextOf(context),
                            width: 2,
                          ),
                        ),
                        hintText: 'Ketik $label...',
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: MekaarTypography.bodyMD.copyWith(
                            color: MekaarColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            IconButton(
              icon: Icon(
                isEditing
                    ? SolarIconsOutline.checkCircle
                    : (isLocked ? SolarIconsOutline.lock : SolarIconsOutline.pen),
                color: isEditing
                    ? MekaarColors.accentTextOf(context)
                    : MekaarColors.textMutedOf(context),
                size: 18,
              ),
              tooltip: isLocked
                  ? (lockedTooltip ?? 'Terkunci dan tidak dapat diubah')
                  : (isEditing ? 'Simpan' : 'Ubah'),
              onPressed: isEditing
                  ? onSave
                  : (isLocked ? onLockedTap : onToggle),
            ),
          ],
        ),
      ),
    );
  }
}
