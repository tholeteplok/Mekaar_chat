import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

final authRepositoryAutoDeleteProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

/// Provider untuk mengatur default "Pesan Menghilang" (auto-delete).
/// Nilai 0 = mati; selain itu = jam.
class AutoDeleteDefaultNotifier extends StateNotifier<int> {
  final AuthRepository _repo;
  final Ref _ref;

  AutoDeleteDefaultNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.autoDeleteDefaultHours ?? 0);

  Future<void> setHours(int hours) async {
    state = hours;
    try {
      final updated = await _repo.updateAutoDeleteDefault(hours);
      final current = _ref.read(authProvider).profile;
      if (current != null) {
        _ref.read(authProvider.notifier).setProfileSilently(
              current.copyWith(autoDeleteDefaultHours: updated.autoDeleteDefaultHours),
            );
      }
    } catch (_) {}
  }
}

final autoDeleteDefaultProvider =
    StateNotifierProvider<AutoDeleteDefaultNotifier, int>((ref) {
  final repo = ref.watch(authRepositoryAutoDeleteProvider);
  return AutoDeleteDefaultNotifier(repo, ref);
});
