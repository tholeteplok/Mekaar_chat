import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../data/models/sos_session_model.dart';
import '../../../data/repositories/sos_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/haptic_service.dart';

// Repository Provider
final sosRepositoryProvider = Provider<SOSRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SOSRepository(supabaseService);
});

// State definition
enum SOSStatus { idle, activating, active, queuedOffline, failed, ending }

class SOSState {
  final SOSStatus status;
  final SOSSession? activeSession;
  final String? message;
  final bool isGpsStreaming;
  final bool isAudioStreaming;
  final bool isVideoStreaming;
  final int elapsedSeconds;
  final bool micPermissionDenied; // true jika mic gagal diakses
  final bool needsInactivityAck; // prompt "Apakah Anda Aman?" sebelum auto-end

  SOSState({
    this.status = SOSStatus.idle,
    this.activeSession,
    this.message,
    this.isGpsStreaming = false,
    this.isAudioStreaming = false,
    this.isVideoStreaming = false,
    this.elapsedSeconds = 0,
    this.micPermissionDenied = false,
    this.needsInactivityAck = false,
  });

  bool get isSOSActive => status == SOSStatus.active && activeSession != null;

  SOSState copyWith({
    SOSStatus? status,
    SOSSession? activeSession,
    String? message,
    bool? isGpsStreaming,
    bool? isAudioStreaming,
    bool? isVideoStreaming,
    int? elapsedSeconds,
    bool? micPermissionDenied,
    bool? needsInactivityAck,
    bool clearActiveSession = false,
    bool clearMessage = false,
  }) {
    return SOSState(
      status: status ?? this.status,
      activeSession: clearActiveSession
          ? null
          : (activeSession ?? this.activeSession),
      message: clearMessage ? null : (message ?? this.message),
      isGpsStreaming: isGpsStreaming ?? this.isGpsStreaming,
      isAudioStreaming: isAudioStreaming ?? this.isAudioStreaming,
      isVideoStreaming: isVideoStreaming ?? this.isVideoStreaming,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      micPermissionDenied: micPermissionDenied ?? this.micPermissionDenied,
      needsInactivityAck: needsInactivityAck ?? this.needsInactivityAck,
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
  static const double _movementThreshold =
      1.5; // m/s² — ambang batas gerakan bermakna
  bool _deviceIsMoving = false;

  // Offline Outbox Queue (blind spot #4): simpan SOS saat tidak ada sinyal,
  // kirim otomatis saat koneksi kembali.
  static const String _pendingKey = 'pending_sos_queue';
  Timer? _flushTimer;
  Future<void>? _pendingFlushOperation;
  late final Future<void> _initialization;

  SOSNotifier(this._sosRepository)
    : super(SOSState(status: SOSStatus.activating)) {
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    final restored = await _checkActiveSOS();
    if (restored) return;

    state = SOSState();
    final queued = await _tryFlushPendingSOS();
    if (!queued) state = SOSState();
  }

  // Simpan payload SOS ke antrean lokal (SharedPreferences).
  Future<bool> _enqueuePendingSOS(
    bool gps,
    bool mic,
    bool video,
    DateTime pressedAt,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = [
        jsonEncode({
          'gps': gps,
          'mic': mic,
          'video': video,
          'pressed_at': pressedAt.toIso8601String(),
        }),
      ];
      return prefs.setStringList(_pendingKey, queue);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _clearPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.remove(_pendingKey);
    } catch (_) {
      return false;
    }
  }

  // Coba kirim ulang SOS yang tertunda saat sinyal kembali.
  Future<bool> _tryFlushPendingSOS() async {
    if (state.status == SOSStatus.active ||
        state.status == SOSStatus.activating ||
        state.status == SOSStatus.ending) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_pendingKey) ?? [];
      if (queue.isEmpty) return false;
      if (state.status == SOSStatus.active ||
          state.status == SOSStatus.activating ||
          state.status == SOSStatus.ending) {
        return false;
      }

      state = state.copyWith(
        status: SOSStatus.queuedOffline,
        message:
            'SOS tersimpan di perangkat dan akan dikirim saat koneksi tersedia.',
        clearActiveSession: true,
      );
      _schedulePendingFlush();
      return true;
    } catch (_) {
      _schedulePendingFlush();
      return false;
    }
  }

  void _schedulePendingFlush() {
    _flushTimer ??= Timer.periodic(const Duration(seconds: 15), (_) async {
      if (state.status != SOSStatus.queuedOffline ||
          _pendingFlushOperation != null) {
        return;
      }

      final operation = _flushPendingSOS();
      _pendingFlushOperation = operation;
      await operation;
      if (identical(_pendingFlushOperation, operation)) {
        _pendingFlushOperation = null;
      }
    });
  }

  Future<void> _flushPendingSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_pendingKey) ?? [];
      if (queue.isEmpty) {
        _flushTimer?.cancel();
        _flushTimer = null;
        state = SOSState();
        return;
      }

      final data = jsonDecode(queue.first) as Map<String, dynamic>;
      final session = await _sosRepository.startSOS(
        gps: data['gps'] as bool,
        mic: data['mic'] as bool,
        video: data['video'] as bool,
      );

      if (state.status != SOSStatus.queuedOffline) {
        try {
          await _sosRepository.endSession(session.id);
        } catch (_) {
          state = SOSState(
            status: SOSStatus.active,
            activeSession: session,
            message:
                'Pembatalan terlambat diterima dan sesi SOS sudah aktif. Akhiri Mode Darurat untuk mencoba lagi.',
          );
          _startSessionTimers(session.id);
        }
        return;
      }

      final saved = await prefs.remove(_pendingKey);
      if (!saved) {
        try {
          await _sosRepository.endSession(session.id);
        } catch (_) {
          await _clearPendingSOS();
          _flushTimer?.cancel();
          _flushTimer = null;
          await _confirmActiveSession(
            session,
            gps: data['gps'] as bool,
            mic: data['mic'] as bool,
            video: data['video'] as bool,
          );
          state = state.copyWith(
            message:
                'Sesi SOS sudah aktif, tetapi antrean lokal gagal diperbarui.',
          );
        }
        return;
      }

      _flushTimer?.cancel();
      _flushTimer = null;
      await _confirmActiveSession(
        session,
        gps: data['gps'] as bool,
        mic: data['mic'] as bool,
        video: data['video'] as bool,
      );
    } catch (_) {
      // Tetap queued; timer akan mencoba lagi saat koneksi tersedia.
    }
  }

  Future<bool> _checkActiveSOS() async {
    try {
      final active = await _sosRepository.getMyActiveSOS();
      if (active != null) {
        _flushTimer?.cancel();
        _flushTimer = null;
        await _clearPendingSOS();
        state = state.copyWith(
          status: SOSStatus.active,
          activeSession: active,
          clearMessage: true,
        );
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
        return true;
      }
    } catch (_) {
      // Supabase is not initialized, ignore safely.
    }
    return false;
  }

  /// Aktivasi SOS: mulai session, GPS, dan mic (jika diizinkan guardian).
  /// Jika offline (gagal simpan session), simpan ke Offline Outbox Queue.
  Future<void> activateSOS({
    bool gps = true,
    bool mic = false,
    bool video = false,
  }) async {
    await _initialization;
    if (state.status == SOSStatus.activating ||
        state.status == SOSStatus.active ||
        state.status == SOSStatus.ending ||
        state.status == SOSStatus.queuedOffline) {
      return;
    }

    state = SOSState(status: SOSStatus.activating);

    SOSSession session;
    try {
      session = await _sosRepository.startSOS(gps: gps, mic: mic, video: video);
    } catch (_) {
      // Offline / tidak ada sinyal: simpan ke antrean lokal, kirim saat sinyal kembali.
      final queued = await _enqueuePendingSOS(gps, mic, video, DateTime.now());
      if (queued) {
        state = SOSState(
          status: SOSStatus.queuedOffline,
          message:
              'SOS belum terkirim. Permintaan tersimpan di perangkat dan akan dikirim saat koneksi tersedia.',
        );
        _schedulePendingFlush();
      } else {
        state = SOSState(
          status: SOSStatus.failed,
          message:
              'SOS gagal dimulai dan tidak dapat disimpan di perangkat. Periksa koneksi lalu coba lagi.',
        );
      }
      return;
    }

    await _confirmActiveSession(session, gps: gps, mic: mic, video: video);
  }

  Future<void> _confirmActiveSession(
    SOSSession session, {
    required bool gps,
    required bool mic,
    required bool video,
  }) async {
    bool audioStarted = false;
    bool micDenied = false;

    if (mic) {
      try {
        audioStarted = await _audioService.startMicStreaming();
        micDenied = !audioStarted;
      } catch (_) {
        micDenied = true;
      }
    }

    state = SOSState(
      status: SOSStatus.active,
      activeSession: session,
      isGpsStreaming: gps,
      isAudioStreaming: audioStarted,
      isVideoStreaming: video,
      micPermissionDenied: micDenied,
    );

    _startSessionTimers(session.id);
    try {
      if (gps) {
        _startLocationStreaming(session.id);
      }
      _startAccelerometerWatch();
      resetInactivityTimer();
    } catch (_) {
      // Sesi server tetap aktif meski salah satu stream lokal gagal dimulai.
    }

    try {
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
  }

  /// Akhiri SOS: hentikan semua stream, update session
  Future<void> endSOS({String reason = 'manual'}) async {
    if (state.status == SOSStatus.queuedOffline) {
      state = state.copyWith(status: SOSStatus.ending, clearMessage: true);
      _flushTimer?.cancel();
      _flushTimer = null;
      final cleared = await _clearPendingSOS();
      await _pendingFlushOperation;
      if (state.status == SOSStatus.active) return;
      state = cleared
          ? SOSState()
          : SOSState(
              status: SOSStatus.queuedOffline,
              message:
                  'Permintaan SOS tertunda gagal dibatalkan. Coba akhiri lagi sebelum koneksi kembali.',
            );
      return;
    }

    final session = state.activeSession;
    if (state.status != SOSStatus.active || session == null) return;

    state = state.copyWith(status: SOSStatus.ending, clearMessage: true);

    try {
      await _sosRepository.endSession(session.id, reason: reason);
    } catch (_) {
      state = state.copyWith(
        status: SOSStatus.active,
        message:
            'SOS belum berhasil diakhiri. Sesi masih aktif; periksa koneksi lalu coba lagi.',
      );
      return;
    }

    _timer?.cancel();
    _locationSubscription?.cancel();
    _inactivityTimer?.cancel();
    _accelerometerSubscription?.cancel();
    await _audioService.stopMicStreaming();

    state = SOSState(); // Reset state
  }

  void _startSessionTimers(String sessionId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != SOSStatus.active ||
          state.activeSession?.id != sessionId) {
        return;
      }
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  /// Mulai streaming GPS ke Supabase location_pings
  void _startLocationStreaming(String sessionId) {
    _locationSubscription?.cancel();

    // Kirim lokasi pertama segera
    LocationService.getCurrentLocation().then((locData) {
      if (state.status == SOSStatus.active &&
          state.activeSession?.id == sessionId &&
          locData != null &&
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
      if (state.status == SOSStatus.active &&
          state.activeSession?.id == sessionId &&
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
    if (state.status != SOSStatus.active) return;
    state = state.copyWith(
      isVideoStreaming: enabled,
      needsInactivityAck: false,
    );
    resetInactivityTimer();
  }

  // Pengguna menekan layar → batalkan prompt inactivity (blind spot #7).
  void acknowledgeInactivity() {
    if (state.status != SOSStatus.active) return;
    state = state.copyWith(needsInactivityAck: false);
    resetInactivityTimer();
  }

  /// Toggle mic state (mute/unmute tanpa stop stream)
  void toggleMic(bool enabled) {
    if (state.status != SOSStatus.active) return;
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
    if (state.status != SOSStatus.active) return;
    _inactivityTimer?.cancel();
    state = state.copyWith(needsInactivityAck: false);

    _inactivityTimer = Timer(const Duration(seconds: 90), () {
      if (state.status == SOSStatus.active &&
          state.isVideoStreaming &&
          !_deviceIsMoving) {
        HapticService.trigger(MekaarHapticIntent.warning);
        state = state.copyWith(needsInactivityAck: true);
      }
    });

    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      // Hanya auto-end jika perangkat benar-benar diam (tidak bergerak)
      if (state.status != SOSStatus.active) return;
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
    _flushTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}

// Global Provider for SOS State
final sosProvider = StateNotifierProvider<SOSNotifier, SOSState>((ref) {
  final repo = ref.watch(sosRepositoryProvider);
  return SOSNotifier(repo);
});
