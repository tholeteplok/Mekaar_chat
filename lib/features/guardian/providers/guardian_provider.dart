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
  final Ref _ref;

  GuardiansNotifier(this._guardianRepository, this._ref) : super([]) {
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
    await _ref.read(whoAddedMeProvider.notifier).refresh();
  }

  Future<void> breakGuardian(String guardianRelationId) async {
    await _guardianRepository.breakGuardian(guardianRelationId);
    await refreshGuardians();
  }
}

// Global Provider for my Guardians
final guardianProvider = StateNotifierProvider<GuardiansNotifier, List<Guardian>>((ref) {
  final repo = ref.watch(guardianRepositoryProvider);
  return GuardiansNotifier(repo, ref);
});

// Who Added Me Notifier
class WhoAddedMeNotifier extends StateNotifier<List<Guardian>> {
  final GuardianRepository _guardianRepository;
  final Ref _ref;

  WhoAddedMeNotifier(this._guardianRepository, this._ref) : super([]) {
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
    await _ref.read(guardianProvider.notifier).refreshGuardians();
  }

  Future<void> reject(String relationId) async {
    await _guardianRepository.deleteGuardian(relationId);
    await refresh();
  }
}

final whoAddedMeProvider = StateNotifierProvider<WhoAddedMeNotifier, List<Guardian>>((ref) {
  final repo = ref.watch(guardianRepositoryProvider);
  return WhoAddedMeNotifier(repo, ref);
});
