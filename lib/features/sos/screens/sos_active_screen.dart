import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mika_animated.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
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
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    Future.microtask(() {
      ref
          .read(screenProtectionControllerProvider)
          .enterMandatorySurface('sos_active');
      ref
          .read(sosProvider.notifier)
          .activateSOS(gps: true, mic: true, video: false);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
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
        _confettiController.play();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
                  IgnorePointer(
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      colors: const [
                        MekaarColors.yellow,
                        MekaarColors.cyan,
                        MekaarColors.pink,
                        MekaarColors.lime,
                      ],
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      numberOfParticles: 30,
                      gravity: 0.3,
                      emissionFrequency: 0.05,
                    ),
                  ),
                  MikaAnimated(
                    pose: MikaPose.shield,
                    size: 48,
                    idle: false,
                  ),
                  const SizedBox(height: 8),
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
                        color: MekaarColors.warningLight,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Izin Mikrofon Ditolak',
                        style: MekaarTypography.labelMD.copyWith(
                          color: MekaarColors.warning,
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
                          final messenger = ScaffoldMessenger.of(context);
                          final result = await ref
                              .read(sosProvider.notifier)
                              .getOwnSessionWithPing();
                          if (!mounted) return;
                          final ping = result?['ping'] as Map?;
                          if (ping == null) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Lokasi belum tersedia'),
                              ),
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(MekaarIcons.videocam),
                        label: const Text('Kirim Video ke Guardian'),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/sos/video'),
                      ),
                    ).animate().fadeIn(duration: 200.ms, delay: 100.ms),
                  ],
                  if (canEnd)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: const Icon(SolarIconsOutline.closeSquare, color: MekaarColors.sosRed),
                        label: Text(
                          sosState.status == SOSStatus.queuedOffline
                              ? 'Batalkan SOS Tertunda'
                              : 'Akhiri Mode Darurat',
                          style: const TextStyle(color: MekaarColors.sosRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: MekaarColors.sosRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _handleEndSOS(sosState),
                      ),
                    ).animate().fadeIn(duration: 200.ms),
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
