import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/privacy_provider.dart';
import '../widgets/settings_tiles.dart';

/// Layar Pengaturan Privasi Lanjutan
/// Berisi:
/// 1. Manajemen Vault (dilindungi verifikasi 6-digit PIN Utama)
/// 2. Sembunyikan Notifikasi Darurat
/// 3. Sembunyikan Cuplikan Pesan
class AdvancedPrivacySettingsScreen extends ConsumerWidget {
  const AdvancedPrivacySettingsScreen({super.key});

  Future<void> _handleOpenVaultManagement(BuildContext context) async {
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Utama',
      subtitle: 'Masukkan 6 digit PIN aplikasi untuk membuka Manajemen Vault',
    );

    if (verified && context.mounted) {
      Navigator.pushNamed(context, AppRoutes.contactVaultSettings);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(
              title: 'Privasi Lanjutan',
              subtitle: 'Manajemen vault, notifikasi & cuplikan pesan',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MekaarSpacing.md,
                  vertical: MekaarSpacing.sm,
                ),
                children: [
                  const SettingsSectionHeader(title: 'Vault Rahasia'),
                  CustomCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SettingsNavTile(
                      icon: SolarIconsBold.shieldKeyhole,
                      iconColor: MekaarColors.guardianTeal,
                      title: 'Manajemen Vault',
                      subtitle: 'Kelola slot vault, kode akses, dan kontak terisolasi',
                      onTap: () => _handleOpenVaultManagement(context),
                    ),
                  ),
                  const SizedBox(height: MekaarSpacing.md),
                  const SettingsSectionHeader(title: 'Notifikasi & Penyamaran'),
                  CustomCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        SettingsSwitchTile(
                          icon: SolarIconsOutline.eye,
                          iconColor: MekaarColors.warning,
                          title: 'Sembunyikan Notifikasi Darurat',
                          subtitle: 'Samarkan rincian nama pengirim & pesan saat darurat',
                          value: ref.watch(notificationMaskingProvider),
                          onChanged: (value) => ref
                              .read(notificationMaskingProvider.notifier)
                              .setEnabled(value),
                        ),
                        SettingsSwitchTile(
                          icon: SolarIconsOutline.eyeClosed,
                          iconColor: MekaarColors.purpleLight,
                          title: 'Sembunyikan Cuplikan Pesan',
                          subtitle: 'Sembunyikan preview teks terakhir pada daftar obrolan publik',
                          value: ref.watch(stealthChatPreviewProvider),
                          onChanged: (value) => ref
                              .read(stealthChatPreviewProvider.notifier)
                              .setEnabled(value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
