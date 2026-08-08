import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repositories/forwarding_protection_repository.dart';
import '../../auth/providers/auth_provider.dart';

final forwardingProtectionRepositoryProvider =
    Provider<ForwardingProtectionRepository>((ref) {
  return ForwardingProtectionRepository(ref.watch(supabaseServiceProvider));
});

class ForwardingProtectionController {
  final ForwardingProtectionRepository repository;
  final Map<String, RoomForwardingProtection> _states = {};
  final Map<String, StreamSubscription<void>> _subscriptions = {};
  final Map<String, int> _activeRoomReferences = {};
  final StreamController<Map<String, RoomForwardingProtection>>
      _stateController = StreamController.broadcast();

  ForwardingProtectionController({required this.repository});

  Stream<Map<String, RoomForwardingProtection>> get states =>
      _stateController.stream;

  RoomForwardingProtection stateFor(String roomId) =>
      _states[roomId] ?? const RoomForwardingProtection.failClosed();

  Future<void> enterRoom(String roomId) async {
    _activeRoomReferences.update(roomId, (c) => c + 1, ifAbsent: () => 1);
    _states.putIfAbsent(roomId, RoomForwardingProtection.failClosed);
    await refresh(roomId);
    _subscriptions[roomId] ??= repository
        .watchRoomChanges(roomId)
        .listen((_) => refresh(roomId), onError: (_) => refresh(roomId));
  }

  Future<void> leaveRoom(String roomId) async {
    final next = (_activeRoomReferences[roomId] ?? 1) - 1;
    if (next <= 0) {
      _activeRoomReferences.remove(roomId);
      await _subscriptions.remove(roomId)?.cancel();
    } else {
      _activeRoomReferences[roomId] = next;
    }
  }

  Future<void> refresh(String roomId) async {
    try {
      final state = await repository.getRoomState(roomId);
      _states[roomId] = state;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('forwarding_protection_room_$roomId', state.effective);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool('forwarding_protection_room_$roomId');
      _states[roomId] = cached == false
          ? const RoomForwardingProtection.failClosed()
          : const RoomForwardingProtection.failClosed();
    }
    _stateController.add(Map.unmodifiable(_states));
  }

  Future<void> setRoomPreference(String roomId, bool enabled) async {
    await repository.setRoomPreference(roomId, enabled);
    await refresh(roomId);
  }

  Future<void> dispose() async {
    for (final s in _subscriptions.values) {
      await s.cancel();
    }
    await _stateController.close();
  }
}

final forwardingProtectionControllerProvider =
    Provider<ForwardingProtectionController>((ref) {
  final controller = ForwardingProtectionController(
    repository: ref.watch(forwardingProtectionRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final roomForwardingProtectionProvider =
    StreamProvider.autoDispose.family<RoomForwardingProtection, String>((
  ref,
  roomId,
) {
  final controller = ref.watch(forwardingProtectionControllerProvider);
  controller.enterRoom(roomId);
  ref.onDispose(() => controller.leaveRoom(roomId));
  return controller.states
      .map(
        (states) =>
            states[roomId] ?? const RoomForwardingProtection.failClosed(),
      )
      .startWith(controller.stateFor(roomId));
});

extension on Stream<RoomForwardingProtection> {
  Stream<RoomForwardingProtection> startWith(
    RoomForwardingProtection value,
  ) async* {
    yield value;
    yield* this;
  }
}
