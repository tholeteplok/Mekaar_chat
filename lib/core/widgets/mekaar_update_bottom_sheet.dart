import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../data/services/update_service.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';

/// MekaarUpdateBottomSheet — Bottom sheet terpusat untuk notifikasi rilis versi terbaru
class MekaarUpdateBottomSheet extends StatelessWidget {
  final AppUpdateInfo info;
  final VoidCallback? onUpdate;
  final VoidCallback? onLater;

  const MekaarUpdateBottomSheet({
    super.key,
    required this.info,
    this.onUpdate,
    this.onLater,
  });

  /// Menampilkan Bottom Sheet notifikasi pembaruan secara modal
  static Future<void> show({
    required BuildContext context,
    required AppUpdateInfo info,
    VoidCallback? onUpdate,
    VoidCallback? onLater,
  }) async {
    HapticService.trigger(MekaarHapticIntent.success);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => MekaarUpdateBottomSheet(
        info: info,
        onUpdate: () {
          Navigator.pop(sheetContext);
          onUpdate?.call();
        },
        onLater: () {
          Navigator.pop(sheetContext);
          onLater?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = MekaarColors.accentOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Ikon & Judul ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                SolarIconsBold.rocket2,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembaruan Tersedia 🚀',
                    style: MekaarTypography.headingSM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Versi ${info.latestVersion}',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Info Metadata Badges (Ukuran & Arsitektur) ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (info.formattedSize.isNotEmpty)
              _buildBadge(
                context,
                icon: SolarIconsOutline.cloudDownload,
                label: info.formattedSize,
                accentColor: accentColor,
              ),
            if (info.matchedAbi.isNotEmpty)
              _buildBadge(
                context,
                icon: SolarIconsOutline.cpu,
                label: info.matchedAbi == 'universal'
                    ? 'Universal APK'
                    : info.matchedAbi,
                accentColor: accentColor,
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Catatan Rilis (Release Notes) ──
        Text(
          'Catatan Rilis:',
          style: MekaarTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: MekaarColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 140),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MekaarColors.surface2Of(context),
            borderRadius: BorderRadius.circular(MekaarRadius.md),
            border: Border.all(
              color: MekaarColors.border.withValues(alpha: isDark ? 0.1 : 0.06),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              info.releaseNotes.isNotEmpty
                  ? info.releaseNotes
                  : 'Pembaruan stabilitas, performa, dan penguatan privasi sistem MEKAAR.',
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Tombol Aksi: Nanti & Perbarui ──
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
                onPressed: onLater,
                child: Text(
                  'Nanti',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
                onPressed: onUpdate,
                icon: const Icon(SolarIconsBold.download, size: 18),
                label: Text(
                  'Perbarui',
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: MekaarTypography.caption.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
