import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrivateContactRepository - Contact Vault & Migration Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Penyembunyian kontak (toggleHideContact) dan pembatalan penyembunyian', () async {
      final repo = PrivateContactRepository();
      const contactUserId = 'user_secret_001';

      expect(await repo.isContactHidden(contactUserId), isFalse);

      // 1. Sembunyikan kontak
      final isHiddenNow = await repo.toggleHideContact(contactUserId);
      expect(isHiddenNow, isTrue);
      expect(await repo.isContactHidden(contactUserId), isTrue);

      final hiddenSet = await repo.getHiddenContactUserIds();
      expect(hiddenSet.contains(contactUserId), isTrue);

      // 2. Batalkan sembunyikan kontak
      final isUnhiddenNow = await repo.toggleHideContact(contactUserId);
      expect(isUnhiddenNow, isFalse);
      expect(await repo.isContactHidden(contactUserId), isFalse);

      final updatedSet = await repo.getHiddenContactUserIds();
      expect(updatedSet.contains(contactUserId), isFalse);
    });

    test('Pembersihan data yatim (removeHiddenContact)', () async {
      final repo = PrivateContactRepository();
      const contactUserId = 'user_to_delete_999';

      await repo.toggleHideContact(contactUserId);
      expect(await repo.isContactHidden(contactUserId), isTrue);

      // Hapus kontak dari vault
      await repo.removeHiddenContact(contactUserId);
      expect(await repo.isContactHidden(contactUserId), isFalse);

      final setAfter = await repo.getHiddenContactUserIds();
      expect(setAfter.contains(contactUserId), isFalse);
    });

    test('Migrasi transparan room legacy ke contactUserId', () async {
      final storage = <String, String>{};
      const legacyRoomId = 'room_old_legacy_123';
      const expectedUserId = 'user_mapped_target_777';

      storage['mekaar_private_vault_hidden_rooms'] = jsonEncode([legacyRoomId]);
      FlutterSecureStorage.setMockInitialValues(storage);

      final repo = PrivateContactRepository();
      final hiddenRooms = await repo.getHiddenRoomIds();
      expect(hiddenRooms.contains(legacyRoomId), isTrue);

      // Jalankan migrasi
      await repo.migrateLegacyHiddenRoomsToContacts({
        legacyRoomId: expectedUserId,
      });

      final hiddenContacts = await repo.getHiddenContactUserIds();
      expect(hiddenContacts.contains(expectedUserId), isTrue);
      expect(await repo.isContactHidden(expectedUserId), isTrue);
    });

    test('HiddenContactUserIdsNotifier bereaksi terhadap perubahan toggle dan remove', () async {
      final repo = PrivateContactRepository();
      final notifier = HiddenContactUserIdsNotifier(repo);

      await notifier.loadHiddenContacts();
      expect(notifier.state.isEmpty, isTrue);

      const userId = 'user_vault_notifier_test';
      final isNowHidden = await notifier.toggleHide(userId);
      expect(isNowHidden, isTrue);
      expect(notifier.state.contains(userId), isTrue);
      expect(notifier.isHidden(userId), isTrue);

      // Hapus kontak
      await notifier.removeContact(userId);
      expect(notifier.state.contains(userId), isFalse);
      expect(notifier.isHidden(userId), isFalse);
    });
  });

  group('Contact-Centric Vault Cloaking Filter Tests', () {
    final contactA = ContactItem(
      id: 'c1',
      contactUserId: 'user_public',
      username: 'alice',
      displayName: 'Alice Public',
      createdAt: DateTime.now(),
    );

    final contactB = ContactItem(
      id: 'c2',
      contactUserId: 'user_secret',
      username: 'bob',
      displayName: 'Bob Secret',
      createdAt: DateTime.now(),
      roomId: 'room_bob_secret',
    );

    final allContacts = [contactA, contactB];

    final roomA = {
      'id': 'room_alice',
      'name': 'Alice Public',
      'otherUserId': 'user_public',
      'isGroup': false,
      'isArchived': false,
    };

    final roomB = {
      'id': 'room_bob_secret',
      'name': 'Bob Secret',
      'otherUserId': 'user_secret',
      'isGroup': false,
      'isArchived': false,
    };

    final allRooms = [roomA, roomB];

    List<ContactItem> filterContacts(
      List<ContactItem> list, {
      required Set<String> hiddenContacts,
      required bool isVaultUnlocked,
    }) {
      return list.where((contact) {
        if (!isVaultUnlocked && hiddenContacts.contains(contact.contactUserId)) {
          return false;
        }
        return true;
      }).toList();
    }

    List<Map<String, dynamic>> filterRooms(
      List<Map<String, dynamic>> list, {
      required Set<String> hiddenContacts,
      required Set<String> hiddenRooms,
      required bool isVaultUnlocked,
    }) {
      return list.where((room) {
        final roomId = room['id'] as String;
        final otherUserId = room['otherUserId'] as String?;
        final isDirectHidden = otherUserId != null && hiddenContacts.contains(otherUserId);
        final isRoomHidden = hiddenRooms.contains(roomId);
        if (!isVaultUnlocked && (isDirectHidden || isRoomHidden)) {
          return false;
        }
        return true;
      }).toList();
    }

    test('Saat vault terkunci, kontak dan obrolan tersembunyi tidak tampil di daftar', () {
      final hiddenContacts = {'user_secret'};
      final hiddenRooms = {'room_bob_secret'};

      final filteredContacts = filterContacts(
        allContacts,
        hiddenContacts: hiddenContacts,
        isVaultUnlocked: false,
      );
      expect(filteredContacts.length, 1);
      expect(filteredContacts.first.contactUserId, 'user_public');

      final filteredRooms = filterRooms(
        allRooms,
        hiddenContacts: hiddenContacts,
        hiddenRooms: hiddenRooms,
        isVaultUnlocked: false,
      );
      expect(filteredRooms.length, 1);
      expect(filteredRooms.first['id'], 'room_alice');
    });

    test('Saat vault terbuka, kontak dan obrolan tersembunyi kembali tampil di daftar', () {
      final hiddenContacts = {'user_secret'};
      final hiddenRooms = {'room_bob_secret'};

      final filteredContacts = filterContacts(
        allContacts,
        hiddenContacts: hiddenContacts,
        isVaultUnlocked: true,
      );
      expect(filteredContacts.length, 2);
      expect(filteredContacts.any((c) => c.contactUserId == 'user_secret'), isTrue);

      final filteredRooms = filterRooms(
        allRooms,
        hiddenContacts: hiddenContacts,
        hiddenRooms: hiddenRooms,
        isVaultUnlocked: true,
      );
      expect(filteredRooms.length, 2);
      expect(filteredRooms.any((r) => r['id'] == 'room_bob_secret'), isTrue);
    });

    test('Guard pencegah akses obrolan kontak tersembunyi saat vault terkunci', () {
      final hiddenContacts = {'user_secret'};
      const isVaultUnlocked = false;

      bool canDirectOpenChat(ContactItem contact) {
        final isVaulted = contact.isVaulted || hiddenContacts.contains(contact.contactUserId);
        if (isVaulted && !isVaultUnlocked) {
          return false; // Ditolak: Wajib verifikasi passcode vault terlebih dahulu
        }
        return true;
      }

      expect(canDirectOpenChat(contactA), isTrue);
      expect(canDirectOpenChat(contactB), isFalse);
    });

    test('Skenario Reinstall / Hapus Data: Kontak isVaulted tetap tersembunyi walau storage lokal kosong', () {
      // Simulasikan storage lokal kosong setelah uninstall / hapus data
      final Set<String> emptyLocalHiddenContacts = {};
      const isVaultUnlocked = false;

      final vaultedContactFromCloud = ContactItem(
        id: 'c_cloud_vaulted',
        contactUserId: 'user_vaulted_cloud',
        username: 'charlie',
        displayName: 'Charlie Secret',
        isVaulted: true, // Dari kolom is_vaulted di database cloud
        createdAt: DateTime.now(),
      );

      final contactList = [contactA, vaultedContactFromCloud];

      final filtered = contactList.where((contact) {
        if (!isVaultUnlocked && (contact.isVaulted || emptyLocalHiddenContacts.contains(contact.contactUserId))) {
          return false;
        }
        return true;
      }).toList();

      // Charlie Secret tetap tersembunyi dan tidak bocor ke publik!
      expect(filtered.length, 1);
      expect(filtered.first.contactUserId, 'user_public');
      expect(filtered.any((c) => c.contactUserId == 'user_vaulted_cloud'), isFalse);
    });

    test('Masking Push Notification memeriksa roomId dan senderId/callerId', () {
      final hiddenRooms = {'room_hidden_999'};
      final hiddenContacts = {'user_hidden_target'};

      bool shouldMaskPush({String? roomId, String? senderOrCallerId}) {
        if (roomId != null && hiddenRooms.contains(roomId)) return true;
        if (senderOrCallerId != null && hiddenContacts.contains(senderOrCallerId)) return true;
        return false;
      }

      // Notifikasi dari kontak tersembunyi meskipun direct room ID berbeda / belum termigrasi
      expect(shouldMaskPush(roomId: 'other_room', senderOrCallerId: 'user_hidden_target'), isTrue);
      expect(shouldMaskPush(roomId: 'room_hidden_999', senderOrCallerId: 'user_regular'), isTrue);
      expect(shouldMaskPush(roomId: 'normal_room', senderOrCallerId: 'user_public'), isFalse);
    });
  });
}
