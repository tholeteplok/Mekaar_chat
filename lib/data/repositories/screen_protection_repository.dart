import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';

class RoomScreenProtection {
  final bool effective;
  final bool callerEnabled;
  final int protectorCount;
  final int participantCount;
  final DateTime? lastChange;
  final bool isFromCache;

  const RoomScreenProtection({
    required this.effective,
    required this.callerEnabled,
    required this.protectorCount,
    required this.participantCount,
    required this.lastChange,
    this.isFromCache = false,
  });

  const RoomScreenProtection.failClosed()
    : effective = true,
      callerEnabled = true,
      protectorCount = 0,
      participantCount = 0,
      lastChange = null,
      isFromCache = true;

  bool get canShowProtectorCount => participantCount >= 3;

  String get statusLabel => canShowProtectorCount
      ? '$protectorCount dari $participantCount peserta mengaktifkan proteksi'
      : 'Proteksi ruang aktif';

  factory RoomScreenProtection.fromJson(Map<String, dynamic> json) {
    return RoomScreenProtection(
      effective: json['effective'] as bool? ?? true,
      callerEnabled: json['caller_enabled'] as bool? ?? true,
      protectorCount: (json['protector_count'] as num?)?.toInt() ?? 0,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      lastChange: DateTime.tryParse(json['last_change'] as String? ?? ''),
    );
  }
}

class ScreenProtectionRepository {
  final SupabaseService _supabase;

  ScreenProtectionRepository(this._supabase);

  Future<RoomScreenProtection> getRoomState(String roomId) async {
    final response = await _supabase.client.rpc(
      'get_room_screenshot_protection',
      params: {'p_room_id': roomId},
    );
    if (response is List && response.isNotEmpty) {
      return RoomScreenProtection.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    }
    return const RoomScreenProtection.failClosed();
  }

  Future<void> setRoomPreference(String roomId, bool enabled) async {
    await _supabase.client.rpc(
      'set_room_screenshot_protection',
      params: {'p_room_id': roomId, 'p_enabled': enabled},
    );
  }

  Stream<void> watchRoomChanges(String roomId) {
    return _supabase.client
        .from('room_participants')
        .stream(primaryKey: ['room_id', 'profile_id'])
        .eq('room_id', roomId)
        .map((_) {});
  }
}

class NativeScreenProtection {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.mekaar.mekaar_chat/security',
  );
  static const EventChannel _captureChannel = EventChannel(
    'com.mekaar.mekaar_chat/screen_capture',
  );

  Stream<bool> get captureState => _captureChannel
      .receiveBroadcastStream()
      .map((event) => event == true)
      .handleError((_) => false);

  Future<void> setEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod(
        enabled ? 'enableSecureFlag' : 'disableSecureFlag',
      );
    } on PlatformException {
      // Unsupported platforms rely on the Flutter capture overlay.
    } on MissingPluginException {
      // Tests and desktop builds do not install the native bridge.
    }
  }
}

class ScreenProtectionController {
  final ScreenProtectionRepository repository;
  final NativeScreenProtection native;
  final Map<String, RoomScreenProtection> _states = {};
  final Map<String, StreamSubscription<void>> _subscriptions = {};
  final Map<String, int> _activeRoomReferences = {};
  final Set<String> _mandatorySurfaces = {};
  final StreamController<Map<String, RoomScreenProtection>> _stateController =
      StreamController.broadcast();

  ScreenProtectionController({required this.repository, required this.native});

  Stream<Map<String, RoomScreenProtection>> get states =>
      _stateController.stream;
  Stream<bool> get captureState => native.captureState;

  bool get hasProtectedSurface =>
      _mandatorySurfaces.isNotEmpty ||
      _activeRoomReferences.keys.any((roomId) => stateFor(roomId).effective);

  RoomScreenProtection stateFor(String roomId) =>
      _states[roomId] ?? const RoomScreenProtection.failClosed();

  Future<void> enterRoom(String roomId) async {
    _activeRoomReferences.update(
      roomId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    _states.putIfAbsent(roomId, RoomScreenProtection.failClosed);
    await _applyNativeState();
    await refresh(roomId);
    _subscriptions[roomId] ??= repository
        .watchRoomChanges(roomId)
        .listen((_) => refresh(roomId), onError: (_) => _applyNativeState());
  }

  Future<void> leaveRoom(String roomId) async {
    final nextCount = (_activeRoomReferences[roomId] ?? 1) - 1;
    if (nextCount <= 0) {
      _activeRoomReferences.remove(roomId);
      await _subscriptions.remove(roomId)?.cancel();
    } else {
      _activeRoomReferences[roomId] = nextCount;
    }
    await _applyNativeState();
  }

  Future<void> enterMandatorySurface(String surfaceId) async {
    _mandatorySurfaces.add(surfaceId);
    await _applyNativeState();
  }

  Future<void> leaveMandatorySurface(String surfaceId) async {
    _mandatorySurfaces.remove(surfaceId);
    await _applyNativeState();
  }

  Future<void> refresh(String roomId) async {
    try {
      final state = await repository.getRoomState(roomId);
      _states[roomId] = state;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('screen_protection_room_$roomId', state.effective);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool('screen_protection_room_$roomId');
      _states[roomId] = cached == false
          ? const RoomScreenProtection.failClosed()
          : const RoomScreenProtection.failClosed();
    }
    _stateController.add(Map.unmodifiable(_states));
    await _applyNativeState();
  }

  Future<void> setRoomPreference(String roomId, bool enabled) async {
    await repository.setRoomPreference(roomId, enabled);
    await refresh(roomId);
  }

  Future<void> _applyNativeState() {
    final roomRequiresProtection = _activeRoomReferences.keys.any(
      (roomId) => stateFor(roomId).effective,
    );
    return native.setEnabled(
      _mandatorySurfaces.isNotEmpty || roomRequiresProtection,
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    await _stateController.close();
  }
}
