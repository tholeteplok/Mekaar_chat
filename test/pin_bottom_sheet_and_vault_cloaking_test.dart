import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';

class FakePrivateContactRepository extends Fake implements PrivateContactRepository {
  Set<String> inMemoryHiddenContacts = {};
  Set<String> inMemoryHiddenRooms = {};

  @override
  Set<String> get cachedHiddenContactUserIds => Set.from(inMemoryHiddenContacts);

  @override
  Set<String> get cachedHiddenRoomIds => Set.from(inMemoryHiddenRooms);

  @override
  Future<void> preloadCache() async {}

  @override
  Future<Set<String>> getHiddenContactUserIds() async => Set.from(inMemoryHiddenContacts);

  @override
  Future<Set<String>> getHiddenRoomIds() async => Set.from(inMemoryHiddenRooms);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Private Contact Vault Anti-Flash & 0ms Cloaking Tests', () {
    test('PrivateContactRepository synchronous getters mengembalikan cache memori instan (0ms)', () {
      final fakeRepo = FakePrivateContactRepository();
      fakeRepo.inMemoryHiddenContacts = {'secret_user_1', 'secret_user_2'};
      fakeRepo.inMemoryHiddenRooms = {'secret_room_1'};

      expect(fakeRepo.cachedHiddenContactUserIds, containsAll(['secret_user_1', 'secret_user_2']));
      expect(fakeRepo.cachedHiddenRoomIds, contains('secret_room_1'));
    });

    test('HiddenContactUserIdsNotifier terhidrasi seketika pada Frame 0 dari cache sinkron', () {
      final fakeRepo = FakePrivateContactRepository();
      fakeRepo.inMemoryHiddenContacts = {'vault_user_target'};

      final notifier = HiddenContactUserIdsNotifier(fakeRepo);
      // State Frame 0 WAJIB langsung memuat ID rahasia tanpa menunggu asynchronous _init()
      expect(notifier.state, contains('vault_user_target'));
      notifier.dispose();
    });

    test('HiddenRoomIdsNotifier terhidrasi seketika pada Frame 0 dari cache sinkron', () {
      final fakeRepo = FakePrivateContactRepository();
      fakeRepo.inMemoryHiddenRooms = {'vault_room_target'};

      final notifier = HiddenRoomIdsNotifier(fakeRepo);
      // State Frame 0 WAJIB langsung memuat ID rahasia tanpa menunggu asynchronous _init()
      expect(notifier.state, contains('vault_room_target'));
      notifier.dispose();
    });

    test('cloakedContactUserIdsProvider langsung menyaring kontak rahasia meskipun userContactsProvider masih loading', () {
      final fakeRepo = FakePrivateContactRepository();
      fakeRepo.inMemoryHiddenContacts = {'classified_user_99'};

      final container = ProviderContainer(
        overrides: [
          privateContactRepositoryProvider.overrideWithValue(fakeRepo),
          hiddenContactUserIdsProvider.overrideWith((ref) => HiddenContactUserIdsNotifier(fakeRepo)),
          unlockedVaultSlotsProvider.overrideWith((ref) => <int>{}),
          privateVaultUnlockedProvider.overrideWith((ref) => false),
          // userContactsProvider masih dalam state AsyncValue.loading() (simulasi jaringan/cloud lambat)
          userContactsProvider.overrideWith((ref) => FakeContactsNotifier(const AsyncValue.loading())),
        ],
      );

      final cloakedIds = container.read(cloakedContactUserIdsProvider);

      // Verifikasi Anti-Flash: Kontak rahasia SUDAH tersaring pada Frame 0
      expect(cloakedIds, contains('classified_user_99'));

      container.dispose();
    });

    test('cloakedRoomIdsProvider langsung menyaring room kontak rahasia saat kontak terselubung', () {
      final fakeRepo = FakePrivateContactRepository();
      fakeRepo.inMemoryHiddenContacts = {'classified_user_99'};
      fakeRepo.inMemoryHiddenRooms = {'classified_room_88'};

      final container = ProviderContainer(
        overrides: [
          privateContactRepositoryProvider.overrideWithValue(fakeRepo),
          hiddenContactUserIdsProvider.overrideWith((ref) => HiddenContactUserIdsNotifier(fakeRepo)),
          hiddenRoomIdsProvider.overrideWith((ref) => HiddenRoomIdsNotifier(fakeRepo)),
          unlockedVaultSlotsProvider.overrideWith((ref) => <int>{}),
          privateVaultUnlockedProvider.overrideWith((ref) => false),
          userContactsProvider.overrideWith((ref) => FakeContactsNotifier(const AsyncValue.loading())),
          chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier([])),
        ],
      );

      final cloakedRooms = container.read(cloakedRoomIdsProvider);

      // Verifikasi Anti-Flash: Room tersembunyi legacy maupun room kontak rahasia langsung tersaring
      expect(cloakedRooms, contains('classified_room_88'));

      container.dispose();
    });
  });
}

class FakeContactsNotifier extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  FakeContactsNotifier(super.state);

  @override
  Future<void> refreshContacts({bool forceLoading = false}) async {}

  @override
  Future<void> updateVaultStatus(String contactUserId, bool isVaulted, {int vaultSlot = 1}) async {}

  @override
  Future<void> deleteContact(String contactUserId) async {}
}

class FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  FakeChatRoomsNotifier(List<Map<String, dynamic>> rooms)
      : super(AsyncValue.data(rooms));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<void> reloadFromLocalCache({bool syncRemoteInBackground = true}) async {}

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
