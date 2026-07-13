import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/constants/colors.dart';
import '../../../data/services/webrtc_service.dart';
import '../providers/sos_provider.dart';

class VideoEmergencyScreen extends ConsumerStatefulWidget {
  const VideoEmergencyScreen({super.key});

  @override
  ConsumerState<VideoEmergencyScreen> createState() => _VideoEmergencyScreenState();
}

class _VideoEmergencyScreenState extends ConsumerState<VideoEmergencyScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isFrontCamera = true;
  bool _isScreenLocked = false;
  int _recordingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _startTimer();
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
    });
  }

  Future<void> _switchCamera() async {
    await _webrtcService.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  void _toggleScreenLock() {
    setState(() => _isScreenLocked = !_isScreenLocked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isScreenLocked 
            ? 'Layar dikunci. Video streaming tetap berjalan di latar belakang.'
            : 'Layar dibuka.'
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
              ? SizedBox.expand(child: RTCVideoView(_localRenderer, mirror: _isFrontCamera))
              : const Center(child: CircularProgressIndicator(color: MekaarColors.sosRed)),

          // Locked Screen Dark Overlay
          if (_isScreenLocked)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 64, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      'Layar Terkunci Secara Aman',
                      style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Streaming kamera terus berjalan.',
                      style: TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: MekaarColors.sosRed),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'REC',
                      style: TextStyle(color: MekaarColors.sosRed, fontSize: 11, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_recordingSeconds),
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
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
                    icon: Icons.flip_camera_ios,
                    label: 'Kamera',
                    onTap: _switchCamera,
                  ),
                  _buildControlBtn(
                    icon: Icons.lock_outline,
                    label: 'Kunci',
                    onTap: _toggleScreenLock,
                  ),
                  _buildControlBtn(
                    icon: Icons.stop,
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
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
