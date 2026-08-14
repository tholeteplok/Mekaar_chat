import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

final authRepositoryTwoFaProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

/// Provider untuk mengatur Verifikasi 2 Langkah (TOTP 2FA).
class TwoFaNotifier extends StateNotifier<bool> {
  final AuthRepository _repo;
  final Ref _ref;

  TwoFaNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.twoFaEnabled ?? false);

  /// Aktifkan 2FA dengan secret yang sudah diverifikasi user.
  Future<void> enable(String secret) async {
    final updated = await _repo.enableTwoFa(secret);
    state = updated.twoFaEnabled;
    final current = _ref.read(authProvider).profile;
    if (current != null) {
      _ref.read(authProvider.notifier).setProfileSilently(
            current.copyWith(
              twoFaEnabled: updated.twoFaEnabled,
              twoFaSecret: updated.twoFaSecret,
            ),
          );
    }
  }

  /// Matikan 2FA setelah verifikasi password.
  Future<void> disable(String password) async {
    final authRepo = _ref.read(authRepositoryProvider);
    final verified = await authRepo.verifyPassword(password);
    if (!verified) {
      throw Exception('Password salah. Verifikasi gagal.');
    }

    final updated = await _repo.disableTwoFa();
    state = updated.twoFaEnabled;
    final current = _ref.read(authProvider).profile;
    if (current != null) {
      _ref.read(authProvider.notifier).setProfileSilently(
            current.copyWith(
              twoFaEnabled: updated.twoFaEnabled,
              twoFaSecret: updated.twoFaSecret,
            ),
          );
    }
  }
}

final twoFaProvider =
    StateNotifierProvider<TwoFaNotifier, bool>((ref) {
  final repo = ref.watch(authRepositoryTwoFaProvider);
  return TwoFaNotifier(repo, ref);
});
