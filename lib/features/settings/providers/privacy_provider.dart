import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

final authRepositoryPrivacyProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

/// Provider untuk mengontrol siapa yang dapat melihat "terakhir dilihat & online".
class LastSeenPrivacyNotifier extends StateNotifier<LastSeenPrivacy> {
  final AuthRepository _repo;
  final Ref _ref;

  LastSeenPrivacyNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.lastSeenPrivacy ??
            LastSeenPrivacy.everyone);

  Future<void> setPrivacy(LastSeenPrivacy privacy) async {
    state = privacy;
    try {
      final updated = await _repo.updateLastSeenPrivacy(privacy.value);
      final current = _ref.read(authProvider).profile;
      if (current != null) {
        _ref.read(authProvider.notifier).setProfileSilently(
              current.copyWith(lastSeenPrivacy: updated.lastSeenPrivacy),
            );
      }
    } catch (_) {}
  }
}

final lastSeenPrivacyProvider =
    StateNotifierProvider<LastSeenPrivacyNotifier, LastSeenPrivacy>((ref) {
  final repo = ref.watch(authRepositoryPrivacyProvider);
  return LastSeenPrivacyNotifier(repo, ref);
});

/// Provider untuk mengontrol bukti baca (read receipts).
class ReadReceiptsNotifier extends StateNotifier<bool> {
  final AuthRepository _repo;
  final Ref _ref;

  ReadReceiptsNotifier(this._repo, this._ref)
      : super(_ref.read(authProvider).profile?.readReceiptsEnabled ?? true);

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final updated = await _repo.updateReadReceipts(enabled);
      final current = _ref.read(authProvider).profile;
      if (current != null) {
        _ref.read(authProvider.notifier).setProfileSilently(
              current.copyWith(readReceiptsEnabled: updated.readReceiptsEnabled),
            );
      }
    } catch (_) {}
  }
}

final readReceiptsProvider =
    StateNotifierProvider<ReadReceiptsNotifier, bool>((ref) {
  final repo = ref.watch(authRepositoryPrivacyProvider);
  return ReadReceiptsNotifier(repo, ref);
});
