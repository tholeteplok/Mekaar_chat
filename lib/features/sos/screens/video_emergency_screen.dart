import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/services/sos_streaming_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../chat/providers/screen_protection_provider.dart';
import '../providers/sos_provider.dart';

class VideoEmergencyScreen extends ConsumerStatefulWidget {
  const VideoEmergencyScreen({super.key});

  @override
  ConsumerState<VideoEmergencyScreen> createState() =>
      _VideoEmergencyScreenState();
}

class _VideoEmergencyScreenState extends ConsumerState<VideoEmergencyScreen> {
  late final SosStreamingService _streamingService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isFrontCamera = true;
  bool _isScreenLocked = false;
  Timer? _timer;
  int _recordingSeconds = 0;
  SosStreamState _streamState = SosStreamState.idle;

  // Durasi maksimal rekaman sebelum otomatis berhenti (menit). 0 = tanpa batas.
  int _autoStopMinutes = 0;
  final List<int> _autoStopOptions = const [0, 5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _streamingService = SosStreamingService(Supabase.instance.client);
    _streamingService.onStreamStateChange = (state) {
      if (mounted) setState(() => _streamState = state);
    };
    _streamingService.onViewerJoined = () {
      if (mounted) {
        MekaarSnackbar.info(context, 'Guardian telah bergabung ke siaran video Anda.');
      }
    };

    Future.microtask(() {
      ref
          .read(screenProtectionControllerProvider)
          .enterMandatorySurface('sos_video');
    });
    _initVideo();
    _startTimer();
  }

  void _dismissInactivityPrompt() {
    ref.read(sosProvider.notifier).acknowledgeInactivity();
  }

  Future<void> _initVideo() async {
    try {
      await _localRenderer.initialize();
      final stream = await _streamingService.initLocalMedia(
        audio: true,
        video: true,
        isFrontCamera: _isFrontCamera,
      );

      if (stream != null) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
        ref.read(sosProvider.notifier).toggleVideo(true);

        // Mulai broadcast ke Guardian jika sesi SOS aktif
        final currentSos = ref.read(sosProvider);
        final sessionId = currentSos.activeSession?.id;
        final userId = SupabaseService().currentUserId;

        if (sessionId != null && userId != null) {
          await _streamingService.startBroadcast(
            sessionId: sessionId,
            myUserId: userId,
          );
        }
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isScreenLocked) {
        setState(() => _recordingSeconds++);
      }
      if (_autoStopMinutes > 0 && _recordingSeconds >= _autoStopMinutes * 60) {
        _stopRecording();
      }
    });
  }

  void _setAutoStop(int minutes) {
    setState(() => _autoStopMinutes = minutes);
    if (mounted) {
      MekaarSnackbar.info(
        context,
        minutes == 0
            ? 'Rekaman tanpa batas waktu.'
            : 'Rekaman berhenti otomatis dalam $minutes menit.',
      );
    }
  }

  void _showAutoStopSheet() {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Henti Otomatis Setelah',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ..._autoStopOptions.map(
            (m) => ListTile(
              title: Text(m == 0 ? 'Tanpa batas' : '$m menit'),
              trailing: _autoStopMinutes == m
                  ? const Icon(
                      SolarIconsOutline.checkCircle,
                      color: MekaarColors.guardianTeal,
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _setAutoStop(m);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    await _streamingService.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _toggleScreenLock() {
    setState(() => _isScreenLocked = !_isScreenLocked);
    if (_isScreenLocked && mounted) {
      MekaarSnackbar.info(
        context,
        'Layar Terkunci. Ketuk 2x di mana saja untuk membuka.',
      );
    }
  }

  void _stopRecording() {
    _timer?.cancel();
    final currentSos = ref.read(sosProvider);
    final sessionId = currentSos.activeSession?.id;
    final userId = SupabaseService().currentUserId;

    if (sessionId != null && userId != null) {
      _streamingService.stopStream(sessionId, userId);
    } else {
      _streamingService.cleanUp();
    }

    _localRenderer.dispose();
    ref.read(sosProvider.notifier).toggleVideo(false);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamingService.cleanUp();
    _localRenderer.dispose();
    ref
        .read(screenProtectionControllerProvider)
        .leaveMandatorySurface('sos_video');
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Preview
          if (_localRenderer.srcObject != null)
            Positioned.fill(
              child: RTCVideoView(
                _localRenderer,
                mirror: _isFrontCamera,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Inactivity prompt
          if (sosState.needsInactivityAck)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                    border: Border.all(color: MekaarColors.warnAmber, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(SolarIconsBold.shieldWarning,
                              color: MekaarColors.warnAmber, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Apakah Anda Aman?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Perangkat Anda terdeteksi tidak bergerak. Sentuh layar atau tekan tombol di bawah jika Anda masih memerlukan rekaman ini.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MekaarColors.warnAmber,
                            foregroundColor: MekaarColors.textOnYellow,
                          ),
                          onPressed: _dismissInactivityPrompt,
                          child: const Text(
                            'Saya Masih Butuh Rekaman Ini',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Screen Lock Overlay
          if (_isScreenLocked)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _toggleScreenLock,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.95),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(SolarIconsOutline.lock,
                              color: Colors.white70, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Kamera & Mic Tetap Merekam',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          // Instruksi jalan keluar dari lock mode — harus
                          // selalu terbaca di atas latar hitam pekat.
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Ketuk 2x untuk membuka kontrol layar',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ),
            ),

          // Non-locked Controls Overlay
          if (!_isScreenLocked) ...[
            // Top Bar: Timer, Stream Status, REC Indicator
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatDuration(_recordingSeconds),
                          style: MekaarTypography.monoMD.copyWith(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Stream Status Dot
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              MekaarIcons.circle,
                              color: _streamState == SosStreamState.streaming
                                  ? MekaarColors.safeTeal
                                  : (_streamState == SosStreamState.waitingForViewer
                                      ? MekaarColors.warnAmber
                                      : MekaarColors.cyan),
                              size: 8,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _streamState == SosStreamState.streaming
                                  ? 'Siaran Langsung ke Guardian'
                                  : (_streamState == SosStreamState.waitingForViewer
                                      ? 'Menunggu Guardian…'
                                      : 'Kamera & Mic Aktif'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // REC Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: MekaarColors.sosRed,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'REC',
                              style: TextStyle(
                                color: MekaarColors.sosRed,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom Action buttons
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlBtn(
                    icon: SolarIconsOutline.refresh,
                    label: 'Kamera',
                    onTap: _switchCamera,
                  ),
                  _buildControlBtn(
                    icon: SolarIconsOutline.stopwatch,
                    label: 'Timer',
                    onTap: _showAutoStopSheet,
                  ),
                  _buildControlBtn(
                    icon: SolarIconsOutline.lock,
                    label: 'Kunci',
                    onTap: _toggleScreenLock,
                  ),
                  _buildControlBtn(
                    icon: SolarIconsBold.stop,
                    label: 'Stop',
                    onTap: _stopRecording,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDestructive ? MekaarColors.sosRed : Colors.black45,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
