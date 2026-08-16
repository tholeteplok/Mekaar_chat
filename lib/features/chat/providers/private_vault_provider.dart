import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/private_contact_repository.dart';

/// State boolean apakah Private Vault saat ini sedang terbuka di sesi memori (RAM).
/// Nilai ini SELALU reset ke false saat aplikasi di-minimize / background.
final privateVaultUnlockedProvider = StateProvider<bool>((ref) => false);

/// Memeriksa apakah pengguna telah menyetel kode rahasia vault
final privateVaultPasscodeSetProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(privateContactRepositoryProvider);
  return repo.hasPasscode();
});

/// Notifier reaktif untuk daftar ID room obrolan yang disembunyikan
final hiddenRoomIdsProvider =
    StateNotifierProvider<HiddenRoomIdsNotifier, Set<String>>((ref) {
  final repo = ref.watch(privateContactRepositoryProvider);
  return HiddenRoomIdsNotifier(repo);
});

class HiddenRoomIdsNotifier extends StateNotifier<Set<String>> {
  final PrivateContactRepository _repo;

  HiddenRoomIdsNotifier(this._repo) : super(<String>{}) {
    _init();
  }

  Future<void> _init() async {
    await _repo.preloadCache();
    await loadHiddenRooms();
  }

  Future<void> loadHiddenRooms() async {
    final ids = await _repo.getHiddenRoomIds();
    state = ids;
  }

  Future<bool> toggleHide(String roomId) async {
    final isHidden = await _repo.toggleHideRoom(roomId);
    final updated = Set<String>.from(state);
    if (isHidden) {
      updated.add(roomId);
    } else {
      updated.remove(roomId);
    }
    state = updated;
    return isHidden;
  }

  bool isHidden(String roomId) {
    return state.contains(roomId);
  }
}
