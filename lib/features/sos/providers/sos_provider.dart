import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../data/models/sos_session_model.dart';
import '../../../data/repositories/sos_repository.dart';
import '../../../data/repositories/log_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';

// Repository Provider
final sosRepositoryProvider = Provider<SOSRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SOSRepository(supabaseService);
});

final logRepositoryProvider = Provider<LogRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return LogRepository(supabaseService);
});

// State definition
class SOSState {
  final SOSSession? activeSession;
  final bool isGpsStreaming;
  final bool isAudioStreaming;
  final bool isVideoStreaming;
  final int elapsedSeconds;
  final bool micPermissionDenied; // true jika mic gagal diakses
  final bool needsInactivityAck; // prompt "Apakah Anda Aman?" sebelum auto-end

  SOSState({
    this.activeSession,
    this.isGpsStreaming = false,
    this.isAudioStreaming = false,
    this.isVideoStreaming = false,
    this.elapsedSeconds = 0,
    this.micPermissionDenied = false,
    this.needsInactivityAck = false,
  });

  bool get isSOSActive => activeSession != null;

  SOSState copyWith({
    SOSSession? activeSession,
    bool? isGpsStreaming,
    bool? isAudioStreaming,
    bool? isVideoStreaming,
    int? elapsedSeconds,
    bool? micPermissionDenied,
    bool? needsInactivityAck,
    bool clearActiveSession = false,
  }) {
    return SOSState(
      activeSession: clearActiveSession
          ? null
          : (activeSession ?? this.activeSession),
      isGpsStreaming: isGpsStreaming ?? this.isGpsStreaming,
      isAudioStreaming: isAudioStreaming ?? this.isAudioStreaming,
      isVideoStreaming: isVideoStreaming ?? this.isVideoStreaming,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      micPermissionDenied: micPermissionDenied ?? this.micPermissionDenied,
      needsInactivityAck:
          needsInactivityAck ?? this.needsInactivityAck,
    );
  }
}

// State Notifier
class SOSNotifier extends StateNotifier<SOSState> {
  final SOSRepository _sosRepository;
  final LogRepository _logRepository;
  final AudioService _audioService = AudioService();

  Timer? _timer;
  StreamSubscription? _locationSubscription;
  Timer? _inactivityTimer;

  // Akselerometer: track gerakan perangkat untuk inactivity check
  StreamSubscription? _accelerometerSubscription;
  double _lastAccelMagnitude = 0.0;
  static const double _movementThreshold =
      1.5; // m/s² — ambang batas gerakan bermakna
  bool _deviceIsMoving = false;

  // Offline Outbox Queue (blind spot #4): simpan SOS saat tidak ada sinyal,
  // kirim otomatis saat koneksi kembali.
  static const String _pendingKey = 'pending_sos_queue';
  Timer? _flushTimer;

  SOSNotifier(this._sosRepository, this._logRepository)
      : super(SOSState()) {
    _checkActiveSOS();
    _tryFlushPendingSOS();
  }

  // Simpan payload SOS ke antrean lokal (SharedPreferences).
  Future<void> _enqueuePendingSOS(
    bool gps,
    bool mic,
    bool video,
    DateTime pressedAt,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_pendingKey) ?? [];
      queue.add(jsonEncode({
        'gps': gps,
        'mic': mic,
        'video': video,
        'pressed_at': pressedAt.toIso8601String(),
      }));
      await prefs.setStringList(_pendingKey, queue);
    } catch (_) {}
  }

  Future<void> _clearPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey);
    } catch (_) {}
  }

  // Coba kirim ulang SOS yang tertunda saat sinyal kembali.
  Future<void> _tryFlushPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_pendingKey) ?? [];
      if (queue.isEmpty) return;

      for (final item in queue) {
        final data = jsonDecode(item) as Map<String, dynamic>;
        await activateSOS(
          gps: data['gps'] as bool,
          mic: data['mic'] as bool,
          video: data['video'] as bool,
        );
      }
      await _clearPendingSOS();
    } catch (_) {
      // Masih offline — coba lagi nanti via timer periodik.
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _tryFlushPendingSOS();
      });
    }
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

  /// Aktivasi SOS: mulai session, GPS, dan mic (jika diizinkan guardian).
  /// Jika offline (gagal simpan session), simpan ke Offline Outbox Queue.
  Future<void> activateSOS({
    bool gps = true,
    bool mic = false,
    bool video = false,
  }) async {
    try {
      final session = await _sosRepository.startSOS(
        gps: gps,
        mic: mic,
        video: video,
      );

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

      try {
        await _logRepository.logEvent('sos_started', {
          'session_id': session.id,
          'gps_enabled': gps,
          'mic_enabled': mic,
          'video_enabled': video,
        });

        final guardians = await _sosRepository.getMyActiveGuardians();
        for (final guardian in guardians) {
          await NotificationService.sendSOSNotification(
            guardianId: guardian,
            sessionId: session.id,
            gps: gps,
            mic: mic,
            video: video,
          );
        }
      } catch (_) {}
    } catch (_) {
      // Offline / tidak ada sinyal: simpan ke antrean lokal, kirim saat sinyal kembali.
      await _enqueuePendingSOS(gps, mic, video, DateTime.now());
    }
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

    try {
      await _logRepository.logEvent('sos_ended', {
        'session_id': session.id,
        'reason': reason,
      });
    } catch (_) {}

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
      if (locData != null &&
          locData.latitude != null &&
          locData.longitude != null) {
        _sosRepository.pingLocation(
          sessionId,
          locData.latitude!,
          locData.longitude!,
          accuracy: locData.accuracy,
        );
      }
    });

    // Listen to location stream
    _locationSubscription = LocationService.getLocationStream().listen((
      locData,
    ) {
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

  /// Pantau akselerometer — deteksi apakah perangkat bergerak atau diam
  void _startAccelerometerWatch() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      // Magnitude total akselerasi (tanpa gravitasi tidak bisa dipisahkan di sini,
      // tapi perubahan antara sample berturut-turut mencerminkan gerakan)
      final magnitude =
          (event.x * event.x + event.y * event.y + event.z * event.z);
      final delta = (magnitude - _lastAccelMagnitude).abs();
      _deviceIsMoving = delta > _movementThreshold;
      _lastAccelMagnitude = magnitude;
    });
  }

  /// Toggle video streaming state
  void toggleVideo(bool enabled) {
    state = state.copyWith(
      isVideoStreaming: enabled,
      needsInactivityAck: false,
    );
    resetInactivityTimer();
  }

  // Pengguna menekan layar → batalkan prompt inactivity (blind spot #7).
  void acknowledgeInactivity() {
    state = state.copyWith(needsInactivityAck: false);
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

  /// Reset inactivity watchdog timer (blind spot #7).
  /// Menit ke-1.5: haptic halus + prompt "Apakah Anda Aman?" (tanpa mematikan
  /// bukti). Menit ke-2: jika perangkat diam & tak ada respon, baru putus video.
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    state = state.copyWith(needsInactivityAck: false);

    _inactivityTimer = Timer(const Duration(seconds: 90), () {
      if (state.isVideoStreaming && !_deviceIsMoving) {
        HapticFeedback.lightImpact();
        state = state.copyWith(needsInactivityAck: true);
      }
    });

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

  Future<Map<String, dynamic>?> getOwnSessionWithPing() async {
    return _sosRepository.getOwnActiveSessionWithPing();
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
  final logRepo = ref.watch(logRepositoryProvider);
  return SOSNotifier(repo, logRepo);
});
