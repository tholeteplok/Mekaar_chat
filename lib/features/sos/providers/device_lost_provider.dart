import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/device_lost_model.dart';
import '../../../data/repositories/device_lost_repository.dart';
import '../../auth/providers/auth_provider.dart';

final deviceLostRepositoryProvider = Provider<DeviceLostRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return DeviceLostRepository(supabaseService);
});

class DeviceLostNotifier extends StateNotifier<DeviceLostState> {
  final DeviceLostRepository _repository;
  final Ref _ref;

  DeviceLostNotifier(this._repository, this._ref) : super(const DeviceLostState()) {
    loadState();
  }

  Future<void> loadState() async {
    final stateLoaded = await _repository.getDeviceLostState();
    state = stateLoaded;
  }

  Future<void> lockDevice({
    required String lockMessage,
    String? recoveryContact,
  }) async {
    final newState = DeviceLostState(
      isLocked: true,
      lockMessage: lockMessage.trim().isEmpty
          ? 'Ponsel ini hilang. Harap hubungi nomor darurat di layar.'
          : lockMessage.trim(),
      recoveryContact: recoveryContact?.trim(),
      lockedAt: DateTime.now(),
    );

    await _repository.setDeviceLostState(newState);
    state = newState;
  }

  Future<bool> unlockWithPIN(String pin) async {
    final authRepo = _ref.read(authRepositoryProvider);
    final isValid = await authRepo.validatePIN(pin);
    if (isValid) {
      await _repository.clearDeviceLostState();
      state = const DeviceLostState(isLocked: false);
      return true;
    }
    return false;
  }
}

final deviceLostProvider =
    StateNotifierProvider<DeviceLostNotifier, DeviceLostState>((ref) {
  final repo = ref.watch(deviceLostRepositoryProvider);
  return DeviceLostNotifier(repo, ref);
});
