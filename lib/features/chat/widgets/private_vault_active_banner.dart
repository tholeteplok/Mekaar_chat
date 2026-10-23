import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../providers/private_vault_provider.dart';

/// PrivateVaultActiveBanner — Banner sentral yang muncul saat Private Vault dibuka.
/// Digunakan serentak di Tab Pesan dan Tab Kontak agar visual, warna, ikon,
/// dan aksi relock konsisten 100% tanpa inkonsistensi desain.
class PrivateVaultActiveBanner extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  final String title;

  const PrivateVaultActiveBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    this.title = 'Vault Terbuka (Sesi Aktif)',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    if (!isVaultUnlocked) return const SizedBox.shrink();

    final safeColor = MekaarColors.safeTextOf(context);

    return Padding(
      padding: padding,
      child: MekaarBanner(
        color: safeColor,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        icon: SolarIconsBold.shieldKeyhole,
        content: Text(
          title,
          style: TextStyle(
            color: MekaarColors.textPrimaryOf(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        action: InkWell(
          onTap: () {
            HapticService.trigger(MekaarHapticIntent.selection);
            ref.read(unlockedVaultSlotsProvider.notifier).state = {};
            ref.read(privateVaultUnlockedProvider.notifier).state = false;
            MekaarSnackbar.info(context, 'Private Vault Terkunci');
          },
          borderRadius: BorderRadius.circular(MekaarRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: MekaarColors.guardianTeal,
              borderRadius: BorderRadius.circular(MekaarRadius.sm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  SolarIconsOutline.lock,
                  color: MekaarColors.textOnTeal,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'Kunci',
                  style: TextStyle(
                    color: MekaarColors.textOnTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
