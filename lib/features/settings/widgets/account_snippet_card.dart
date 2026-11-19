import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/strings.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../auth/providers/auth_provider.dart';

/// Helper logout confirm — dipakai bersama oleh [AccountSnippetCard]
/// dan [SettingsLogoutTile].
Future<void> _showLogoutConfirm(BuildContext context, WidgetRef ref) async {
  final confirmed = await MekaarDialog.showConfirmation<bool>(
    context: context,
    title: MekaarCopy.logoutConfirmTitle,
    message: MekaarCopy.logoutConfirmMessage,
    isDestructive: true,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Batal'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text(
          MekaarCopy.logoutConfirmAction,
          style: TextStyle(
            color: MekaarColors.sosRed,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
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

    final displayName = profile?.displayName ??
        profile?.fullName ??
        profile?.username ??
        'Pengguna';
    final username = profile?.username;
    final handleText = (username != null && username.isNotEmpty)
        ? '@$username'
        : (user?.email?.isNotEmpty == true
            ? user!.email!
            : 'Info Profil & Akun');

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.profile);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Avatar
            Avatar(
              initial: displayName,
              imageUrl: profile?.avatarUrl,
              size: 56,
            ),
            const SizedBox(width: 14),
            // Nama & @username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: MekaarTypography.bodyMD.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    handleText,
                    style: MekaarTypography.subtitle.copyWith(
                      fontSize: 13,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!authState.isDuressActive)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.qrCode,
                  size: 22,
                  color: MekaarColors.primaryOf(context),
                ),
                tooltip: MekaarCopy.myQrTooltip,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.myQr);
                },
              ),
            // Chevron arrow
            Icon(
              SolarIconsOutline.altArrowRight,
              size: 18,
              color: MekaarColors.textMutedOf(context),
            ),
          ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? MekaarColors.sosRed.withValues(alpha: 0.15)
              : MekaarColors.sosLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          SolarIconsOutline.logout,
          color: MekaarColors.sosRed,
          size: 22,
        ),
      ),
      title: Text(
        MekaarCopy.logoutTitle,
        style: MekaarTypography.bodyMD.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MekaarColors.sosRed,
        ),
      ),
      subtitle: Text(
        MekaarCopy.logoutSubtitle,
        style: MekaarTypography.bodySM.copyWith(
          fontSize: 13.5,
          color: MekaarColors.textMutedOf(context),
        ),
      ),
      trailing: Icon(
        SolarIconsOutline.altArrowRight,
        size: 18,
        color: MekaarColors.textMutedOf(context),
      ),
      onTap: () => _showLogoutConfirm(context, ref),
    );
  }
}
