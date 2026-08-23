import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/hold_to_confirm_button.dart';
import '../../chat/providers/screen_protection_provider.dart';
import '../../guardian/providers/guardian_provider.dart';
import '../providers/sos_provider.dart';

class SOSActiveScreen extends ConsumerStatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  ConsumerState<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends ConsumerState<SOSActiveScreen> {
  bool _allowPop = false;

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
      }
    });
  }

  @override
  void dispose() {
    ref
        .read(screenProtectionControllerProvider)
        .leaveMandatorySurface('sos_active');
    super.dispose();
  }

  void _handleEndSOS(SOSState sosState) async {
    final isQueued = sosState.status == SOSStatus.queuedOffline;
    final confirmed = await MekaarDialog.showConfirmation<bool>(
      context: context,
      title: isQueued ? 'Batalkan SOS Tertunda?' : 'Akhiri Mode Darurat?',
      message: isQueued
          ? 'Permintaan SOS akan dihapus dari perangkat dan tidak dikirim saat koneksi kembali.'
          : 'Sesi SOS aktif, akses lokasi, dan perekaman audio akan dihentikan.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isQueued ? 'Batalkan' : 'Akhiri',
            style: const TextStyle(
              color: MekaarColors.sosRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    if (confirmed == true && mounted) {
      await ref.read(sosProvider.notifier).endSOS();
      if (!mounted) return;
      final current = ref.read(sosProvider);
      if (current.status == SOSStatus.idle) {
        HapticService.trigger(MekaarHapticIntent.success);
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        Navigator.pop(context);
      } else if (current.message != null) {
        MekaarSnackbar.error(context, current.message!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);
    final activeGuardians = activeGuardiansOf(
      ref.watch(guardianProvider),
    ).map((guardian) => guardian.name).toList();
    final isActive = sosState.status == SOSStatus.active;
    final useEmergencyForeground = isActive;
    final statusTitleColor = useEmergencyForeground
        ? Colors.white
        : MekaarColors.textPrimaryOf(context);
    final statusBodyColor = useEmergencyForeground
        ? Colors.white.withValues(alpha: 0.7)
        : MekaarColors.textSecondaryOf(context);
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
            '${sosState.isGpsStreaming ? 'Lokasi perangkat dibagikan.' : 'Lokasi perangkat tidak dibagikan.'} '
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
      canPop: _allowPop || sosState.status == SOSStatus.failed,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final message = isActive
            ? 'SOS masih aktif. Akhiri Mode Darurat sebelum kembali.'
            : sosState.status == SOSStatus.queuedOffline
            ? 'SOS masih tertunda. Batalkan SOS tertunda sebelum kembali.'
            : 'Proses SOS belum selesai. Tunggu konfirmasi status.';
        MekaarSnackbar.info(context, message);
      },
      child: MekaarScaffold(
        flat: true,
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  MekaarColors.sosRed.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: 1.15),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) => Container(
                      width: 140 * value,
                      height: 140 * value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MekaarColors.sosRed.withValues(
                          alpha: 0.18 * (1.15 - value) / 0.15,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MekaarColors.sosRed,
                          ),
                          child: const Icon(
                            SolarIconsBold.danger,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: MekaarTypography.monoLG.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: statusTitleColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: MekaarTypography.bodyMD.copyWith(
                      color: statusBodyColor,
                      height: 1.5,
                    ),
                  ),
                  if (isActive && sosState.micPermissionDenied) ...[
                    const SizedBox(height: 12),
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
                  if (isActive) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: const Icon(SolarIconsOutline.gps),
                        label: const Text('Lihat Lokasi Saya'),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final result = await ref
                              .read(sosProvider.notifier)
                              .getOwnSessionWithPing();
                          if (!context.mounted) return;
                          final ping = result?['ping'] as Map?;
                          if (ping == null) {
                            MekaarSnackbar.warning(context, 'Lokasi belum tersedia');
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
                    const SizedBox(height: 14),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: const Icon(SolarIconsOutline.videocameraRecord),
                            label: const Text('Siarkan Video & Rekam Darurat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MekaarColors.surface2Of(context),
                              foregroundColor: MekaarColors.textPrimaryOf(context),
                              elevation: 0,
                              side: BorderSide(
                                color: MekaarColors.cardBorderOf(context),
                              ),
                            ),
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.sosVideo),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Streaming langsung ke layar Guardian secara real-time',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: MekaarColors.textMutedOf(context),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 200.ms, delay: 100.ms),
                  ],
                  if (canEnd) ...[
                    const SizedBox(height: 8),
                    HoldToConfirmButton(
                      duration: const Duration(seconds: 3),
                      label: sosState.status == SOSStatus.queuedOffline
                          ? 'Batalkan SOS'
                          : 'Akhiri Mode Darurat',
                      onTrigger: () => _handleEndSOS(sosState),
                    ).animate().fadeIn(duration: 200.ms),
                  ],
                  if (sosState.status == SOSStatus.failed)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => ref
                            .read(sosProvider.notifier)
                            .activateSOS(gps: true, mic: true, video: false),
                        child: const Text('Coba Lagi'),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
