import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Archived Chats Vault Cloaking Tests (P1-2)', () {
    final now = DateTime.now().toUtc();

    final publicContact = ContactItem(
      id: 'c_pub',
      contactUserId: 'u_pub',
      username: 'budi_public',
      displayName: 'Budi Santoso',
      createdAt: now,
      isVaulted: false,
      vaultSlot: 1,
    );

    final slot2Contact = ContactItem(
      id: 'c_s2',
      contactUserId: 'u_s2',
      username: 'slot2_user',
      displayName: 'Kontak Rahasia Slot 2',
      createdAt: now,
      isVaulted: true,
      vaultSlot: 2,
    );

    final testContacts = [publicContact, slot2Contact];

    final testRooms = <Map<String, dynamic>>[
      {
        'id': 'room_pub_archived',
        'name': 'Budi Santoso',
        'otherUserId': 'u_pub',
        'isArchived': true,
      },
      {
        'id': 'room_s2_archived',
        'name': 'Kontak Rahasia Slot 2',
        'otherUserId': 'u_s2',
        'isArchived': true,
      },
      {
        'id': 'room_pub_active',
        'name': 'Budi Santoso (Active)',
        'otherUserId': 'u_pub',
        'isArchived': false,
      },
    ];

    ProviderContainer createContainer({
      Set<int> unlockedSlots = const {},
      bool isVaultUnlocked = false,
      Set<String> hiddenContacts = const {},
      Set<String> hiddenRooms = const {},
    }) {
      final container = ProviderContainer(
        overrides: [
          userContactsProvider.overrideWith((ref) => _FakeContactsNotifier(testContacts)),
          chatRoomsProvider.overrideWith((ref) => _FakeChatRoomsNotifier(testRooms)),
          unlockedVaultSlotsProvider.overrideWith((ref) => unlockedSlots),
          privateVaultUnlockedProvider.overrideWith((ref) => isVaultUnlocked),
          hiddenContactUserIdsProvider.overrideWith((ref) => _FakeHiddenContactUserIdsNotifier(hiddenContacts)),
          hiddenRoomIdsProvider.overrideWith((ref) => _FakeHiddenRoomIdsNotifier(hiddenRooms)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('1. Saat seluruh vault terkunci, room arsip vault (room_s2_archived) cloaked', () {
      final container = createContainer(unlockedSlots: {}, isVaultUnlocked: false);

      final cloakedRooms = container.read(cloakedRoomIdsProvider);
      final cloakedContacts = container.read(cloakedContactUserIdsProvider);

      expect(cloakedRooms.contains('room_s2_archived'), isTrue);
      expect(cloakedContacts.contains('u_s2'), isTrue);

      // Filter seperti pada ArchivedChatsScreen
      final visibleArchived = testRooms.where((r) {
        if (r['isArchived'] != true) return false;
        final roomId = r['id'] as String;
        final otherUserId = r['otherUserId'] as String?;
        if (cloakedRooms.contains(roomId)) return false;
        if (otherUserId != null && cloakedContacts.contains(otherUserId)) return false;
        return true;
      }).toList();

      expect(visibleArchived.length, equals(1));
      expect(visibleArchived.first['id'], equals('room_pub_archived'));
    });

    test('2. Saat Slot 1 dibuka, room arsip Slot 2 TETAP cloaked', () {
      final container = createContainer(unlockedSlots: {1}, isVaultUnlocked: true);

      final cloakedRooms = container.read(cloakedRoomIdsProvider);
      expect(cloakedRooms.contains('room_s2_archived'), isTrue);

      final visibleArchived = testRooms.where((r) {
        if (r['isArchived'] != true) return false;
        final roomId = r['id'] as String;
        final otherUserId = r['otherUserId'] as String?;
        if (cloakedRooms.contains(roomId)) return false;
        if (otherUserId != null && container.read(cloakedContactUserIdsProvider).contains(otherUserId)) {
          return false;
        }
        return true;
      }).toList();

      expect(visibleArchived.length, equals(1));
      expect(visibleArchived.first['id'], equals('room_pub_archived'));
    });

    test('3. Saat Slot 2 dibuka, room arsip Slot 2 muncul di daftar arsip', () {
      final container = createContainer(unlockedSlots: {2}, isVaultUnlocked: true);

      final cloakedRooms = container.read(cloakedRoomIdsProvider);
      expect(cloakedRooms.contains('room_s2_archived'), isFalse);

      final visibleArchived = testRooms.where((r) {
        if (r['isArchived'] != true) return false;
        final roomId = r['id'] as String;
        final otherUserId = r['otherUserId'] as String?;
        if (cloakedRooms.contains(roomId)) return false;
        if (otherUserId != null && container.read(cloakedContactUserIdsProvider).contains(otherUserId)) {
          return false;
        }
        return true;
      }).toList();

      expect(visibleArchived.length, equals(2));
      expect(visibleArchived.any((r) => r['id'] == 'room_s2_archived'), isTrue);
    });
  });

  group('Vault PIN Lockout & Anti-Brute Force Tests (P2-2)', () {
    test('1. Lima kali verifikasi gagal berturut-turut mengaktifkan lockout', () async {
      final repo = PrivateContactRepository();
      await repo.setSlotPasscode(1, '123456');

      expect(await repo.isVaultLockedOut(), isFalse);

      // Lakukan 4 kali percobaan salah
      for (int i = 0; i < 4; i++) {
        final match = await repo.verifySlotPasscode(1, '999999');
        expect(match, isFalse);
        expect(await repo.isVaultLockedOut(), isFalse);
      }

      // Percobaan ke-5 salah -> trigger lockout
      final match5 = await repo.verifySlotPasscode(1, '999999');
      expect(match5, isFalse);
      expect(await repo.isVaultLockedOut(), isTrue);

      final remaining = await repo.getVaultLockoutRemainingSeconds();
      expect(remaining, greaterThan(0));

      // Saat lockout aktif, PIN yang BENAR pun ditolak untuk mencegah brute-force
      final matchWhileLocked = await repo.verifySlotPasscode(1, '123456');
      expect(matchWhileLocked, isFalse);

      // checkAnySlotPasscode juga menolak selama lockout
      final anySlotMatch = await repo.checkAnySlotPasscode('123456');
      expect(anySlotMatch, isNull);
    });

    test('2. Verifikasi sukses mereset counter percobaan gagal', () async {
      final repo = PrivateContactRepository();
      await repo.setSlotPasscode(2, '654321');

      // 3 kali salah
      for (int i = 0; i < 3; i++) {
        await repo.verifySlotPasscode(2, '000000');
      }

      // 1 kali benar
      final match = await repo.verifySlotPasscode(2, '654321');
      expect(match, isTrue);

      // Reset lockout
      expect(await repo.isVaultLockedOut(), isFalse);
    });
  });

  group('Slot Deletion SharedPreferences Cleanup Tests (P3-1)', () {
    test('deleteSlotPasscode membersihkan nama slot di SharedPreferences', () async {
      final repo = PrivateContactRepository();
      await repo.setSlotPasscode(2, '112233');
      await repo.setSlotName(2, 'Lingkaran Rahasia');

      expect(await repo.getSlotName(2), equals('Lingkaran Rahasia'));

      // Hapus slot
      await repo.deleteSlotPasscode(2);

      // Key terhapus, kembali ke nama default 'Profil 2'
      expect(await repo.getSlotName(2), equals('Profil 2'));
    });
  });
}

class _FakeContactsNotifier extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  _FakeContactsNotifier(List<ContactItem> items) : super(AsyncValue.data(items));

  @override
  Future<void> refreshContacts({bool forceLoading = false}) async {}

  @override
  Future<void> updateVaultStatus(
    String contactUserId,
    bool isVaulted, {
    int vaultSlot = 1,
  }) async {}

  @override
  Future<void> deleteContact(String contactUserId) async {}
}

class _FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  _FakeChatRoomsNotifier(List<Map<String, dynamic>> rooms)
      : super(AsyncValue.data(rooms));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<String> getOrCreateRoom(
    String otherUserId,
    String type, {
    bool screenshotEnabled = true,
  }) async =>
      'mock-room-id';

  @override
  void updateLastMessageLocally({
    required String roomId,
    required String previewText,
    required DateTime timestamp,
    required bool isFromOtherUser,
    bool isCurrentlyInRoom = false,
  }) {}
}

class _FakeHiddenContactUserIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenContactUserIdsNotifier {
  _FakeHiddenContactUserIdsNotifier(super.ids);

  @override
  Future<void> loadHiddenContacts() async {}

  @override
  Future<bool> toggleHide(String contactUserId) async => false;

  @override
  Future<void> hideContact(String contactUserId) async {}

  @override
  Future<void> removeContact(String contactUserId) async {}

  @override
  bool isHidden(String contactUserId) => state.contains(contactUserId);
}

class _FakeHiddenRoomIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenRoomIdsNotifier {
  _FakeHiddenRoomIdsNotifier(super.ids);

  @override
  Future<void> loadHiddenRooms() async {}

  @override
  Future<bool> toggleHide(String roomId) async => false;

  @override
  bool isHidden(String roomId) => state.contains(roomId);
}
