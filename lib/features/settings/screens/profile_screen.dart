import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/services/image_picker_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_info_tile.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isEditingUsername = false;
  bool _isEditingDisplayName = false;
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
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
  }

  @override
  void dispose() {
    _usernameController.dispose();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final wasDuress = authState.lastUnlockWasDuress;
    final user = authState.user;
    final profile = authState.profile;

    final userName = profile?.fullName ?? profile?.username ?? 'User';
    final userEmail = user?.email ?? '';
    final username = profile?.username ?? '';
    final pinSet = authState.isPinSet;

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          children: [
            const MekaarTabHeader(title: 'Profil'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar Hero Section ──
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
                                  size: 80,
                                ),
                                if (_isUploadingAvatar)
                                  Container(
                                    width: 80,
                                    height: 80,
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
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: MekaarColors.guardianTeal,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      SolarIconsBold.camera,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(userName, style: MekaarTypography.headingMD),
                          const SizedBox(height: 4),
                          Text(userEmail, style: MekaarTypography.bodyMD),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pinSet
                                  ? MekaarColors.successLight
                                  : MekaarColors.warningLight,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  pinSet
                                      ? SolarIconsBold.lock
                                      : SolarIconsOutline.lockUnlocked,
                                  size: 12,
                                  color: pinSet
                                      ? MekaarColors.success
                                      : MekaarColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pinSet ? 'PIN Aktif' : 'PIN Belum Diatur',
                                  style: MekaarTypography.labelSM.copyWith(
                                    color: pinSet
                                        ? MekaarColors.success
                                        : MekaarColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Account Info Section ──
                    Text('INFORMASI AKUN', style: MekaarTypography.overline),
                    const SizedBox(height: 12),
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          MekaarInfoTile(
                            icon: SolarIconsOutline.letter,
                            label: 'Email',
                            value: userEmail,
                          ),
                          Divider(
                            height: 24,
                            color: MekaarColors.dividerOf(context),
                          ),
                          // Display Name — editable
                          _buildEditableRow(
                            icon: SolarIconsOutline.user,
                            label: 'Nama Tampilan',
                            value: profile?.displayName ??
                                profile?.fullName ??
                                profile?.username ??
                                'Belum diatur',
                            isEditing: _isEditingDisplayName,
                            controller: _displayNameController,
                            onSubmitted: _saveDisplayName,
                            onToggle: () => setState(
                              () => _isEditingDisplayName = true,
                            ),
                            onSave: _saveDisplayName,
                          ),
                          const Divider(height: 24, color: Colors.transparent),
                          // Username — editable
                          _buildEditableRow(
                            icon: SolarIconsOutline.mentionSquare,
                            label: 'Username',
                            value: username.isNotEmpty
                                ? '@$username'
                                : 'Belum diatur',
                            isEditing: _isEditingUsername,
                            controller: _usernameController,
                            onSubmitted: _saveUsername,
                            onToggle: () => setState(
                              () => _isEditingUsername = true,
                            ),
                            onSave: _saveUsername,
                          ),
                        ],
                      ),
                    ),

                    if (!wasDuress) ...[
                      const SizedBox(height: 24),

                      // ── Security Section ──
                      Text('KEAMANAN', style: MekaarTypography.overline),
                      const SizedBox(height: 12),
                      CustomCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: MekaarColors.surface2Of(context),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  SolarIconsOutline.lockPassword,
                                  color: MekaarColors.textSecondary,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                pinSet ? 'Ubah PIN' : 'Buat PIN',
                                style: MekaarTypography.bodyMD.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: MekaarColors.textPrimaryOf(context),
                                ),
                              ),
                              subtitle: Text(
                                pinSet
                                    ? 'Perbarui PIN 6 digit keamanan Anda.'
                                    : 'Buat PIN untuk melindungi akses aplikasi.',
                                style: MekaarTypography.bodySM.copyWith(
                                  color: MekaarColors.textMutedOf(context),
                                ),
                              ),
                              trailing: Icon(
                                SolarIconsOutline.altArrowRight,
                                color: MekaarColors.textMutedOf(context),
                                size: 18,
                              ),
                              onTap: _navigateToChangePin,
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (!wasDuress) ...[
                      const SizedBox(height: 24),
                      // ── Danger Zone ──
                      Text('ZONA BERBAHAYA', style: MekaarTypography.overline),
                      const SizedBox(height: 12),
                      CustomCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: MekaarColors.sosLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              SolarIconsOutline.logout,
                              color: MekaarColors.sosRed,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            'Keluar',
                            style: MekaarTypography.bodyMD.copyWith(
                              fontWeight: FontWeight.w700,
                              color: MekaarColors.sosRed,
                            ),
                          ),
                          subtitle: Text(
                            'Sesi login dan PIN lokal akan dihapus.',
                            style: MekaarTypography.bodySM.copyWith(
                              color: MekaarColors.textMutedOf(context),
                            ),
                          ),
                          onTap: _confirmLogout,
                        ),
                      ),
                    ],
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required VoidCallback onSubmitted,
    required VoidCallback onToggle,
    required VoidCallback onSave,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: MekaarColors.surface2Of(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: MekaarColors.textSecondaryOf(context), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isEditing
              ? TextField(
                  controller: controller,
                  autofocus: true,
                  onSubmitted: (_) => onSubmitted(),
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textPrimaryOf(context),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(),
                    hintText: 'Masukkan nilai',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: MekaarTypography.bodySM),
                    Text(
                      value,
                      style: MekaarTypography.bodyMD.copyWith(
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
        ),
        IconButton(
          icon: Icon(
            isEditing
                ? SolarIconsOutline.checkCircle
                : SolarIconsOutline.pen,
            color: isEditing
                ? MekaarColors.softCoral
                : MekaarColors.textMutedOf(context),
            size: 18,
          ),
          onPressed: isEditing ? onSave : onToggle,
        ),
      ],
    );
  }
}
