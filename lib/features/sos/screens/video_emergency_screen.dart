import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../data/services/webrtc_service.dart';
import '../providers/sos_provider.dart';

class VideoEmergencyScreen extends ConsumerStatefulWidget {
  const VideoEmergencyScreen({super.key});

  @override
  ConsumerState<VideoEmergencyScreen> createState() =>
      _VideoEmergencyScreenState();
}

class _VideoEmergencyScreenState extends ConsumerState<VideoEmergencyScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isFrontCamera = true;
  bool _isScreenLocked = false;
  int _recordingSeconds = 0;
  Timer? _timer;

  // Durasi maksimal rekaman sebelum otomatis berhenti (menit). 0 = tanpa batas.
  int _autoStopMinutes = 0;
  final List<int> _autoStopOptions = const [0, 5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _initVideo();
    _startTimer();
  }

  void _dismissInactivityPrompt() {
    ref.read(sosProvider.notifier).acknowledgeInactivity();
  }

  Future<void> _initVideo() async {
    await _localRenderer.initialize();
    try {
      final stream = await _webrtcService.getLocalStream(
        audio: true,
        video: true,
        isFrontCamera: _isFrontCamera,
      );
      setState(() {
        _localRenderer.srcObject = stream;
      });
      ref.read(sosProvider.notifier).toggleVideo(true);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          minutes == 0
              ? 'Rekaman tanpa batas waktu.'
              : 'Rekaman berhenti otomatis dalam $minutes menit.',
        ),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _showAutoStopSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    await _webrtcService.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _toggleScreenLock() {
    setState(() => _isScreenLocked = !_isScreenLocked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isScreenLocked
              ? 'Layar dikunci. Video streaming tetap berjalan di latar belakang.'
              : 'Layar dibuka.',
        ),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _stopRecording() async {
    ref.read(sosProvider.notifier).toggleVideo(false);
    await _webrtcService.cleanUp();
    _localRenderer.srcObject = null;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _localRenderer.dispose();
    _webrtcService.cleanUp();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Local Camera Feed View
          _localRenderer.srcObject != null
              ? SizedBox.expand(
                  child: RTCVideoView(_localRenderer, mirror: _isFrontCamera),
                )
              : const Center(
                  child: CircularProgressIndicator(color: MekaarColors.sosRed),
                ),

          // Locked Screen Dark Overlay
          if (_isScreenLocked)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      SolarIconsBold.lock,
                      size: 64,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Layar Terkunci Secara Aman',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Streaming kamera terus berjalan.',
                      style: TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      icon: const Icon(SolarIconsOutline.lockUnlocked),
                      label: const Text('Buka Layar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                      ),
                      onPressed: _toggleScreenLock,
                    ),
                  ],
                ),
              ),
            ),

          // Inactivity prompt "Apakah Anda Aman?" (blind spot #7)
          if (ref.watch(sosProvider).needsInactivityAck && !_isScreenLocked)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MekaarColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        SolarIconsOutline.heart,
                        color: MekaarColors.sosRed,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Apakah Anda Aman?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ketuk untuk melanjutkan rekam. Jika tidak ada respon, streaming dihentikan otomatis untuk menjaga privasi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _dismissInactivityPrompt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.guardianTeal,
                        ),
                        child: const Text('Saya Aman, Lanjutkan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Status HUD controls (Hidden when screen is locked)
          if (!_isScreenLocked) ...[
            // Status Indicator Dot (OS Green indicator)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 8),
                        SizedBox(width: 6),
                        Text(
                          'Kamera & Mic Aktif',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Recording Flash Indicators
            Positioned(
              top: 40,
              right: 20,
              child: Container(
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
            ),
            // Timer Indicator
            Positioned(
              top: 40,
              left: 20,
              child: Container(
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
            ),
            // Bottom Action buttons
            Positioned(
              bottom: 40,
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
    return GestureDetector(
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
    );
  }
}
