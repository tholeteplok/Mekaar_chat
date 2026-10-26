import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/sos_provider.dart';

/// EmergencyActiveBanner — Banner darurat sentral persisten yang muncul
/// di layar obrolan saat SOS sedang aktif atau tertunda offline.
///
/// Menyediakan akses instan ke layar penuh SOS serta tombol penonaktifan
/// dengan warna kontras tinggi (BUKAN MERAH) yang diwajibkan verifikasi PIN 6-digit.
class EmergencyActiveBanner extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const EmergencyActiveBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mode duress adalah mode senyap (stealth): jangan tampilkan banner darurat.
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;
    if (wasDuress) {
      return const SizedBox.shrink();
    }

    final sosState = ref.watch(sosProvider);
    final isActive = sosState.status == SOSStatus.active;
    final isQueued = sosState.status == SOSStatus.queuedOffline;

    if (!isActive && !isQueued) {
      return const SizedBox.shrink();
    }

    final title = isQueued ? 'SOS Tertunda Offline' : 'Mode Darurat SOS Aktif';
    final streamInfo = isQueued
        ? 'Menunggu sinyal untuk dikirim ke server'
        : [
            sosState.isGpsStreaming ? 'GPS Aktif' : 'GPS Mati',
            sosState.isAudioStreaming ? 'Audio Merekam' : 'Audio Mati',
            if (sosState.isVideoStreaming) 'Video Aktif',
          ].join(' • ');

    return Padding(
      padding: padding,
      child: MekaarBanner(
        color: MekaarColors.sosRed,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        icon: isQueued ? SolarIconsBold.cloudUpload : SolarIconsBold.danger,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: MekaarTypography.labelLG.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              streamInfo,
              style: MekaarTypography.bodySM.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Buka Layar Penuh SOS
            InkWell(
              onTap: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                Navigator.pushNamed(context, AppRoutes.sosActive);
              },
              borderRadius: BorderRadius.circular(MekaarRadius.sm),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Buka',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol Nonaktifkan SOS (Solid White, BUKAN MERAH, dengan PIN)
            InkWell(
              onTap: () async {
                HapticService.trigger(MekaarHapticIntent.selection);
                final pinVerified = await MekaarPinVerificationSheet.verify(
                  context,
                  title: isQueued
                      ? 'Batalkan SOS Tertunda'
                      : 'Nonaktifkan Mode Darurat',
                  subtitle:
                      'Masukkan 6 digit PIN untuk menghentikan pelacakan SOS',
                );

                if (pinVerified == true && context.mounted) {
                  await ref.read(sosProvider.notifier).endSOS();
                  HapticService.trigger(MekaarHapticIntent.success);
                  if (!context.mounted) return;
                  MekaarSnackbar.info(
                    context,
                    isQueued
                        ? 'SOS tertunda berhasil dibatalkan'
                        : 'Mode Darurat telah dinonaktifkan',
                  );
                }
              },
              borderRadius: BorderRadius.circular(MekaarRadius.sm),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white, // BUKAN MERAH — Putih solid kontras tinggi
                  borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SolarIconsBold.lock,
                      color: Color(0xFF1E293B), // Dark slate icon
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Akhiri',
                      style: TextStyle(
                        color: Color(0xFF1E293B), // Dark slate text
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
