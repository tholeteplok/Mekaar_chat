import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
import 'chat_provider.dart';

/// State set slot vault mana saja yang saat ini sedang terbuka di sesi memori (RAM).
/// Nilai ini SELALU reset ke kosong saat aplikasi di-minimize / background.
final unlockedVaultSlotsProvider = StateProvider<Set<int>>((ref) => <int>{});

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

/// Set contactUserId yang saat ini sedang terkunci/terselubung (cloaked)
/// berdasarkan nomor slot masing-masing dan status unlockedVaultSlotsProvider.
final cloakedContactUserIdsProvider = Provider<Set<String>>((ref) {
  final unlockedSlots = ref.watch(unlockedVaultSlotsProvider);
  final isAnyUnlocked =
      unlockedSlots.isNotEmpty || ref.watch(privateVaultUnlockedProvider);
  final hiddenIds = ref.watch(hiddenContactUserIdsProvider);
  final contactsAsync = ref.watch(userContactsProvider);
  final contacts = contactsAsync.value ?? const <ContactItem>[];

  final cloaked = <String>{};
  final contactMap = <String, ContactItem>{
    for (final c in contacts) c.contactUserId: c,
  };

  // 1. Kontak yang terdaftar di userContacts: cek status isVaulted dan slotnya
  for (final c in contacts) {
    if (c.isVaulted) {
      if (!unlockedSlots.contains(c.vaultSlot)) {
        cloaked.add(c.contactUserId);
      }
    }
  }

  // 2. Kontak yang tercatat di hiddenContactUserIds lokal (fail-safe / legacy)
  for (final hid in hiddenIds) {
    final contact = contactMap[hid];
    if (contact != null) {
      if (contact.isVaulted && !unlockedSlots.contains(contact.vaultSlot)) {
        cloaked.add(hid);
      }
    } else {
      if (!isAnyUnlocked) {
        cloaked.add(hid);
      }
    }
  }

  return cloaked;
});

/// Set ID room obrolan yang saat ini sedang terselubung (cloaked)
final cloakedRoomIdsProvider = Provider<Set<String>>((ref) {
  final cloakedUserIds = ref.watch(cloakedContactUserIdsProvider);
  final hiddenRooms = ref.watch(hiddenRoomIdsProvider);
  final isAnyUnlocked = ref.watch(unlockedVaultSlotsProvider).isNotEmpty ||
      ref.watch(privateVaultUnlockedProvider);
  final rooms =
      ref.watch(chatRoomsProvider).value ?? const <Map<String, dynamic>>[];

  final cloaked = <String>{};

  // 1. Room yang otherUserId-nya termasuk cloaked contact
  for (final room in rooms) {
    final roomId = room['id'] as String?;
    final otherUserId = room['otherUserId'] as String?;
    if (roomId != null) {
      if (otherUserId != null && cloakedUserIds.contains(otherUserId)) {
        cloaked.add(roomId);
      } else if (hiddenRooms.contains(roomId) && !isAnyUnlocked) {
        cloaked.add(roomId);
      }
    }
  }

  // 2. Hidden rooms legacy
  if (!isAnyUnlocked) {
    cloaked.addAll(hiddenRooms);
  }

  return cloaked;
});

/// Helper terpusat untuk evaluasi isolasi status Private Vault (per-slot)
class VaultIsolationHelper {
  /// Menentukan apakah kontak tertentu saat ini sedang terselubung / terkunci (cloaked).
  static bool isContactCloaked(
    dynamic ref,
    String contactUserId, {
    int? knownSlot,
  }) {
    final Set<int> unlockedSlots;
    final List<ContactItem>? contacts;
    final Set<String> hiddenUsers;
    final bool isAnyUnlocked;

    if (ref is WidgetRef) {
      unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      contacts = ref.read(userContactsProvider).value;
      hiddenUsers = ref.read(hiddenContactUserIdsProvider);
      isAnyUnlocked =
          unlockedSlots.isNotEmpty || ref.read(privateVaultUnlockedProvider);
    } else if (ref is Ref) {
      unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      contacts = ref.read(userContactsProvider).value;
      hiddenUsers = ref.read(hiddenContactUserIdsProvider);
      isAnyUnlocked =
          unlockedSlots.isNotEmpty || ref.read(privateVaultUnlockedProvider);
    } else if (ref is ProviderContainer) {
      unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      contacts = ref.read(userContactsProvider).value;
      hiddenUsers = ref.read(hiddenContactUserIdsProvider);
      isAnyUnlocked =
          unlockedSlots.isNotEmpty || ref.read(privateVaultUnlockedProvider);
    } else {
      unlockedSlots = <int>{};
      contacts = null;
      hiddenUsers = <String>{};
      isAnyUnlocked = false;
    }

    ContactItem? contact;
    if (contacts != null) {
      for (final c in contacts) {
        if (c.contactUserId == contactUserId) {
          contact = c;
          break;
        }
      }
    }

    if (contact != null) {
      if (!contact.isVaulted) return false;
      return !unlockedSlots.contains(contact.vaultSlot);
    }

    if (knownSlot != null) {
      return !unlockedSlots.contains(knownSlot);
    }

    if (hiddenUsers.contains(contactUserId)) {
      return !isAnyUnlocked;
    }

    return false;
  }

  /// Mengetahui slot vault milik seorang kontak (default 1 jika tidak ditentukan)
  static int getContactVaultSlot(dynamic ref, String contactUserId) {
    final List<ContactItem>? contacts;
    if (ref is WidgetRef) {
      contacts = ref.read(userContactsProvider).value;
    } else if (ref is Ref) {
      contacts = ref.read(userContactsProvider).value;
    } else if (ref is ProviderContainer) {
      contacts = ref.read(userContactsProvider).value;
    } else {
      contacts = null;
    }

    if (contacts != null) {
      for (final c in contacts) {
        if (c.contactUserId == contactUserId) {
          return c.vaultSlot;
        }
      }
    }

    return 1;
  }

  /// Menentukan apakah ruang obrolan (roomId) beserta lawan bicaranya sedang terselubung (cloaked)
  static bool isRoomCloaked(
    dynamic ref, {
    required String? roomId,
    String? otherUserId,
    int? knownSlot,
  }) {
    if (otherUserId != null && otherUserId.isNotEmpty) {
      return isContactCloaked(ref, otherUserId, knownSlot: knownSlot);
    }

    if (roomId == null) return false;

    final Set<int> unlockedSlots;
    final Set<String> hiddenRooms;
    final bool isAnyUnlocked;

    if (ref is WidgetRef) {
      unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      hiddenRooms = ref.read(hiddenRoomIdsProvider);
      isAnyUnlocked =
          unlockedSlots.isNotEmpty || ref.read(privateVaultUnlockedProvider);
    } else if (ref is Ref) {
      unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      hiddenRooms = ref.read(hiddenRoomIdsProvider);
      isAnyUnlocked =
          unlockedSlots.isNotEmpty || ref.read(privateVaultUnlockedProvider);
    } else if (ref is ProviderContainer) {
      unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      hiddenRooms = ref.read(hiddenRoomIdsProvider);
      isAnyUnlocked =
          unlockedSlots.isNotEmpty || ref.read(privateVaultUnlockedProvider);
    } else {
      unlockedSlots = <int>{};
      hiddenRooms = <String>{};
      isAnyUnlocked = false;
    }

    if (hiddenRooms.contains(roomId)) {
      return !isAnyUnlocked;
    }

    return false;
  }
}

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
    if (!mounted) return;
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
    if (!mounted) return;
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
