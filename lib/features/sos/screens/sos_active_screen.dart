import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
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
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startDurationTimer();
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

  void _startDurationTimer() {
    _updateElapsed();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateElapsed();
      }
    });
  }

  void _updateElapsed() {
    final sosState = ref.read(sosProvider);
    final startedAt =
        sosState.activeSession?.startedAt ?? sosState.activeSession?.createdAt;
    if (startedAt != null) {
      final diff = DateTime.now().difference(startedAt);
      if (mounted) {
        setState(() {
          _elapsed = diff.isNegative ? Duration.zero : diff;
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
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
    // Strict Rejection: allowDuress = false agar Duress PIN tidak dapat melumpuhkan darurat
    final pinVerified = await MekaarPinVerificationSheet.verify(
      context,
      title: isQueued ? 'Batalkan SOS Tertunda' : 'Nonaktifkan Mode Darurat',
      subtitle: 'Masukkan 6 digit PIN Utama untuk menghentikan pelacakan SOS',
      allowDuress: false,
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

    // 1. Update kolom message pada tabel sos_sessions secara instan di database
    final sosState = ref.read(sosProvider);
    final sessionId = sosState.activeSession?.id;
    if (sessionId != null) {
      try {
        final sosRepo = ref.read(sosRepositoryProvider);
        await sosRepo.updateSessionMessage(sessionId, templateText);
      } catch (_) {}
    }

    // 2. Kirim pesan ke room chat semua guardian aktif menggunakan guardian.guardianId
    if (!mounted) return;
    final activeGuardians = activeGuardiansOf(ref.read(guardianProvider));
    if (activeGuardians.isEmpty) {
      MekaarSnackbar.warning(
        context,
        'Pesan darurat tersimpan, namun tidak ada Guardian aktif yang terhubung.',
      );
      return;
    }

    final chatRepo = ref.read(chatRepositoryProvider);
    int sentCount = 0;

    for (final guardian in activeGuardians) {
      try {
        final roomId = await chatRepo.createRoom(
          guardian.guardianId,
          'guardian',
        );
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
        'Pesan senyap terkirim ke $sentCount Guardian & layar pantau.',
      );
    } else {
      MekaarSnackbar.warning(
        context,
        'Pesan darurat tersimpan di radar SOS.',
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
                color: MekaarColors.stealthTextMuted,
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
                      backgroundColor: MekaarColors.stealthCard,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        side: const BorderSide(
                          color: MekaarColors.stealthCardBorder,
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

  Widget _buildTelemetryChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required Color statusColor,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MekaarColors.stealthSurface,
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(color: MekaarColors.stealthCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: MekaarTypography.labelMD.copyWith(
              color: MekaarColors.stealthText,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: MekaarTypography.caption.copyWith(
              color: MekaarColors.stealthTextMuted,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: chip,
      );
    }
    return chip;
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

    final errorMessage = sosState.message;

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
              color: MekaarColors.stealthBg, // OLED PURE BLACK — ZERO GLOW DI TEMPAT GELAP
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
                          color: MekaarColors.stealthSurface,
                          borderRadius: BorderRadius.circular(MekaarRadius.pill),
                          border: Border.all(
                            color: MekaarColors.stealthCardBorder,
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
                                  color: MekaarColors.stealthDanger,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                        if (isActive) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: MekaarColors.stealthSurface,
                              borderRadius:
                                  BorderRadius.circular(MekaarRadius.pill),
                              border: Border.all(
                                color: MekaarColors.stealthCardBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  SolarIconsOutline.stopwatch,
                                  size: 16,
                                  color: MekaarColors.stealthTextMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_elapsed),
                                  style: MekaarTypography.monoLG.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: MekaarColors.stealthText,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.stealthSuccess
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'LIVE',
                                    style: MekaarTypography.labelSM.copyWith(
                                      color: MekaarColors.stealthSuccess,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (errorMessage != null &&
                            sosState.status == SOSStatus.failed) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: MekaarTypography.bodyMD.copyWith(
                              color: MekaarColors.stealthWarning,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // ── Cockpit Telemetry HUD: Grid 2x2 ──
                        Row(
                          children: [
                            Expanded(
                              child: _buildTelemetryChip(
                                icon: sosState.isGpsStreaming
                                    ? SolarIconsBold.mapPoint
                                    : sosState.locationPermissionDenied
                                        ? SolarIconsBold.mapPointRemove
                                        : SolarIconsOutline.mapPoint,
                                iconColor: sosState.isGpsStreaming
                                    ? MekaarColors.stealthSuccess
                                    : sosState.locationPermissionDenied
                                        ? MekaarColors.stealthWarning
                                        : MekaarColors.stealthTextMuted,
                                label: sosState.isGpsStreaming
                                    ? 'GPS LIVE'
                                    : sosState.locationPermissionDenied
                                        ? 'GPS DITOLAK'
                                        : 'GPS MATI',
                                sublabel: sosState.isGpsStreaming
                                    ? 'Koordinat aktif'
                                    : sosState.locationPermissionDenied
                                        ? 'Izin ditolak'
                                        : 'Lokasi off',
                                statusColor: sosState.isGpsStreaming
                                    ? MekaarColors.stealthSuccess
                                    : sosState.locationPermissionDenied
                                        ? MekaarColors.stealthWarning
                                        : MekaarColors.stealthTextMuted,
                                onTap: sosState.locationPermissionDenied
                                    ? () => MekaarDialog
                                        .showLocationPermissionDeniedWarning(
                                            context: context)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTelemetryChip(
                                icon: sosState.isAudioStreaming
                                    ? SolarIconsBold.microphone
                                    : sosState.micPermissionDenied
                                        ? SolarIconsBold.muted
                                        : SolarIconsOutline.muted,
                                iconColor: sosState.isAudioStreaming
                                    ? MekaarColors.stealthSuccess
                                    : sosState.micPermissionDenied
                                        ? MekaarColors.stealthWarning
                                        : MekaarColors.stealthTextMuted,
                                label: sosState.isAudioStreaming
                                    ? 'AUDIO LIVE'
                                    : sosState.micPermissionDenied
                                        ? 'AUDIO DITOLAK'
                                        : 'AUDIO MATI',
                                sublabel: sosState.isAudioStreaming
                                    ? 'Suara live'
                                    : sosState.micPermissionDenied
                                        ? 'Izin mic ditolak'
                                        : 'Mic nonaktif',
                                statusColor: sosState.isAudioStreaming
                                    ? MekaarColors.stealthSuccess
                                    : sosState.micPermissionDenied
                                        ? MekaarColors.stealthWarning
                                        : MekaarColors.stealthTextMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTelemetryChip(
                                icon: activeGuardians.isNotEmpty
                                    ? SolarIconsBold.shieldUser
                                    : SolarIconsOutline.shieldWarning,
                                iconColor: activeGuardians.isNotEmpty
                                    ? MekaarColors.guardianTeal
                                    : MekaarColors.stealthWarning,
                                label: activeGuardians.isNotEmpty
                                    ? '${activeGuardians.length} GUARDIAN'
                                    : '0 GUARDIAN',
                                sublabel: activeGuardians.isNotEmpty
                                    ? activeGuardians.take(2).join(', ')
                                    : 'Belum terhubung',
                                statusColor: activeGuardians.isNotEmpty
                                    ? MekaarColors.guardianTeal
                                    : MekaarColors.stealthWarning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTelemetryChip(
                                icon: isQueued
                                    ? SolarIconsBold.cloudUpload
                                    : SolarIconsBold.cloudCheck,
                                iconColor: isQueued
                                    ? MekaarColors.stealthWarning
                                    : MekaarColors.stealthSuccess,
                                label: isQueued ? 'OFFLINE' : 'TERHUBUNG',
                                sublabel: isQueued
                                    ? 'Antrean lokal'
                                    : 'Radar cloud aktif',
                                statusColor: isQueued
                                    ? MekaarColors.stealthWarning
                                    : MekaarColors.stealthSuccess,
                              ),
                            ),
                          ],
                        ),
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
                                backgroundColor: MekaarColors.stealthSurface,
                                side: const BorderSide(color: MekaarColors.stealthCardBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(MekaarRadius.md),
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
                                foregroundColor: MekaarColors.stealthText,
                                side: const BorderSide(color: MekaarColors.stealthCardBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(MekaarRadius.md),
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
                                          MekaarColors.stealthCard,
                                      foregroundColor:
                                          Colors.white,
                                      elevation: 0,
                                      side: const BorderSide(
                                        color: MekaarColors.stealthCardBorder,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(MekaarRadius.md),
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
                                    color: MekaarColors.stealthTextMuted,
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
                                color: MekaarColors.stealthSurface, // Dark slate icon
                                size: 20,
                              ),
                              label: Text(
                                isQueued
                                    ? 'Batalkan SOS (Perlu PIN)'
                                    : 'Nonaktifkan SOS (Perlu PIN)',
                                style: const TextStyle(
                                  color: MekaarColors.stealthSurface, // Dark slate text
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white, // BUKAN MERAH — Putih solid
                                foregroundColor: MekaarColors.stealthSurface,
                                elevation: 4,
                                shadowColor: Colors.black.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(MekaarRadius.md),
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
                              color: MekaarColors.stealthTextMuted,
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
