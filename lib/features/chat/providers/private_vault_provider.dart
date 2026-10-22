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

/// Notifier reaktif untuk daftar ID kontak (contactUserId) yang disembunyikan
final hiddenContactUserIdsProvider =
    StateNotifierProvider<HiddenContactUserIdsNotifier, Set<String>>((ref) {
  final repo = ref.watch(privateContactRepositoryProvider);
  return HiddenContactUserIdsNotifier(repo);
});

class HiddenContactUserIdsNotifier extends StateNotifier<Set<String>> {
  final PrivateContactRepository _repo;

  HiddenContactUserIdsNotifier(this._repo) : super(<String>{}) {
    _init();
  }

  Future<void> _init() async {
    await _repo.preloadCache();
    await loadHiddenContacts();
  }

  Future<void> loadHiddenContacts() async {
    final ids = await _repo.getHiddenContactUserIds();
    state = ids;
  }

  Future<bool> toggleHide(String contactUserId) async {
    final isHidden = await _repo.toggleHideContact(contactUserId);
    final updated = Set<String>.from(state);
    if (isHidden) {
      updated.add(contactUserId);
    } else {
      updated.remove(contactUserId);
    }
    state = updated;
    return isHidden;
  }

  Future<void> hideContact(String contactUserId) async {
    await _repo.hideContact(contactUserId);
    if (!state.contains(contactUserId)) {
      final updated = Set<String>.from(state)..add(contactUserId);
      state = updated;
    }
  }

  Future<void> removeContact(String contactUserId) async {
    await _repo.removeHiddenContact(contactUserId);
    final updated = Set<String>.from(state);
    if (updated.remove(contactUserId)) {
      state = updated;
    }
  }

  bool isHidden(String contactUserId) {
    return state.contains(contactUserId);
  }
}

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
