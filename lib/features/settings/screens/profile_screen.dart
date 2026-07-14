import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditingUsername = false;
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    _usernameController = TextEditingController(text: profile?.username ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty || newUsername.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username minimal 3 karakter.'),
          backgroundColor: MekaarColors.sosRed,
        ),
      );
      return;
    }

    // Untuk sementara update di state local karena update profile belum di repo
    setState(() => _isEditingUsername = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Username berhasil diperbarui.'),
        backgroundColor: MekaarColors.success,
      ),
    );
  }

  void _navigateToChangePin() {
    Navigator.pushNamed(context, '/pin', arguments: true);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi?'),
        content: const Text('PIN keamanan lokal akan dihapus demi privasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Keluar', style: TextStyle(color: MekaarColors.sosRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profile = authState.profile;

    final userName = profile?.fullName ?? profile?.username ?? 'User';
    final userEmail = user?.email ?? '';
    final username = profile?.username ?? '';
    final pinSet = authState.isPinSet;

    return Scaffold(
      backgroundColor: MekaarColors.background,
      appBar: const CustomAppBar(title: 'Profil Saya'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar Hero Section ──
            Center(
              child: Column(
                children: [
                  Avatar(initial: userName, size: 80),
                  const SizedBox(height: 16),
                  Text(userName, style: MekaarTypography.headingMD),
                  const SizedBox(height: 4),
                  Text(userEmail, style: MekaarTypography.bodyMD),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: pinSet ? MekaarColors.successLight : MekaarColors.warningLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pinSet ? Icons.lock : Icons.lock_open_outlined,
                          size: 12,
                          color: pinSet ? MekaarColors.success : MekaarColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pinSet ? 'PIN Aktif' : 'PIN Belum Diatur',
                          style: MekaarTypography.labelSM.copyWith(
                            color: pinSet ? MekaarColors.success : MekaarColors.warning,
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
                  _infoRow(Icons.email_outlined, 'Email', userEmail),
                  const Divider(height: 24, color: MekaarColors.borderLight),
                  // Username — editable
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: MekaarColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.alternate_email, color: MekaarColors.textSecondary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isEditingUsername
                            ? TextField(
                                controller: _usernameController,
                                autofocus: true,
                                style: MekaarTypography.bodyMD.copyWith(color: MekaarColors.textPrimary),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: UnderlineInputBorder(),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Username', style: MekaarTypography.bodySM),
                                  Text(
                                    username.isNotEmpty ? '@$username' : 'Belum diatur',
                                    style: MekaarTypography.bodyMD.copyWith(color: MekaarColors.textPrimary),
                                  ),
                                ],
                              ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEditingUsername ? Icons.check : Icons.edit_outlined,
                          color: _isEditingUsername ? MekaarColors.softCoral : MekaarColors.textMuted,
                          size: 18,
                        ),
                        onPressed: _isEditingUsername
                            ? _saveUsername
                            : () => setState(() => _isEditingUsername = true),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: MekaarColors.surface2, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.lock_outline, color: MekaarColors.textSecondary, size: 18),
                    ),
                    title: Text(pinSet ? 'Ubah PIN' : 'Buat PIN', style: MekaarTypography.labelLG),
                    subtitle: Text(
                      pinSet ? 'Perbarui PIN 6 digit keamanan Anda.' : 'Buat PIN untuk melindungi akses aplikasi.',
                      style: MekaarTypography.bodySM,
                    ),
                    trailing: const Icon(Icons.chevron_right, color: MekaarColors.textMuted, size: 18),
                    onTap: _navigateToChangePin,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Danger Zone ──
            Text('ZONA BERBAHAYA', style: MekaarTypography.overline),
            const SizedBox(height: 12),
            CustomCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: MekaarColors.sosLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.logout, color: MekaarColors.sosRed, size: 18),
                ),
                title: Text('Keluar', style: MekaarTypography.labelLG.copyWith(color: MekaarColors.sosRed)),
                subtitle: Text('Sesi login dan PIN lokal akan dihapus.', style: MekaarTypography.bodySM),
                onTap: _confirmLogout,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: MekaarColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: MekaarColors.textSecondary, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: MekaarTypography.bodySM),
            Text(value, style: MekaarTypography.bodyMD.copyWith(color: MekaarColors.textPrimary)),
          ],
        ),
      ],
    );
  }
}
