import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../data/models/trip_permission_model.dart';
import '../../../data/repositories/trip_permission_repository.dart';
import '../../../data/services/location_service.dart';

class TripPermissionNotifier extends StateNotifier<TripPermission?> {
  final TripPermissionRepository _repository;
  final Logger _log = Logger();
  Timer? _pingTimer;
  Timer? _expiryTimer;

  TripPermissionNotifier(this._repository) : super(null) {
    refreshActiveSession();
  }

  Future<void> refreshActiveSession() async {
    final active = await _repository.getActiveHangoutSession();
    state = active;
    if (active != null && active.isActive) {
      _startPingTimer(active);
      _startExpiryTimer(active);
    }
  }

  Future<void> startHangout({
    required String guardianId,
    required String destinationName,
    required DateTime endTime,
    int pingIntervalMinutes = 5,
    bool reminder15mEnabled = true,
  }) async {
    final newSession = await _repository.startHangoutSession(
      guardianId: guardianId,
      destinationName: destinationName,
      endTime: endTime,
      pingIntervalMinutes: pingIntervalMinutes,
      reminder15mEnabled: reminder15mEnabled,
    );
    state = newSession;
    _startPingTimer(newSession);
    _startExpiryTimer(newSession);
    // Kirim ping pertama segera
    _doPing(newSession.id);
  }

  void _startPingTimer(TripPermission session) {
    _pingTimer?.cancel();
    final interval = Duration(minutes: session.pingIntervalMinutes);
    _pingTimer = Timer.periodic(interval, (_) {
      if (state == null || !state!.isActive) {
        _pingTimer?.cancel();
        return;
      }
      _doPing(state!.id);
    });
  }

  void _startExpiryTimer(TripPermission session) {
    _expiryTimer?.cancel();
    final remaining = session.endTime.difference(DateTime.now());
    if (remaining.isNegative) {
      _handleExpiry();
      return;
    }
    _expiryTimer = Timer(remaining, _handleExpiry);
  }

  void _handleExpiry() {
    _pingTimer?.cancel();
    _expiryTimer?.cancel();
    state = null;
    _log.i('TripPermissionNotifier: sesi hangout telah berakhir (expired)');
  }

  Future<void> _doPing(String sessionId) async {
    try {
      final locData = await LocationService.getCurrentLocation();
      if (locData != null && locData.latitude != null && locData.longitude != null) {
        await _repository.updatePingLocation(
          sessionId,
          locData.latitude!,
          locData.longitude!,
        );
        _log.d('TripPermissionNotifier: ping lokasi terkirim '
            '(${locData.latitude}, ${locData.longitude})');
      }
    } catch (e) {
      _log.w('TripPermissionNotifier: gagal ping lokasi: $e');
    }
  }

  Future<void> updateLocation(double lat, double lon) async {
    if (state == null || !state!.isActive) return;
    await _repository.updatePingLocation(state!.id, lat, lon);
  }

  Future<void> cancelHangout() async {
    if (state == null) return;
    await _repository.cancelHangoutSession(state!.id);
    _pingTimer?.cancel();
    _expiryTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}

final tripPermissionNotifierProvider =
    StateNotifierProvider<TripPermissionNotifier, TripPermission?>((ref) {
  final repo = ref.watch(tripPermissionRepositoryProvider);
  return TripPermissionNotifier(repo);
});
