import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/user_device.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/services/device_identity_service.dart';

/// State untuk layar Perangkat Terhubung.
class ConnectedDevicesState {
  final List<UserDevice> devices;
  final String currentDeviceId;
  final bool isLoading;
  final String? error;

  const ConnectedDevicesState({
    this.devices = const [],
    this.currentDeviceId = '',
    this.isLoading = true,
    this.error,
  });

  ConnectedDevicesState copyWith({
    List<UserDevice>? devices,
    String? currentDeviceId,
    bool? isLoading,
    String? error,
  }) {
    return ConnectedDevicesState(
      devices: devices ?? this.devices,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Perangkat saat ini (yang sedang digunakan).
  UserDevice? get currentDevice {
    try {
      return devices.firstWhere((d) => d.deviceId == currentDeviceId);
    } catch (_) {
      return null;
    }
  }

  /// Perangkat lain (bukan yang sedang digunakan).
  List<UserDevice> get otherDevices {
    return devices.where((d) => d.deviceId != currentDeviceId).toList();
  }
}

/// Provider state notifier untuk mengelola daftar perangkat terhubung.
class ConnectedDevicesNotifier extends StateNotifier<ConnectedDevicesState> {
  final DeviceRepository _repository;

  ConnectedDevicesNotifier(this._repository)
      : super(const ConnectedDevicesState());

  /// Muat daftar perangkat dari server.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentId = await DeviceIdentityService.getDeviceId();
      final devices = await _repository.listMyDevices();

      state = state.copyWith(
        devices: devices,
        currentDeviceId: currentId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat daftar perangkat: $e',
      );
    }
  }

  /// Revoke perangkat tertentu.
  Future<void> revokeDevice(String deviceId) async {
    try {
      await _repository.revokeDevice(deviceId);
      // Hapus dari state lokal tanpa reload
      state = state.copyWith(
        devices: state.devices.where((d) => d.deviceId != deviceId).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Gagal menghapus perangkat: $e',
      );
    }
  }

  /// Revoke semua perangkat lain.
  Future<void> revokeAllOtherDevices() async {
    try {
      await _repository.revokeAllOtherDevices();
      // Hanya sisakan perangkat saat ini
      state = state.copyWith(
        devices: state.devices
            .where((d) => d.deviceId == state.currentDeviceId)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Gagal menghapus perangkat lain: $e',
      );
    }
  }
}

/// Riverpod provider untuk ConnectedDevicesNotifier.
final connectedDevicesProvider =
    StateNotifierProvider<ConnectedDevicesNotifier, ConnectedDevicesState>(
  (ref) {
    final repo = DeviceRepository(Supabase.instance.client);
    return ConnectedDevicesNotifier(repo);
  },
);
