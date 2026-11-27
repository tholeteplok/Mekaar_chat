import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/trip_monitor_service.dart';

class TripMonitorScheduler with WidgetsBindingObserver {
  final Ref _ref;
  final Logger _logger = Logger();
  Timer? _timer;
  bool _isEvaluating = false;
  bool _isDisposed = false;

  static const Duration _interval = Duration(minutes: 3);

  TripMonitorScheduler(this._ref);

  void start() {
    _isDisposed = false;
    WidgetsBinding.instance.addObserver(this);
    _runCycle();
    _ensureTimerActive();
    _logger.i('TripMonitorScheduler dimulai (interval ${_interval.inMinutes} menit)');
  }

  void _ensureTimerActive() {
    if (_isDisposed || (_timer?.isActive ?? false)) return;
    _timer = Timer.periodic(_interval, (_) => _runCycle());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed) {
      _ensureTimerActive();
      _runCycle();
    }
  }

  Future<void> _runCycle() async {
    if (_isEvaluating || _isDisposed) return;
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    _isEvaluating = true;
    try {
      await TripMonitorService.evaluate(
        tripRepository: _ref.read(tripRepositoryProvider),
        chatRepository: _ref.read(chatRepositoryProvider),
        fetchCurrentLocation: () async {
          final locationData = await LocationService.getCurrentLocation()
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
          final lat = locationData?.latitude;
          final lng = locationData?.longitude;
          if (lat == null || lng == null) return null;
          return (lat: lat, lng: lng);
        },
      );
    } catch (e) {
      _logger.w('TripMonitorScheduler: siklus evaluasi gagal (non-fatal): $e');
    } finally {
      _isEvaluating = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}

final tripMonitorSchedulerProvider = Provider<TripMonitorScheduler>((ref) {
  final user = ref.watch(authProvider.select((s) => s.user));
  final scheduler = TripMonitorScheduler(ref);
  if (user == null) {
    scheduler.dispose();
  }
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
