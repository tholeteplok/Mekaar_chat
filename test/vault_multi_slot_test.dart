import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';

void main() {
  group('Vault Multi-Slot Isolation & Management Unit Tests', () {
    final now = DateTime.now().toUtc();

    final publicContact = ContactItem(
      id: 'c_public_1',
      contactUserId: 'u_public_1',
      username: 'budi_public',
      displayName: 'Budi Santoso',
      createdAt: now,
      isVaulted: false,
      vaultSlot: 1,
    );

    final slot1Contact = ContactItem(
      id: 'c_slot1_1',
      contactUserId: 'u_slot1_1',
      username: 'klien_rahasia_a',
      displayName: 'Klien Handoko (Slot 1)',
      createdAt: now,
      isVaulted: true,
      vaultSlot: 1,
    );

    final slot2Contact = ContactItem(
      id: 'c_slot2_1',
      contactUserId: 'u_slot2_1',
      username: 'keluarga_jauh_b',
      displayName: 'Paman Joko (Slot 2)',
      createdAt: now,
      isVaulted: true,
      vaultSlot: 2,
    );

    final slot3Contact = ContactItem(
      id: 'c_slot3_1',
      contactUserId: 'u_slot3_1',
      username: 'spesial_c',
      displayName: 'Teman Spesial (Slot 3)',
      createdAt: now,
      isVaulted: true,
      vaultSlot: 3,
    );

    final allContacts = [publicContact, slot1Contact, slot2Contact, slot3Contact];

    List<ContactItem> filterContactsByUnlockedSlots(
      List<ContactItem> contacts,
      Set<int> unlockedSlots,
    ) {
      return contacts.where((c) {
        if (!c.isVaulted) return true;
        return unlockedSlots.contains(c.vaultSlot);
      }).toList();
    }

    test('Saat seluruh vault terkunci, hanya kontak publik yang tampil', () {
      final result = filterContactsByUnlockedSlots(allContacts, {});
      expect(result.length, 1);
      expect(result.first.contactUserId, 'u_public_1');
    });

    test('Saat Slot 1 terbuka, HANYA kontak Slot 1 dan kontak publik yang tampil (Isolasi Slot 1)', () {
      final result = filterContactsByUnlockedSlots(allContacts, {1});
      expect(result.length, 2);
      expect(result.any((c) => c.contactUserId == 'u_public_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot1_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot2_1'), isFalse);
      expect(result.any((c) => c.contactUserId == 'u_slot3_1'), isFalse);
    });

    test('Saat Slot 2 terbuka, HANYA kontak Slot 2 dan kontak publik yang tampil (Isolasi Slot 2)', () {
      final result = filterContactsByUnlockedSlots(allContacts, {2});
      expect(result.length, 2);
      expect(result.any((c) => c.contactUserId == 'u_public_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot2_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot1_1'), isFalse);
      expect(result.any((c) => c.contactUserId == 'u_slot3_1'), isFalse);
    });

    test('Saat Slot 3 terbuka, HANYA kontak Slot 3 dan kontak publik yang tampil (Isolasi Slot 3)', () {
      final result = filterContactsByUnlockedSlots(allContacts, {3});
      expect(result.length, 2);
      expect(result.any((c) => c.contactUserId == 'u_public_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot3_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot1_1'), isFalse);
      expect(result.any((c) => c.contactUserId == 'u_slot2_1'), isFalse);
    });

    test('Pemindahan kontak antar-slot memperbarui nomor slot secara presisi', () {
      final moved = slot1Contact.copyWith(vaultSlot: 2);
      expect(moved.vaultSlot, 2);
      expect(moved.isVaulted, isTrue);

      final resultBefore = filterContactsByUnlockedSlots([moved], {1});
      expect(resultBefore.isEmpty, isTrue);

      final resultAfter = filterContactsByUnlockedSlots([moved], {2});
      expect(resultAfter.length, 1);
      expect(resultAfter.first.contactUserId, 'u_slot1_1');
    });

    test('Menghapus slot mengeluarkan kontak ke daftar publik', () {
      // Simulasikan efek RPC delete_vault_slot untuk slot 2
      final afterDeleteSlot2 = allContacts.map((c) {
        if (c.vaultSlot == 2 && c.isVaulted) {
          return c.copyWith(isVaulted: false, vaultSlot: 1);
        }
        return c;
      }).toList();

      // Saat vault terkunci, kontak bekas slot 2 kini sudah publik dan tampil
      final result = filterContactsByUnlockedSlots(afterDeleteSlot2, {});
      expect(result.length, 2);
      expect(result.any((c) => c.contactUserId == 'u_public_1'), isTrue);
      expect(result.any((c) => c.contactUserId == 'u_slot2_1'), isTrue);
    });
  });
}
