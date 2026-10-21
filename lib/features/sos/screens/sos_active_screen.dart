import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/motion.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/screen_protection_provider.dart';
import '../../guardian/providers/guardian_provider.dart';
import '../providers/sos_provider.dart';

class SOSActiveScreen extends ConsumerStatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  ConsumerState<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends ConsumerState<SOSActiveScreen> {
  bool _hasShownLocationWarning = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(screenProtectionControllerProvider)
          .enterMandatorySurface('sos_active');
      final sosState = ref.read(sosProvider);
      if (sosState.status == SOSStatus.idle) {
        ref
            .read(sosProvider.notifier)
            .activateSOS(gps: true, mic: true, video: false);
      } else if (sosState.locationPermissionDenied &&
          !_hasShownLocationWarning &&
          mounted) {
        _hasShownLocationWarning = true;
        MekaarDialog.showLocationPermissionDeniedWarning(context: context);
      }
    });
  }

  @override
  void dispose() {
    try {
      ref
          .read(screenProtectionControllerProvider)
          .leaveMandatorySurface('sos_active');
    } catch (_) {}
    super.dispose();
  }

  void _handleEndSOS(SOSState sosState) async {
    final isQueued = sosState.status == SOSStatus.queuedOffline;

    // Wajib verifikasi PIN keamanan 6-digit untuk menonaktifkan SOS
    final pinVerified = await MekaarPinVerificationSheet.verify(
      context,
      title: isQueued ? 'Batalkan SOS Tertunda' : 'Nonaktifkan Mode Darurat',
      subtitle: 'Masukkan 6 digit PIN untuk menghentikan pelacakan SOS',
    );

    if (pinVerified != true || !mounted) return;

    await ref.read(sosProvider.notifier).endSOS();
    if (!mounted) return;
    final current = ref.read(sosProvider);
    if (current.status == SOSStatus.idle) {
      HapticService.trigger(MekaarHapticIntent.success);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context);
    } else if (current.message != null) {
      MekaarSnackbar.error(context, current.message!);
    }
  }

  Future<void> _sendSilentEmergencyMessage(String templateText) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final activeGuardians = activeGuardiansOf(ref.read(guardianProvider));
    if (activeGuardians.isEmpty) {
      MekaarSnackbar.warning(
        context,
        'Tidak ada Guardian aktif yang terhubung.',
      );
      return;
    }

    final chatRepo = ref.read(chatRepositoryProvider);
    int sentCount = 0;

    for (final guardian in activeGuardians) {
      try {
        final roomId = await chatRepo.createRoom(guardian.id, 'guardian');
        await chatRepo.sendMessage(
          roomId,
          '🚨 [PESAN DARURAT SENYAP]: $templateText',
        );
        sentCount++;
      } catch (_) {}
    }

    if (!mounted) return;
    if (sentCount > 0) {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.info(
        context,
        'Pesan senyap berhasil dikirim ke $sentCount Guardian',
      );
    } else {
      MekaarSnackbar.error(
        context,
        'Gagal mengirimkan pesan senyap ke Guardian.',
      );
    }
  }

  void _showSilentEmergencyDispatchSheet() {
    HapticService.trigger(MekaarHapticIntent.selection);
    const templates = [
      'Jangan telepon saya! Saya sedang sembunyi',
      'Pelaku membawa senjata',
      'Tolong segera hubungi polisi / bantuan ke lokasi saya',
      'Saya dalam bahaya akut, ikuti pergerakan GPS saya',
    ];

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Container(
        color: const Color(0xFF0F172A), // Stealth dark slate
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  SolarIconsBold.chatRoundDots,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Kirim Pesan Senyap ke Guardian',
                  style: MekaarTypography.labelLG.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih pesan darurat terverifikasi untuk dikirim instan tanpa suara ke seluruh Guardian aktif:',
              style: MekaarTypography.bodySM.copyWith(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ...templates.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendSilentEmergencyMessage(text);
                    },
                    child: Row(
                      children: [
                        const Icon(
                          SolarIconsOutline.shieldWarning,
                          color: MekaarColors.warnAmber,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      sosProvider.select((s) => s.locationPermissionDenied),
      (prev, next) {
        if (next && !_hasShownLocationWarning && mounted) {
          _hasShownLocationWarning = true;
          MekaarDialog.showLocationPermissionDeniedWarning(context: context);
        }
      },
    );

    final sosState = ref.watch(sosProvider);
    final activeGuardians = activeGuardiansOf(
      ref.watch(guardianProvider),
    ).map((guardian) => guardian.name).toList();
    final isActive = sosState.status == SOSStatus.active;
    final isQueued = sosState.status == SOSStatus.queuedOffline;
    final canEnd = isActive || sosState.status == SOSStatus.queuedOffline;

    final title = switch (sosState.status) {
      SOSStatus.idle => 'MENYIAPKAN SOS',
      SOSStatus.activating => 'MENGAKTIFKAN SOS',
      SOSStatus.active => 'MODE DARURAT AKTIF',
      SOSStatus.queuedOffline => 'SOS TERTUNDA OFFLINE',
      SOSStatus.failed => 'SOS GAGAL DIMULAI',
      SOSStatus.ending => 'MENGAKHIRI SOS',
    };

    final statusText = switch (sosState.status) {
      SOSStatus.active when sosState.message != null => sosState.message!,
      SOSStatus.active when activeGuardians.isEmpty =>
        'SOS tercatat aktif. Tidak ada Guardian aktif yang terhubung ke akun Anda. Tambahkan Guardian setelah Anda berada di tempat aman.',
      SOSStatus.active =>
        'SOS tercatat aktif. Guardian yang terhubung: ${activeGuardians.join(', ')}. '
            '${sosState.isGpsStreaming
                ? 'Lokasi perangkat dibagikan.'
                : sosState.locationPermissionDenied
                    ? 'Lokasi tidak tersedia karena izin lokasi ditolak.'
                    : 'Lokasi perangkat tidak dibagikan.'} '
            '${sosState.isAudioStreaming
                ? 'Audio perangkat dibagikan.'
                : sosState.micPermissionDenied
                ? 'Audio tidak tersedia karena izin mikrofon ditolak.'
                : 'Audio perangkat tidak dibagikan.'}',
      SOSStatus.queuedOffline =>
        sosState.message ?? 'SOS belum terkirim dan menunggu koneksi.',
      SOSStatus.failed => sosState.message ?? 'SOS gagal dimulai. Coba lagi.',
      SOSStatus.ending => 'Sedang memastikan SOS berakhir dengan aman.',
      _ =>
        'Menunggu konfirmasi sesi. Guardian belum menerima status pelacakan.',
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          MekaarSnackbar.warning(
            context,
            'Aplikasi terkunci dalam Mode Darurat. Masukkan PIN untuk menonaktifkan SOS.',
          );
        }
      },
      child: MekaarScaffold(
        flat: true,
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF000000), // OLED PURE BLACK — ZERO GLOW DI TEMPAT GELAP
            ),
            child: Column(
              children: [
                // Header Navigasi Taktis: Indikator Terkunci Tanpa Tombol Keluar Biasa
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: MekaarColors.sosRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isQueued
                                  ? 'SOS TERTUNDA OFFLINE'
                                  : 'MODE DARURAT TERKUNCI',
                              style: MekaarTypography.labelSM.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1, end: 1.15),
                          duration: const Duration(seconds: 1),
                          builder: (context, value, child) => Container(
                            width: 130 * value,
                            height: 130 * value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E0A0A).withValues(
                                alpha: 0.25 * (1.15 - value) / 0.15,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1E0A0A),
                                ),
                                child: Icon(
                                  isQueued
                                      ? SolarIconsBold.cloudUpload
                                      : SolarIconsBold.danger,
                                  color: const Color(0xFFEF4444),
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: MekaarTypography.monoLG.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: MekaarTypography.bodyMD.copyWith(
                            color: const Color(0xFF94A3B8), // Soft slate grey
                            height: 1.5,
                          ),
                        ),
                        if (isActive &&
                            (sosState.micPermissionDenied ||
                                sosState.locationPermissionDenied)) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              if (sosState.locationPermissionDenied)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.warnAmber,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    'Izin Lokasi Ditolak',
                                    style: MekaarTypography.labelLG.copyWith(
                                      color: MekaarColors.textOnYellow,
                                    ),
                                  ),
                                ),
                              if (sosState.micPermissionDenied)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.warnAmber,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    'Izin Mikrofon Ditolak',
                                    style: MekaarTypography.labelLG.copyWith(
                                      color: MekaarColors.textOnYellow,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (isActive) ...[
                          // Tombol Kirim Pesan Senyap ke Guardian (Eksklusif Template Terverifikasi)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                SolarIconsBold.chatRoundDots,
                                color: Colors.white,
                              ),
                              label: const Text('Kirim Pesan Senyap ke Guardian'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFF334155)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _showSilentEmergencyDispatchSheet,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              icon: const Icon(SolarIconsOutline.gps),
                              label: const Text('Lihat Lokasi Saya'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE2E8F0),
                                side: const BorderSide(color: Color(0xFF334155)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final result = await ref
                                    .read(sosProvider.notifier)
                                    .getOwnSessionWithPing();
                                if (!context.mounted) return;
                                final ping = result?['ping'] as Map?;
                                if (ping == null) {
                                  MekaarSnackbar.warning(
                                    context,
                                    'Lokasi belum tersedia',
                                  );
                                  return;
                                }
                                navigator.pushNamed(
                                  AppRoutes.map,
                                  arguments: {
                                    'latitude': ping['latitude'] as double,
                                    'longitude': ping['longitude'] as double,
                                    'locationName': 'Lokasi Saya',
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedAppear(
                            delay: MekaarMotion.staggerStep,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      SolarIconsOutline.videocameraRecord,
                                    ),
                                    label: const Text(
                                      'Siarkan Video & Rekam Darurat',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1E293B),
                                      foregroundColor:
                                          Colors.white,
                                      elevation: 0,
                                      side: const BorderSide(
                                        color: Color(0xFF334155),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.sosVideo,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Streaming langsung ke layar Guardian secara real-time',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Tombol Nonaktifkan SOS (Solid White, BUKAN MERAH, dengan PIN)
                        if (canEnd) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                SolarIconsBold.lock,
                                color: Color(0xFF0F172A), // Dark slate icon
                                size: 20,
                              ),
                              label: Text(
                                isQueued
                                    ? 'Batalkan SOS (Perlu PIN)'
                                    : 'Nonaktifkan SOS (Perlu PIN)',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A), // Dark slate text
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white, // BUKAN MERAH — Putih solid
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 4,
                                shadowColor: Colors.black.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => _handleEndSOS(sosState),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Wajib 6 digit PIN untuk memastikan hanya Anda yang dapat menonaktifkan SOS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                        if (sosState.status == SOSStatus.failed) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () => ref
                                  .read(sosProvider.notifier)
                                  .activateSOS(
                                    gps: true,
                                    mic: true,
                                    video: false,
                                  ),
                              child: const Text('Coba Lagi'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
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
