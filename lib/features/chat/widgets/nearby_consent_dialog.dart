import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';

class NearbyConsentDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback? onCancel;

  const NearbyConsentDialog({
    super.key,
    required this.onAccept,
    this.onCancel,
  });

  static Future<bool> show(BuildContext context) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final result = await MekaarBottomSheet.show<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => NearbyConsentDialog(
        onAccept: () {
          Navigator.pop(sheetContext, true);
        },
        onCancel: () {
          Navigator.pop(sheetContext, false);
        },
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final points = [
      (
        icon: SolarIconsOutline.radar2,
        title: 'Hanya Radius Kasar (Bukan GPS Presisi)',
        desc:
            'Jarak ditampilkan dalam band diskrit (Dekatmu, Sekitarmu, Di kotamu). Koordinat mentah Anda tidak pernah dibagikan ke orang lain.',
        color: MekaarColors.guardianTeal,
      ),
      (
        icon: SolarIconsOutline.usersGroupRounded,
        title: 'Mutual Opt-In Dua Arah',
        desc:
            'Anda hanya dapat melihat teman yang juga mengaktifkan fitur ini. Begitu dinonaktifkan, Anda langsung hilang dari canvas teman seketika.',
        color: AppColors.blue,
      ),
      (
        icon: SolarIconsOutline.lockKeyhole,
        title: 'Kontrol & Perlindungan Privasi',
        desc:
            'Data lokasi bersifat sementara (tanpa histori) dan fitur dapat dimatikan kapan saja langsung dari Pengaturan Privasi.',
        color: MekaarColors.softCoral,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teman Sekitar',
                style: MekaarTypography.headingMD.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kesadaran jarak sosial berbasis privasi',
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textMutedOf(context),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Poin-poin edukasi
          for (final point in points) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: point.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  ),
                  child: Icon(point.icon, color: point.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.title,
                        style: MekaarTypography.bodyMD.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: MekaarColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        point.desc,
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textSecondaryOf(context),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  child: Text(
                    'Nanti Saja',
                    style: TextStyle(
                      color: MekaarColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.guardianTeal,
                    foregroundColor: MekaarColors.textOnTeal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  child: const Text(
                    'Aktifkan Fitur',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
