import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/privacy_provider.dart';
import '../widgets/settings_tiles.dart';

/// Layar Pengaturan Privasi Lanjutan
/// Berisi:
/// 1. Sembunyikan Notifikasi Darurat
/// 2. Sembunyikan Cuplikan Pesan
/// 3. Sembunyikan Alamat IP Panggilan (WebRTC Relay Only)
class AdvancedPrivacySettingsScreen extends ConsumerWidget {
  const AdvancedPrivacySettingsScreen({super.key});

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
              subtitle: 'Notifikasi, cuplikan pesan & keamanan jaringan',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: MekaarSpacing.sm, bottom: 24),
                children: [
                  const SettingsSectionHeader(title: 'Notifikasi & Penyamaran'),
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
                  const SettingsDivider(),
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
                  const SizedBox(height: MekaarSpacing.md),
                  const SettingsSectionHeader(title: 'Panggilan & Jaringan (Anti-IP Leak)'),
                  SettingsSwitchTile(
                    icon: SolarIconsOutline.routing,
                    iconColor: MekaarColors.info,
                    title: 'Sembunyikan Alamat IP Panggilan',
                    subtitle: 'Selalu alihkan panggilan via relay server MEKAAR untuk mencegah kebocoran alamat IP Anda',
                    value: ref.watch(relayCallsOnlyProvider),
                    onChanged: (value) => ref
                        .read(relayCallsOnlyProvider.notifier)
                        .setEnabled(value),
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
