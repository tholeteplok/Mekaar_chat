import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';

/// MekaarPermissionsBottomSheet — Bottom sheet terpusat untuk edukasi & permintaan izin sensor awal.
class MekaarPermissionsBottomSheet extends StatelessWidget {
  final VoidCallback onGrant;
  final VoidCallback? onCancel;

  const MekaarPermissionsBottomSheet({
    super.key,
    required this.onGrant,
    this.onCancel,
  });

  /// Menampilkan Bottom Sheet Permintaan Izin Sensor
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onGrant,
    VoidCallback? onCancel,
  }) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    await MekaarBottomSheet.show<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => MekaarPermissionsBottomSheet(
        onGrant: () {
          Navigator.pop(sheetContext);
          onGrant();
        },
        onCancel: () {
          Navigator.pop(sheetContext);
          onCancel?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.blue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Ikon & Judul ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                SolarIconsBold.shieldCheck,
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
                    'Izin Sensor & Keamanan',
                    style: MekaarTypography.headingSM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Diperlukan untuk perlindungan darurat',
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

        Text(
          'Untuk perlindungan maksimal dan respon darurat aktif, MEKAAR memerlukan izin akses:',
          style: MekaarTypography.bodySM.copyWith(
            color: MekaarColors.textSecondaryOf(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // ── 3 Sensor Tiles ──
        _buildSensorTile(
          context,
          icon: SolarIconsOutline.mapPoint,
          title: 'Lokasi GPS Presisi',
          description:
              'Mengirim koordinat real-time saat SOS aktif dan pelacakan rute aman.',
          iconBg: isDark ? const Color(0xFF1E304F) : const Color(0xFFE8F4FC),
          iconColor: AppColors.blue,
        ),
        const SizedBox(height: 10),
        _buildSensorTile(
          context,
          icon: SolarIconsOutline.videocamera,
          title: 'Kamera',
          description:
              'Merekam bukti video kondisi darurat dan pemindaian kode QR kontak.',
          iconBg: isDark ? const Color(0xFF1E304F) : const Color(0xFFE8F4FC),
          iconColor: AppColors.blue,
        ),
        const SizedBox(height: 10),
        _buildSensorTile(
          context,
          icon: SolarIconsOutline.microphone,
          title: 'Mikrofon',
          description:
              'Mengirim audio darurat sekitar secara langsung ke Guardian terhubung.',
          iconBg: isDark ? const Color(0xFF1E304F) : const Color(0xFFE8F4FC),
          iconColor: AppColors.blue,
        ),
        const SizedBox(height: 14),

        // ── Catatan Pop-up Sistem ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E304F).withValues(alpha: 0.6)
                : const Color(0xFFF1F6FB),
            borderRadius: BorderRadius.circular(MekaarRadius.md),
            border: Border.all(
              color: isDark ? const Color(0xFF25395B) : const Color(0xFFDCE7F5),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                SolarIconsOutline.infoCircle,
                size: 18,
                color: AppColors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ponsel Anda akan menampilkan dialog izin sistem setelah ini.',
                  style: MekaarTypography.caption.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Tombol Aksi ──
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  ),
                ),
                onPressed: onCancel,
                child: Text(
                  'Nanti',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  ),
                ),
                onPressed: onGrant,
                icon: const Icon(SolarIconsBold.shieldCheck, size: 18),
                label: Text(
                  'Berikan Izin',
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color iconBg,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2A44) : Colors.white,
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(
          color: isDark ? const Color(0xFF25395B) : const Color(0xFFDCE7F5),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.textPrimaryOf(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: MekaarTypography.caption.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
