import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/services/haptic_service.dart';

/// Hasil tangkapan dari layar kamera terpadu (foto atau video).
class CameraCaptureResult {
  final File file;
  final bool isVideo;
  final Duration? duration;

  const CameraCaptureResult({
    required this.file,
    required this.isVideo,
    this.duration,
  });
}

/// Layar kamera in-app terpadu dengan gesture:
/// - Ketuk sekali (Tap) pada tombol shutter: Jepret Foto
/// - Tekan & tahan (Hold) pada tombol shutter: Rekam Video
///
/// Mengadaptasi visual 1:1 sesuai standar modern obrolan (WhatsApp/Telegram).
class UnifiedCameraScreen extends StatefulWidget {
  final List<CameraDescription>? initialCameras;

  const UnifiedCameraScreen({
    super.key,
    this.initialCameras,
  });

  @override
  State<UnifiedCameraScreen> createState() => _UnifiedCameraScreenState();
}

class _UnifiedCameraScreenState extends State<UnifiedCameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  String? _errorMessage;

  // Flash mode cycling: off -> auto -> torch/always
  FlashMode _currentFlashMode = FlashMode.off;

  // Video recording state
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  static const Duration _maxVideoDuration = Duration(seconds: 60);

  // Focus point animation
  Offset? _focusPoint;
  Timer? _focusResetTimer;

  // Animation controller for shutter button expansion during video hold
  late AnimationController _shutterAnimController;
  late Animation<double> _shutterScaleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shutterAnimController = AnimationController(
      vsync: this,
      duration: MekaarMotion.normal,
    );
    _shutterScaleAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _shutterAnimController,
        curve: MekaarMotion.bounce,
      ),
    );

    _initializeCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _focusResetTimer?.cancel();
    _shutterAnimController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initializeCameras() async {
    try {
      if (widget.initialCameras != null) {
        _cameras = widget.initialCameras!;
      } else {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'Tidak ada sensor kamera yang terdeteksi di perangkat ini.';
          });
        }
        return;
      }

      // Default pilih kamera belakang jika tersedia
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;

      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Gagal mengakses kamera: $e';
        });
      }
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final prevController = _controller;
    if (prevController != null) {
      await prevController.dispose();
    }

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = newController;

    try {
      await newController.initialize();
      await newController.setFlashMode(_currentFlashMode);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Gagal menginisialisasi kamera: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() => _isInitializing = true);

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _cycleFlashMode() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isRecording) return;

    HapticService.trigger(MekaarHapticIntent.selection);
    FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await ctrl.setFlashMode(nextMode);
      if (mounted) {
        setState(() => _currentFlashMode = nextMode);
      }
    } catch (_) {}
  }

  void _onTapPreview(TapUpDetails details, BoxConstraints constraints) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isRecording) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    try {
      ctrl.setFocusPoint(offset);
      ctrl.setExposurePoint(offset);
    } catch (_) {}

    _focusResetTimer?.cancel();
    setState(() => _focusPoint = details.localPosition);
    _focusResetTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Future<void> _takePhoto() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isRecording) return;

    HapticService.trigger(MekaarHapticIntent.selection);

    try {
      final xFile = await ctrl.takePicture();
      if (!mounted) return;

      Navigator.pop(
        context,
        CameraCaptureResult(
          file: File(xFile.path),
          isVideo: false,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  Future<void> _startVideoRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isRecording) return;

    HapticService.trigger(MekaarHapticIntent.warning);
    _shutterAnimController.forward();

    try {
      await ctrl.startVideoRecording();
      if (!mounted) return;

      _recordingStartTime = DateTime.now();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted || !_isRecording) {
          t.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(_recordingStartTime!);
        setState(() => _recordingDuration = elapsed);

        if (elapsed >= _maxVideoDuration) {
          t.cancel();
          _stopVideoRecording();
        }
      });
    } catch (e) {
      _shutterAnimController.reverse();
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai perekaman: $e')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isRecordingVideo || !_isRecording) return;

    HapticService.trigger(MekaarHapticIntent.selection);
    _recordingTimer?.cancel();
    _shutterAnimController.reverse();

    try {
      final xFile = await ctrl.stopVideoRecording();
      final elapsed = _recordingDuration;

      if (!mounted) return;
      setState(() => _isRecording = false);

      // Jika durasi terlalu singkat (< 600ms), anggap tidak sengaja tertahan
      if (elapsed.inMilliseconds < 600) {
        return;
      }

      Navigator.pop(
        context,
        CameraCaptureResult(
          file: File(xFile.path),
          isVideo: true,
          duration: elapsed,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan rekaman: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              SolarIconsOutline.lightning,
              color: Colors.white70,
              size: 26,
            ),
            Transform.rotate(
              angle: -0.785,
              child: Container(
                width: 20,
                height: 2,
                color: Colors.white,
              ),
            ),
          ],
        );
      case FlashMode.auto:
        return const Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              SolarIconsOutline.lightning,
              color: Colors.white,
              size: 26,
            ),
            Positioned(
              right: -3,
              bottom: -1,
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      case FlashMode.always:
      case FlashMode.torch:
        return const Icon(
          SolarIconsBold.lightning,
          color: Colors.amberAccent,
          size: 26,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  SolarIconsOutline.videocamera,
                  color: Colors.white54,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Kamera Preview Layar Penuh
              GestureDetector(
                onTapUp: (details) => _onTapPreview(details, constraints),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1 / controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  ),
                ),
              ),

              // 2. Lingkaran Fokus Tap
              if (_focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 28,
                  top: _focusPoint!.dy - 28,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

              // 3. Header Atas: Tombol Tutup & Indikator Rekaman Video
              Positioned(
                top: topPadding + 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          SolarIconsOutline.closeCircle,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // 4. Area Kontrol Bawah (Persis Gambar 3):
              // Flash Toggle (Kiri) | Shutter (Tengah) | Switch Camera (Kanan)
              Positioned(
                bottom: bottomPadding + 20,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Baris Kontrol Utama
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tombol Flash (Kiri)
                          IconButton(
                            icon: _buildFlashIcon(),
                            tooltip: 'Flash',
                            onPressed: _cycleFlashMode,
                          ),

                          // Tombol Shutter Terpadu (Tengah)
                          GestureDetector(
                            onTap: _takePhoto,
                            onLongPressStart: (_) => _startVideoRecording(),
                            onLongPressEnd: (_) => _stopVideoRecording(),
                            onLongPressCancel: () => _stopVideoRecording(),
                            child: ScaleTransition(
                              scale: _shutterScaleAnim,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isRecording
                                        ? Colors.red
                                        : Colors.white,
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: context.motion(MekaarMotion.fast),
                                    width: _isRecording ? 36 : 64,
                                    height: _isRecording ? 36 : 64,
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? Colors.red
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        _isRecording ? 8 : 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Tombol Putar Kamera Depan/Belakang (Kanan)
                          IconButton(
                            icon: const Icon(
                              SolarIconsOutline.cameraRotate,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Putar Kamera',
                            onPressed: _cameras.length > 1
                                ? _switchCamera
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Teks Petunjuk (Persis Gambar 3)
                    Text(
                      _isRecording
                          ? 'Lepas untuk selesai merekam'
                          : 'Tap for photo, hold for video',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
