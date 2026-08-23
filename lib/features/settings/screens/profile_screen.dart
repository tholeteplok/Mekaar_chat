import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/services/image_picker_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';
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
  bool _isEditingUsername = false;
  bool _isEditingDisplayName = false;
  bool _isEditingBio = false;
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  bool _isUploadingAvatar = false;

  final ImagePickerService _imagePickerService = ImagePickerService();

  Future<void> _handlePickAndUploadAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;

    setState(() => _isUploadingAvatar = true);

    final file = await _imagePickerService.pickAndProcessImage(source, context: context);
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

  void _showAvatarOptions() {
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
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _displayNameController = TextEditingController(text: profile?.displayName ?? profile?.fullName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
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

  Future<void> _saveUsername() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty || newUsername.length < 3) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Username minimal 3 karakter.');
      }
      return;
    }

    setState(() => _isEditingUsername = false);

    try {
      await ref.read(authProvider.notifier).updateUsername(newUsername);
      if (mounted) {
        MekaarSnackbar.success(context, 'Username berhasil diperbarui.');
      }
    } catch (e) {
      final errorStr = e.toString();
      if (mounted) {
        MekaarSnackbar.error(
          context,
          errorStr.contains('digunakan')
              ? 'Username sudah digunakan.'
              : 'Gagal memperbarui username.',
        );
      }
      _usernameController.text = ref.read(authProvider).profile?.username ?? '';
    }
  }

  void _navigateToChangePin() {
    Navigator.pushNamed(context, '/pin', arguments: true);
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
    if (_isEditingUsername) {
      await _saveUsername();
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
    final wasDuress = authState.lastUnlockWasDuress;
    final user = authState.user;
    final profile = authState.profile;

    final userName =
        profile?.displayName ?? profile?.fullName ?? profile?.username ?? 'User';
    final userEmail = user?.email ?? '';
    final username = profile?.username ?? '';
    final pinSet = authState.isPinSet;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    final saveActionButton = (_isEditingDisplayName || _isEditingUsername || _isEditingBio)
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

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          children: [
            if (canPop)
              SettingsTopBar(
                title: 'Profil',
                trailing: saveActionButton,
              )
            else
              MekaarTabHeader(
                title: 'Profil',
                action: saveActionButton,
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
                            onTap: _isUploadingAvatar ? null : _showAvatarOptions,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Avatar(
                                  initial: userName,
                                  imageUrl: profile?.avatarUrl,
                                  size: 84,
                                ),
                                if (_isUploadingAvatar)
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
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

                    // ── Clean Parameter Form Rows ──
                    CustomCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          // 1. Nama Tampilan
                          _buildCleanRow(
                            label: 'Nama',
                            isEditing: _isEditingDisplayName,
                            controller: _displayNameController,
                            value: profile?.displayName ??
                                profile?.fullName ??
                                profile?.username ??
                                'Belum diatur',
                            onToggle: () => setState(
                              () => _isEditingDisplayName = true,
                            ),
                            onSave: _saveDisplayName,
                          ),
                          const SizedBox(height: 6),

                          // 2. Username
                          _buildCleanRow(
                            label: 'Username',
                            isEditing: _isEditingUsername,
                            controller: _usernameController,
                            value: username.isNotEmpty
                                ? '@$username'
                                : 'Belum diatur',
                            onToggle: () => setState(
                              () => _isEditingUsername = true,
                            ),
                            onSave: _saveUsername,
                          ),
                          const SizedBox(height: 6),

                          // 3. Bio / Status
                          _buildCleanRow(
                            label: 'Bio',
                            isEditing: _isEditingBio,
                            controller: _bioController,
                            value: (profile?.bio != null && profile!.bio!.isNotEmpty)
                                ? profile.bio!
                                : 'Tambah bio / status...',
                            onToggle: () => setState(
                              () => _isEditingBio = true,
                            ),
                            onSave: _saveBio,
                          ),
                          const SizedBox(height: 6),

                          // 4. Email
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    'Email',
                                    style: MekaarTypography.bodySM.copyWith(
                                      color: MekaarColors.textMutedOf(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    userEmail.isNotEmpty
                                        ? userEmail
                                        : 'Belum terhubung',
                                    style: MekaarTypography.bodyMD.copyWith(
                                      color:
                                          MekaarColors.textPrimaryOf(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  SolarIconsOutline.lock,
                                  size: 16,
                                  color: MekaarColors.textMutedOf(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!wasDuress) ...[
                      const SizedBox(height: 20),
                      Text(
                        'KEAMANAN AKUN',
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.textMutedOf(context),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      CustomCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                'PIN Kunci',
                                style: MekaarTypography.bodySM.copyWith(
                                  color: MekaarColors.textMutedOf(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: pinSet
                                    ? MekaarColors.successLight
                                    : MekaarColors.warningLight,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                pinSet ? 'PIN Aktif' : 'Belum Diatur',
                                style: MekaarTypography.caption.copyWith(
                                  color: pinSet
                                      ? MekaarColors.success
                                      : MekaarColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _navigateToChangePin,
                              child: Text(
                                pinSet ? 'Ubah PIN' : 'Atur PIN',
                                style: MekaarTypography.bodySM.copyWith(
                                  color: MekaarColors.accentTextOf(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Logout Action Button ──
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(
                          SolarIconsOutline.logout,
                          color: MekaarColors.sosRed,
                          size: 18,
                        ),
                        label: Text(
                          'Keluar dari Akun',
                          style: MekaarTypography.bodyMD.copyWith(
                            color: MekaarColors.sosRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),
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
    required bool isEditing,
    required TextEditingController controller,
    required VoidCallback onToggle,
    required VoidCallback onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textMutedOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: isEditing
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
                        borderSide:
                            BorderSide(color: MekaarColors.accentTextOf(context)),
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
                : Text(
                    value,
                    style: MekaarTypography.bodyMD.copyWith(
                      color: MekaarColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          IconButton(
            icon: Icon(
              isEditing
                  ? SolarIconsOutline.checkCircle
                  : SolarIconsOutline.pen,
              color: isEditing
                  ? MekaarColors.accentTextOf(context)
                  : MekaarColors.textMutedOf(context),
              size: 18,
            ),
            onPressed: isEditing ? onSave : onToggle,
          ),
        ],
      ),
    );
  }
}
