import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/guardian_model.dart';
import '../../../data/repositories/guardian_repository.dart';
import '../../auth/providers/auth_provider.dart';

// Repository Provider
final guardianRepositoryProvider = Provider<GuardianRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return GuardianRepository(supabaseService);
});

// Guardians State Notifier (My added guardians)
class GuardiansNotifier extends StateNotifier<List<Guardian>> {
  final GuardianRepository _guardianRepository;

  GuardiansNotifier(this._guardianRepository) : super([]) {
    refreshGuardians();
  }

  Future<void> refreshGuardians() async {
    try {
      final list = await _guardianRepository.getMyGuardians();
      state = list;
    } catch (_) {}
  }

  Future<void> inviteGuardian(String usernameOrEmail, Map<String, bool> permissions) async {
    await _guardianRepository.addGuardian(usernameOrEmail, permissions);
    await refreshGuardians();
  }

  Future<void> removeGuardian(String guardianRelationId) async {
    await _guardianRepository.deleteGuardian(guardianRelationId);
    await refreshGuardians();
  }

  Future<void> updateGuardianPermissions(
    String guardianRelationId,
    Map<String, bool> permissions,
    String storageOption,
  ) async {
    await _guardianRepository.updatePermissions(guardianRelationId, permissions: permissions, storageOption: storageOption);
    await refreshGuardians();
  }

  Future<void> initiateRoleSwap(String guardianRelationId) async {
    await _guardianRepository.initiateSwap(guardianRelationId);
    await refreshGuardians();
  }
}

// Global Provider for my Guardians
final guardianProvider = StateNotifierProvider<GuardiansNotifier, List<Guardian>>((ref) {
  final repo = ref.watch(guardianRepositoryProvider);
  return GuardiansNotifier(repo);
});

// Who Added Me Notifier
class WhoAddedMeNotifier extends StateNotifier<List<Guardian>> {
  final GuardianRepository _guardianRepository;

  WhoAddedMeNotifier(this._guardianRepository) : super([]) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _guardianRepository.getWhoAddedMe();
      state = list;
    } catch (_) {}
  }

  Future<void> accept(String relationId) async {
    await _guardianRepository.acceptInvitation(relationId);
    await refresh();
  }

  Future<void> reject(String relationId) async {
    await _guardianRepository.deleteGuardian(relationId);
    await refresh();
  }
}

final whoAddedMeProvider = StateNotifierProvider<WhoAddedMeNotifier, List<Guardian>>((ref) {
  final repo = ref.watch(guardianRepositoryProvider);
  return WhoAddedMeNotifier(repo);
});
