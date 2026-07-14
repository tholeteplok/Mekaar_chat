import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../data/models/sos_session_model.dart';
import '../../../data/repositories/sos_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/audio_service.dart';
import '../../auth/providers/auth_provider.dart';

// Repository Provider
final sosRepositoryProvider = Provider<SOSRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SOSRepository(supabaseService);
});

// State definition
class SOSState {
  final SOSSession? activeSession;
  final bool isGpsStreaming;
  final bool isAudioStreaming;
  final bool isVideoStreaming;
  final int elapsedSeconds;
  final bool micPermissionDenied; // true jika mic gagal diakses

  SOSState({
    this.activeSession,
    this.isGpsStreaming = false,
    this.isAudioStreaming = false,
    this.isVideoStreaming = false,
    this.elapsedSeconds = 0,
    this.micPermissionDenied = false,
  });

  bool get isSOSActive => activeSession != null;

  SOSState copyWith({
    SOSSession? activeSession,
    bool? isGpsStreaming,
    bool? isAudioStreaming,
    bool? isVideoStreaming,
    int? elapsedSeconds,
    bool? micPermissionDenied,
    bool clearActiveSession = false,
  }) {
    return SOSState(
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      isGpsStreaming: isGpsStreaming ?? this.isGpsStreaming,
      isAudioStreaming: isAudioStreaming ?? this.isAudioStreaming,
      isVideoStreaming: isVideoStreaming ?? this.isVideoStreaming,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      micPermissionDenied: micPermissionDenied ?? this.micPermissionDenied,
    );
  }
}

// State Notifier
class SOSNotifier extends StateNotifier<SOSState> {
  final SOSRepository _sosRepository;
  final AudioService _audioService = AudioService();

  Timer? _timer;
  StreamSubscription? _locationSubscription;
  Timer? _inactivityTimer;

  // Akselerometer: track gerakan perangkat untuk inactivity check
  StreamSubscription? _accelerometerSubscription;
  double _lastAccelMagnitude = 0.0;
  static const double _movementThreshold = 1.5; // m/s² — ambang batas gerakan bermakna
  bool _deviceIsMoving = false;

  SOSNotifier(this._sosRepository) : super(SOSState()) {
    _checkActiveSOS();
  }

  Future<void> _checkActiveSOS() async {
    try {
      final active = await _sosRepository.getMyActiveSOS();
      if (active != null) {
        state = state.copyWith(activeSession: active);
        _startSessionTimers(active.id);
        if (active.gpsEnabled) {
          _startLocationStreaming(active.id);
        }
        // Resume mic jika session aktif dari sebelumnya
        if (active.micEnabled) {
          final success = await _audioService.startMicStreaming();
          state = state.copyWith(
            isAudioStreaming: success,
            micPermissionDenied: !success,
          );
        }
        _startAccelerometerWatch();
      }
    } catch (_) {
      // Supabase is not initialized, ignore safely.
    }
  }

  /// Aktivasi SOS: mulai session, GPS, dan mic (jika diizinkan guardian)
  Future<void> activateSOS({bool gps = true, bool mic = false, bool video = false}) async {
    try {
      final session = await _sosRepository.startSOS(gps: gps, mic: mic, video: video);

      bool audioStarted = false;
      bool micDenied = false;

      // Hanya start mic jika parameter mic = true (guardian sudah beri izin)
      if (mic) {
        audioStarted = await _audioService.startMicStreaming();
        micDenied = !audioStarted;
      }

      state = state.copyWith(
        activeSession: session,
        isGpsStreaming: gps,
        isAudioStreaming: audioStarted,
        isVideoStreaming: video,
        elapsedSeconds: 0,
        micPermissionDenied: micDenied,
      );

      _startSessionTimers(session.id);

      if (gps) {
        _startLocationStreaming(session.id);
      }

      _startAccelerometerWatch();
      resetInactivityTimer();
    } catch (_) {}
  }

  /// Akhiri SOS: hentikan semua stream, update session
  Future<void> endSOS({String reason = 'manual'}) async {
    final session = state.activeSession;
    if (session == null) return;

    _timer?.cancel();
    _locationSubscription?.cancel();
    _inactivityTimer?.cancel();
    _accelerometerSubscription?.cancel();

    // Hentikan mic streaming
    await _audioService.stopMicStreaming();

    await _sosRepository.endSession(session.id, reason: reason);

    state = SOSState(); // Reset state
  }

  void _startSessionTimers(String sessionId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  /// Mulai streaming GPS ke Supabase location_pings
  void _startLocationStreaming(String sessionId) {
    _locationSubscription?.cancel();

    // Kirim lokasi pertama segera
    LocationService.getCurrentLocation().then((locData) {
      if (locData != null && locData.latitude != null && locData.longitude != null) {
        _sosRepository.pingLocation(
          sessionId,
          locData.latitude!,
          locData.longitude!,
          accuracy: locData.accuracy,
        );
      }
    });

    // Listen to location stream
    _locationSubscription = LocationService.getLocationStream().listen((locData) {
      if (locData.latitude != null && locData.longitude != null) {
        _sosRepository.pingLocation(
          sessionId,
          locData.latitude!,
          locData.longitude!,
          accuracy: locData.accuracy,
        );
      }
    });
  }

  /// Monitor akselerometer — deteksi apakah perangkat bergerak atau diam
  void _startAccelerometerWatch() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Magnitude total akselerasi (tanpa gravitasi tidak bisa dipisahkan di sini, 
      // tapi perubahan antara sample berturut-turut mencerminkan gerakan)
      final magnitude = (event.x * event.x + event.y * event.y + event.z * event.z);
      final delta = (magnitude - _lastAccelMagnitude).abs();
      _deviceIsMoving = delta > _movementThreshold;
      _lastAccelMagnitude = magnitude;
    });
  }

  /// Toggle video streaming state
  void toggleVideo(bool enabled) {
    state = state.copyWith(isVideoStreaming: enabled);
    resetInactivityTimer();
  }

  /// Toggle mic state (mute/unmute tanpa stop stream)
  void toggleMic(bool enabled) {
    if (_audioService.isMicActive) {
      _audioService.setMuted(!enabled);
    }
    state = state.copyWith(isAudioStreaming: enabled);
    resetInactivityTimer();
  }

  /// Reset inactivity watchdog timer.
  /// Auto-end video stream jika perangkat DIAM (akselerometer) + tidak ada sentuhan selama 2 menit.
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();

    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      // Hanya auto-end jika perangkat benar-benar diam (tidak bergerak)
      if (state.isVideoStreaming && !_deviceIsMoving) {
        toggleVideo(false);
      } else if (state.isVideoStreaming && _deviceIsMoving) {
        // Perangkat masih bergerak — reset timer lagi
        resetInactivityTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _inactivityTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}

// Global Provider for SOS State
final sosProvider = StateNotifierProvider<SOSNotifier, SOSState>((ref) {
  final repo = ref.watch(sosRepositoryProvider);
  return SOSNotifier(repo);
});
