import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/guardian_model.dart';
import '../../../data/repositories/guardian_repository.dart';
import '../../auth/providers/auth_provider.dart';

enum GuardianLoadStatus { loading, data, error }

bool isGuardianActive(Guardian guardian, {DateTime? now}) {
  if (guardian.status != 'active') return false;
  final expiresAt = guardian.expiresAt;
  return expiresAt == null || expiresAt.isAfter(now ?? DateTime.now());
}

List<Guardian> activeGuardiansOf(
  Iterable<Guardian> guardians, {
  DateTime? now,
}) {
  return guardians
      .where((guardian) => isGuardianActive(guardian, now: now))
      .toList(growable: false);
}

final guardianLoadStatusProvider = StateProvider<GuardianLoadStatus>(
  (ref) => GuardianLoadStatus.loading,
);
final whoAddedMeLoadStatusProvider = StateProvider<GuardianLoadStatus>(
  (ref) => GuardianLoadStatus.loading,
);

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
    _ref.read(guardianLoadStatusProvider.notifier).state =
        GuardianLoadStatus.loading;
    try {
      final list = await _guardianRepository.getMyGuardians();
      state = list;
      _ref.read(guardianLoadStatusProvider.notifier).state =
          GuardianLoadStatus.data;
    } catch (_) {
      _ref.read(guardianLoadStatusProvider.notifier).state =
          GuardianLoadStatus.error;
    }
  }

  Future<void> inviteGuardian(
    String usernameOrEmail,
    Map<String, bool> permissions,
  ) async {
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
    await _guardianRepository.updatePermissions(
      guardianRelationId,
      permissions: permissions,
      storageOption: storageOption,
    );
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
final guardianProvider =
    StateNotifierProvider<GuardiansNotifier, List<Guardian>>((ref) {
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
    _ref.read(whoAddedMeLoadStatusProvider.notifier).state =
        GuardianLoadStatus.loading;
    try {
      final list = await _guardianRepository.getWhoAddedMe();
      state = list;
      _ref.read(whoAddedMeLoadStatusProvider.notifier).state =
          GuardianLoadStatus.data;
    } catch (_) {
      _ref.read(whoAddedMeLoadStatusProvider.notifier).state =
          GuardianLoadStatus.error;
    }
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

final whoAddedMeProvider =
    StateNotifierProvider<WhoAddedMeNotifier, List<Guardian>>((ref) {
      final repo = ref.watch(guardianRepositoryProvider);
      return WhoAddedMeNotifier(repo, ref);
    });
