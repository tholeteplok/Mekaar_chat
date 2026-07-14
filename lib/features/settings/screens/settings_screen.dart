import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profile = authState.profile;

    final userName = profile?.fullName ?? profile?.username ?? 'User';
    final userEmail = user?.email ?? '';

    return Scaffold(
      backgroundColor: MekaarColors.background,
      appBar: const CustomAppBar(title: 'Pengaturan'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Card Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Avatar(initial: userName, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MekaarColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: const TextStyle(fontSize: 13, color: MekaarColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Menu Items List
            _buildSectionHeader('Keamanan & Darurat'),
            _buildMenuItem(
              context,
              icon: Icons.history_edu_outlined,
              title: 'Log Sistem',
              subtitle: 'Riwayat aktivitas keamanan permanen Anda',
              onTap: () => Navigator.pushNamed(context, AppRoutes.logs),
            ),
            _buildMenuItem(
              context,
              icon: Icons.find_in_page_outlined,
              title: 'Temukan Ponsel Saya',
              subtitle: 'Mode perangkat hilang (self-guardian)',
              onTap: () => Navigator.pushNamed(context, AppRoutes.deviceLost),
            ),
            const Divider(color: MekaarColors.borderLight, height: 32),
            _buildSectionHeader('Akun'),
            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: 'Profil Saya',
              subtitle: 'Kelola username, foto, dan PIN keamanan',
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            ),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Keluar',
              subtitle: 'Hapus sesi login dari perangkat ini',
              isDestructive: true,
              onTap: () async {
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
                          Navigator.pop(context); // close dialog
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            );
                          }
                        },
                        child: const Text('Keluar', style: TextStyle(color: MekaarColors.sosRed)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: MekaarColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive ? MekaarColors.sosLight : MekaarColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? MekaarColors.sosRed : MekaarColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDestructive ? MekaarColors.sosRed : MekaarColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: MekaarColors.textMuted),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: MekaarColors.textMuted),
      onTap: onTap,
    );
  }
}
