import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/avatar.dart';
import '../../auth/providers/auth_provider.dart';

/// Helper logout confirm — dipakai bersama oleh [AccountSnippetCard]
/// dan [SettingsLogoutTile].
Future<void> _showLogoutConfirm(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Keluar Aplikasi?'),
      content: const Text('PIN keamanan lokal akan dihapus demi privasi.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Keluar',
            style: TextStyle(
              color: MekaarColors.sosRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    }
  }
}

/// Cuplikan profil singkat untuk section Akun di halaman Pengaturan.
///
/// Menampilkan: avatar + nama + email (read-only).
/// Tap kartu → buka [ProfileScreen] yang lengkap.
///
/// Tidak menduplikasi form edit atau logika lengkap [ProfileScreen].
class AccountSnippetCard extends ConsumerWidget {
  const AccountSnippetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final user = authState.user;

    final displayName = profile?.displayName ?? profile?.fullName ?? profile?.username ?? 'Pengguna';
    final email = user?.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: isDark ? MekaarColors.cardDark : MekaarColors.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                Avatar(initial: displayName, size: 48),
                const SizedBox(width: 14),
                // Nama & email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: MekaarTypography.labelLG.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: MekaarTypography.bodySM,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Chevron — tap ke profil
                const Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 18,
                  color: MekaarColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol logout destructive — dipakai di section Akun settings.
/// Terpisah dari [AccountSnippetCard] agar fleksibel penempatannya.
class SettingsLogoutTile extends ConsumerWidget {
  const SettingsLogoutTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? MekaarColors.sosRed.withValues(alpha: 0.15)
              : MekaarColors.sosLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          SolarIconsOutline.logout,
          color: MekaarColors.sosRed,
          size: 20,
        ),
      ),
      title: Text(
        'Keluar',
        style: MekaarTypography.labelLG.copyWith(
          fontWeight: FontWeight.bold,
          color: MekaarColors.sosRed,
        ),
      ),
      subtitle: Text(
        'Sesi login dan PIN lokal akan dihapus.',
        style: MekaarTypography.bodySM,
      ),
      trailing: const Icon(
        SolarIconsOutline.altArrowRight,
        size: 18,
        color: MekaarColors.textMuted,
      ),
      onTap: () => _showLogoutConfirm(context, ref),
    );
  }
}
