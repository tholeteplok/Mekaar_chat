import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';

void main() {
  group('Vault Multi-Slot Isolation Leak Prevention Tests', () {
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

    final slot1Contact = ContactItem(
      id: 'c_s1',
      contactUserId: 'u_s1',
      username: 'slot1_user',
      displayName: 'Kontak Rahasia Slot 1',
      createdAt: now,
      isVaulted: true,
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

    final slot3Contact = ContactItem(
      id: 'c_s3',
      contactUserId: 'u_s3',
      username: 'slot3_user',
      displayName: 'Kontak Rahasia Slot 3',
      createdAt: now,
      isVaulted: true,
      vaultSlot: 3,
    );

    final testContacts = [
      publicContact,
      slot1Contact,
      slot2Contact,
      slot3Contact,
    ];

    final testRooms = <Map<String, dynamic>>[
      {
        'id': 'room_pub',
        'name': 'Budi Santoso',
        'otherUserId': 'u_pub',
        'unreadCount': 2,
      },
      {
        'id': 'room_s1',
        'name': 'Kontak Rahasia Slot 1',
        'otherUserId': 'u_s1',
        'unreadCount': 5,
      },
      {
        'id': 'room_s2',
        'name': 'Kontak Rahasia Slot 2',
        'otherUserId': 'u_s2',
        'unreadCount': 7,
      },
      {
        'id': 'room_s3',
        'name': 'Kontak Rahasia Slot 3',
        'otherUserId': 'u_s3',
        'unreadCount': 3,
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

    test('1. Kontak publik tidak pernah dianggap cloaked', () {
      final container = createContainer();
      final isCloaked = VaultIsolationHelper.isContactCloaked(
        container,
        publicContact.contactUserId,
      );
      expect(isCloaked, isFalse);
    });

    test('2. Saat seluruh vault terkunci, kontak Slot 1..3 semuanya cloaked', () {
      final container = createContainer();
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s1'), isTrue);
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s2'), isTrue);
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s3'), isTrue);

      final cloakedIds = container.read(cloakedContactUserIdsProvider);
      expect(cloakedIds.contains('u_s1'), isTrue);
      expect(cloakedIds.contains('u_s2'), isTrue);
      expect(cloakedIds.contains('u_s3'), isTrue);
      expect(cloakedIds.contains('u_pub'), isFalse);
    });

    test('3. Saat Slot 1 dibuka, Slot 2 dan Slot 3 TETAP cloaked (Strict Multi-Slot Isolation)', () {
      final container = createContainer(
        unlockedSlots: {1},
        isVaultUnlocked: true,
      );

      // Slot 1 harus terbuka (tidak cloaked)
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s1'), isFalse);

      // Slot 2 & Slot 3 HARUS tetap cloaked!
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s2'), isTrue);
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s3'), isTrue);

      final cloakedIds = container.read(cloakedContactUserIdsProvider);
      expect(cloakedIds.contains('u_s1'), isFalse);
      expect(cloakedIds.contains('u_s2'), isTrue);
      expect(cloakedIds.contains('u_s3'), isTrue);
    });

    test('4. Room isolasi: Room milik kontak Slot 2 tetap cloaked saat Slot 1 terbuka', () {
      final container = createContainer(
        unlockedSlots: {1},
        isVaultUnlocked: true,
      );

      // Room Slot 1 terbuka
      expect(
        VaultIsolationHelper.isRoomCloaked(
          container,
          roomId: 'room_s1',
          otherUserId: 'u_s1',
        ),
        isFalse,
      );

      // Room Slot 2 & Slot 3 tetap cloaked
      expect(
        VaultIsolationHelper.isRoomCloaked(
          container,
          roomId: 'room_s2',
          otherUserId: 'u_s2',
        ),
        isTrue,
      );

      final cloakedRooms = container.read(cloakedRoomIdsProvider);
      expect(cloakedRooms.contains('room_s1'), isFalse);
      expect(cloakedRooms.contains('room_s2'), isTrue);
      expect(cloakedRooms.contains('room_s3'), isTrue);
      expect(cloakedRooms.contains('room_pub'), isFalse);
    });

    test('5. Anti-Phantom Unread Badge: Total unread hanya menghitung publik + slot yang terbuka', () {
      final container = createContainer(
        unlockedSlots: {1},
        isVaultUnlocked: true,
      );

      final cloakedRooms = container.read(cloakedRoomIdsProvider);
      final cloakedContacts = container.read(cloakedContactUserIdsProvider);
      final rooms = container.read(chatRoomsProvider).value!;

      final totalUnread = rooms.fold<int>(0, (sum, r) {
        final otherUserId = r['otherUserId'] as String?;
        if (cloakedRooms.contains(r['id']) ||
            (otherUserId != null && cloakedContacts.contains(otherUserId))) {
          return sum;
        }
        return sum + ((r['unreadCount'] as int?) ?? 0);
      });

      // Total seharusnya: room_pub (2) + room_s1 (5) = 7.
      // room_s2 (7) dan room_s3 (3) TIDAK boleh ikut terhitung!
      expect(totalUnread, equals(7));
    });

    test('6. Slot 2 & 3 terbuka secara simultan jika kedua slot di-unlock', () {
      final container = createContainer(
        unlockedSlots: {2, 3},
        isVaultUnlocked: true,
      );

      // Slot 1 tetap cloaked
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s1'), isTrue);

      // Slot 2 & Slot 3 terbuka
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s2'), isFalse);
      expect(VaultIsolationHelper.isContactCloaked(container, 'u_s3'), isFalse);
    });

    test('7. getContactVaultSlot mengembalikan slot yang tepat', () {
      final container = createContainer();
      expect(VaultIsolationHelper.getContactVaultSlot(container, 'u_pub'), equals(1));
      expect(VaultIsolationHelper.getContactVaultSlot(container, 'u_s1'), equals(1));
      expect(VaultIsolationHelper.getContactVaultSlot(container, 'u_s2'), equals(2));
      expect(VaultIsolationHelper.getContactVaultSlot(container, 'u_s3'), equals(3));
      // Kontak tak dikenal default ke 1
      expect(VaultIsolationHelper.getContactVaultSlot(container, 'u_unknown'), equals(1));
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
