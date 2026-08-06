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

  static const Duration _interval = Duration(minutes: 3);

  TripMonitorScheduler(this._ref);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _runCycle();
    _timer = Timer.periodic(_interval, (_) => _runCycle());
    _logger.i('TripMonitorScheduler dimulai (interval ${_interval.inMinutes} menit)');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runCycle();
    }
  }

  Future<void> _runCycle() async {
    if (_isEvaluating) return;
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    _isEvaluating = true;
    try {
      final locationData = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      await TripMonitorService.evaluate(
        tripRepository: _ref.read(tripRepositoryProvider),
        chatRepository: _ref.read(chatRepositoryProvider),
        currentLat: locationData?.latitude,
        currentLng: locationData?.longitude,
      );
    } catch (e) {
      _logger.w('TripMonitorScheduler: siklus evaluasi gagal (non-fatal): $e');
    } finally {
      _isEvaluating = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}

final tripMonitorSchedulerProvider = Provider<TripMonitorScheduler>((ref) {
  final scheduler = TripMonitorScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
