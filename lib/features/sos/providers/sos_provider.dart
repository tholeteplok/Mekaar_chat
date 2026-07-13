import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/sos_session_model.dart';
import '../../../data/repositories/sos_repository.dart';
import '../../../data/services/location_service.dart';
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

  SOSState({
    this.activeSession,
    this.isGpsStreaming = false,
    this.isAudioStreaming = false,
    this.isVideoStreaming = false,
    this.elapsedSeconds = 0,
  });

  bool get isSOSActive => activeSession != null;

  SOSState copyWith({
    SOSSession? activeSession,
    bool? isGpsStreaming,
    bool? isAudioStreaming,
    bool? isVideoStreaming,
    int? elapsedSeconds,
    bool clearActiveSession = false,
  }) {
    return SOSState(
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      isGpsStreaming: isGpsStreaming ?? this.isGpsStreaming,
      isAudioStreaming: isAudioStreaming ?? this.isAudioStreaming,
      isVideoStreaming: isVideoStreaming ?? this.isVideoStreaming,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

// State Notifier
class SOSNotifier extends StateNotifier<SOSState> {
  final SOSRepository _sosRepository;
  Timer? _timer;
  StreamSubscription? _locationSubscription;
  Timer? _inactivityTimer;

  SOSNotifier(this._sosRepository) : super(SOSState()) {
    _checkActiveSOS();
  }

  Future<void> _checkActiveSOS() async {
    final active = await _sosRepository.getMyActiveSOS();
    if (active != null) {
      state = state.copyWith(activeSession: active);
      _startSessionTimers(active.id);
      if (active.gpsEnabled) {
        _startLocationStreaming(active.id);
      }
    }
  }

  // Start SOS Session
  Future<void> activateSOS({bool gps = true, bool mic = false, bool video = false}) async {
    try {
      final session = await _sosRepository.startSOS(gps: gps, mic: mic, video: video);
      state = state.copyWith(
        activeSession: session,
        isGpsStreaming: gps,
        isAudioStreaming: mic,
        isVideoStreaming: video,
        elapsedSeconds: 0,
      );

      _startSessionTimers(session.id);
      
      if (gps) {
        _startLocationStreaming(session.id);
      }
      
      resetInactivityTimer();
    } catch (_) {}
  }

  // End SOS Session
  Future<void> endSOS({String reason = 'manual'}) async {
    final session = state.activeSession;
    if (session == null) return;

    _timer?.cancel();
    _locationSubscription?.cancel();
    _inactivityTimer?.cancel();

    await _sosRepository.endSession(session.id, reason: reason);
    
    state = SOSState(); // Reset state
  }

  void _startSessionTimers(String sessionId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  // Start Location Updates GPS Stream to Supabase Location Pings
  void _startLocationStreaming(String sessionId) {
    _locationSubscription?.cancel();
    
    // Get initial location
    LocationService.getCurrentLocation().then((locData) {
      if (locData != null && locData.latitude != null && locData.longitude != null) {
        _sosRepository.pingLocation(
          sessionId, 
          locData.latitude!, 
          locData.longitude!, 
          accuracy: locData.accuracy
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
          accuracy: locData.accuracy
        );
      }
    });
  }

  // Handle video toggles
  void toggleVideo(bool enabled) {
    state = state.copyWith(isVideoStreaming: enabled);
    resetInactivityTimer();
  }

  // Handle mic toggles
  void toggleMic(bool enabled) {
    state = state.copyWith(isAudioStreaming: enabled);
    resetInactivityTimer();
  }

  // Reset inactivity watchdog timer (Auto-end video streaming after 2 mins if inactive)
  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    
    // 2 minutes inactivity timer
    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      if (state.isVideoStreaming) {
        // Auto-end streaming to protect privacy
        toggleVideo(false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }
}

// Global Provider for SOS State
final sosProvider = StateNotifierProvider<SOSNotifier, SOSState>((ref) {
  final repo = ref.watch(sosRepositoryProvider);
  return SOSNotifier(repo);
});
