import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:mekaar_chat/core/widgets/mekaar_selection_header.dart';
import 'package:mekaar_chat/core/widgets/mekaar_selection_indicator.dart';
import 'package:mekaar_chat/data/models/blocked_user_model.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/block_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_request_repository.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/nearby_friends_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/chat_list_screen.dart';
import 'package:mekaar_chat/features/chat/screens/contact_list_screen.dart';
import 'package:mekaar_chat/features/settings/providers/block_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';

class _FakeAuthRepo extends Fake implements AuthRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AuthState initial) : super(_FakeAuthRepo()) {
    state = initial;
  }
}

class _FakeChatRepo extends Fake implements ChatRepository {
  @override
  Future<List<Map<String, dynamic>>> getRooms() async => [];

  @override
  Future<void> deleteChat(String roomId) async {}
}

class _FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  _FakeChatRoomsNotifier(List<Map<String, dynamic>> rooms)
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
      'dummy-room';

  @override
  void updateLastMessageLocally({
    required String roomId,
    required String previewText,
    required DateTime timestamp,
    required bool isFromOtherUser,
    required bool isCurrentlyInRoom,
    bool isSending = false,
  }) {}

  @override
  void updateOtherLastReadLocally(String roomId, DateTime readAt) {}
}

class _SpyChatActions extends Fake implements ChatActionsNotifier {
  final List<String> deletedRoomIds = [];
  final List<String> markedReadRoomIds = [];

  @override
  Future<void> deleteChat(String roomId) async {
    deletedRoomIds.add(roomId);
  }

  @override
  Future<void> markRoomRead(String roomId) async {
    markedReadRoomIds.add(roomId);
  }
}

class _FakeBlockRepo extends Fake implements BlockRepository {
  @override
  Future<List<BlockedUser>> listBlocked() async => const [];
}

class _FakeBlockNotifier extends BlockNotifier {
  _FakeBlockNotifier() : super(_FakeBlockRepo()) {
    state = const AsyncValue.data([]);
  }
}

class _FakeNearbyFriendsNotifier extends StateNotifier<NearbyFriendsState>
    implements NearbyFriendsNotifier {
  _FakeNearbyFriendsNotifier() : super(const NearbyFriendsState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContactRepo extends Fake implements ContactRepository {}

class _SpyUserContactsNotifier extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  final List<String> deletedContactIds = [];

  _SpyUserContactsNotifier(List<ContactItem> initial)
      : super(AsyncValue.data(initial));

  @override
  Future<void> refreshContacts({bool forceLoading = false}) async {}

  @override
  Future<void> deleteContact(String contactUserId) async {
    deletedContactIds.add(contactUserId);
    state.whenData((list) {
      state = AsyncValue.data(
        list.where((c) => c.contactUserId != contactUserId).toList(),
      );
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('T22 — Komponen Sentral Multi-Select', () {
    testWidgets('MekaarSelectionHeader menampilkan counter, toggle select-all, dan overflow menu', (
      tester,
    ) async {
      var closed = false;
      var toggledAll = false;
      var overflowTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarSelectionHeader(
              selectedCount: 3,
              allSelected: false,
              onClose: () => closed = true,
              onToggleSelectAll: () => toggledAll = true,
              maxVisibleInlineActions: 2,
              actions: [
                MekaarSelectionAction(
                  icon: SolarIconsOutline.trashBinTrash,
                  label: 'Hapus',
                  tooltip: 'Hapus',
                  isDestructive: true,
                  onPressed: () {},
                ),
                MekaarSelectionAction(
                  icon: SolarIconsOutline.archive,
                  label: 'Arsipkan',
                  tooltip: 'Arsipkan',
                  onPressed: () {},
                ),
                MekaarSelectionAction(
                  icon: SolarIconsOutline.checkCircle,
                  label: 'Tandai Dibaca',
                  tooltip: 'Tandai Dibaca',
                  onPressed: () => overflowTriggered = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('3 dipilih'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mekaar_selection_overflow_btn')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('mekaar_selection_overflow_btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tandai Dibaca'));
      await tester.pumpAndSettle();
      expect(overflowTriggered, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('mekaar_selection_select_all_btn')),
      );
      await tester.tap(
        find.byKey(const ValueKey('mekaar_selection_close_btn')),
      );
      expect(toggledAll, isTrue);
      expect(closed, isTrue);
    });

    testWidgets('MekaarSelectionAvatar hanya menampilkan badge centang saat selection mode & terpilih', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                MekaarSelectionAvatar(
                  initial: 'A',
                  isSelectionMode: true,
                  isSelected: true,
                ),
                MekaarSelectionAvatar(
                  initial: 'B',
                  isSelectionMode: true,
                  isSelected: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scales = tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .toList();
      expect(scales.length, 2);
      expect(scales[0].scale, 1.0);
      expect(scales[1].scale, 0.0);
    });
  });

  group('T23 — Menu Tekan-Tahan Grup & Multi-Select ChatListScreen', () {
    final nowUtc = DateTime.utc(2026, 11, 19, 10, 0);

    List<Map<String, dynamic>> sampleRooms() => [
      {
        'id': 'room-group-1',
        'name': 'Keluarga Mekaar',
        'lastMessage': 'Dih',
        'timestamp': nowUtc,
        'unreadCount': 2,
        'isArchived': false,
        'isGuardian': false,
        'isGroup': true,
        'isMuted': false,
      },
      {
        'id': 'room-dm-1',
        'name': 'Salma',
        'otherUserId': 'user-salma',
        'lastMessage': 'Hadir',
        'timestamp': nowUtc.subtract(const Duration(minutes: 5)),
        'unreadCount': 0,
        'isArchived': false,
        'isGuardian': true,
        'isGroup': false,
        'isMuted': false,
      },
    ];

    Widget buildChatListWidget({
      required List<Map<String, dynamic>> rooms,
      required _SpyChatActions spyActions,
      AuthUnlockMode unlockMode = AuthUnlockMode.master,
    }) {
      return ProviderScope(
        key: ValueKey('chat_scope_${unlockMode.name}'),
        overrides: [
          authProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              AuthState(unlockMode: unlockMode, isPinSet: true),
            ),
          ),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepo()),
          chatRoomsProvider.overrideWith(
            (ref) => _FakeChatRoomsNotifier(rooms),
          ),
          chatActionsProvider.overrideWithValue(spyActions),
          contactRepositoryProvider.overrideWithValue(_FakeContactRepo()),
          userContactsProvider.overrideWith(
            (ref) => _SpyUserContactsNotifier(const []),
          ),
          blockProvider.overrideWith((ref) => _FakeBlockNotifier()),
          pendingRequestsCountStreamProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          cloakedRoomIdsProvider.overrideWith((ref) => <String>{}),
          cloakedContactUserIdsProvider.overrideWith((ref) => <String>{}),
          sosFeatureEnabledProvider.overrideWith(
            (ref) => SOSFeatureEnabledNotifier(null, false),
          ),
        ],
        child: const MaterialApp(
          home: ChatListScreen(),
        ),
      );
    }

    testWidgets('Tekan tahan grup menampilkan Info & Pengaturan Grup serta Keluar dari Grup (bukan Info Kontak)', (
      tester,
    ) async {
      final spy = _SpyChatActions();
      await tester.pumpWidget(
        buildChatListWidget(rooms: sampleRooms(), spyActions: spy),
      );
      await tester.pumpAndSettle();

      // Tekan tahan item grup
      await tester.longPress(find.text('Keluarga Mekaar'));
      await tester.pumpAndSettle();

      expect(find.text('Info & Pengaturan Grup'), findsOneWidget);
      expect(find.text('Keluar dari Grup'), findsOneWidget);
      expect(find.text('Pilih Beberapa'), findsOneWidget);
      expect(find.text('Hapus Chat'), findsOneWidget);
      expect(find.text('Info Kontak & Pengaturan'), findsNothing);

      // Tutup sheet, lalu tekan tahan item DM
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Salma'));
      await tester.pumpAndSettle();

      expect(find.text('Info Kontak & Pengaturan'), findsOneWidget);
      expect(find.text('Info & Pengaturan Grup'), findsNothing);
      expect(find.text('Keluar dari Grup'), findsNothing);
    });

    testWidgets('Multi-select di ChatListScreen menghapus beberapa obrolan sekaligus (Master) dan Silent Vault (Guest)', (
      tester,
    ) async {
      final spyMaster = _SpyChatActions();
      await tester.pumpWidget(
        buildChatListWidget(
          rooms: sampleRooms(),
          spyActions: spyMaster,
          unlockMode: AuthUnlockMode.master,
        ),
      );
      await tester.pumpAndSettle();

      // Ikon multi-select di header tidak ditampilkan (masuk lewat bottom sheet)
      expect(
        find.byKey(const ValueKey('chat_list_select_mode_btn')),
        findsNothing,
      );

      // Masuk multi-select lewat tekan-tahan item -> Pilih Beberapa di bottom sheet
      await tester.longPress(find.text('Keluarga Mekaar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih Beberapa'));
      await tester.pumpAndSettle();

      expect(find.text('1 dipilih'), findsOneWidget);

      // Pilih Semua
      await tester.tap(
        find.byKey(const ValueKey('mekaar_selection_select_all_btn')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 dipilih'), findsOneWidget);

      // Hapus Massal
      await tester.tap(find.byKey(const ValueKey('chat_bulk_delete_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus 2 Obrolan?'), findsOneWidget);

      await tester.tap(find.text('Hapus (Hanya Saya)'));
      await tester.pumpAndSettle();

      expect(
        spyMaster.deletedRoomIds,
        containsAll(['room-group-1', 'room-dm-1']),
      );

      // Mode Tamu: Hapus massal TIDAK memanggil deleteChat server/lokal
      final spyGuest = _SpyChatActions();
      await tester.pumpWidget(
        buildChatListWidget(
          rooms: sampleRooms(),
          spyActions: spyGuest,
          unlockMode: AuthUnlockMode.decoy,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Keluarga Mekaar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih Beberapa'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('mekaar_selection_select_all_btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat_bulk_delete_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus (Hanya Saya)'));
      await tester.pumpAndSettle();

      expect(spyGuest.deletedRoomIds, isEmpty);
    });
  });

  group('T24 — Multi-Select ContactListScreen (List & Grid)', () {
    final nowUtc = DateTime.utc(2026, 11, 19, 10, 0);

    List<ContactItem> sampleContacts() => [
      ContactItem(
        id: 'c1',
        contactUserId: 'user-ani',
        username: 'ani',
        displayName: 'Ani',
        createdAt: nowUtc,
        roomId: 'room-ani',
      ),
      ContactItem(
        id: 'c2',
        contactUserId: 'user-budi',
        username: 'budi',
        displayName: 'Budi',
        createdAt: nowUtc.subtract(const Duration(hours: 1)),
        roomId: 'room-budi',
      ),
    ];

    Widget buildContactListWidget({
      required _SpyUserContactsNotifier contactsNotifier,
      AuthUnlockMode unlockMode = AuthUnlockMode.master,
    }) {
      return ProviderScope(
        key: ValueKey('chat_scope_${unlockMode.name}'),
        overrides: [
          authProvider.overrideWith(
            (ref) => _FakeAuthNotifier(
              AuthState(unlockMode: unlockMode, isPinSet: true),
            ),
          ),
          contactRepositoryProvider.overrideWithValue(_FakeContactRepo()),
          userContactsProvider.overrideWith((ref) => contactsNotifier),
          nearbyFriendsProvider.overrideWith(
            (ref) => _FakeNearbyFriendsNotifier(),
          ),
        ],
        child: const MaterialApp(
          home: ContactListScreen(),
        ),
      );
    }

    testWidgets('Multi-select lewat tekan-tahan kontak menghapus beberapa kontak di Master & menjaga data di Guest', (
      tester,
    ) async {
      final masterContacts = _SpyUserContactsNotifier(sampleContacts());
      await tester.pumpWidget(
        buildContactListWidget(
          contactsNotifier: masterContacts,
          unlockMode: AuthUnlockMode.master,
        ),
      );
      await tester.pumpAndSettle();

      // Tekan tahan Ani -> Pilih Beberapa
      await tester.longPress(find.text('Ani'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih Beberapa'));
      await tester.pumpAndSettle();

      expect(find.text('1 dipilih'), findsOneWidget);

      // Tap Budi untuk menambah pilihan
      await tester.tap(find.text('Budi'));
      await tester.pumpAndSettle();
      expect(find.text('2 dipilih'), findsOneWidget);

      // Pastikan aksi Buat Grup & Sembunyikan ke Vault tersedia di Master
      expect(
        find.byKey(const ValueKey('contact_bulk_create_group_btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contact_bulk_vault_btn')),
        findsOneWidget,
      );

      // Hapus Massal
      await tester.tap(find.byKey(const ValueKey('contact_bulk_delete_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus 2 Kontak?'), findsOneWidget);

      await tester.tap(find.text('Hapus Kontak & Chat'));
      await tester.pumpAndSettle();

      expect(
        masterContacts.deletedContactIds,
        containsAll(['user-ani', 'user-budi']),
      );

      // Mode Tamu: Hapus massal tidak memanggil deleteContact & tombol Vault tersembunyi
      final guestContacts = _SpyUserContactsNotifier(sampleContacts());
      await tester.pumpWidget(
        buildContactListWidget(
          contactsNotifier: guestContacts,
          unlockMode: AuthUnlockMode.decoy,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Ani'));
      await tester.pumpAndSettle();
      expect(find.text('Sembunyikan ke Private Vault'), findsNothing);
      await tester.tap(find.text('Pilih Beberapa'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('contact_bulk_vault_btn')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('contact_bulk_delete_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus Kontak & Chat'));
      await tester.pumpAndSettle();

      expect(guestContacts.deletedContactIds, isEmpty);
    });
  });
}
