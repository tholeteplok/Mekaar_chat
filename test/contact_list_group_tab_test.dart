import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/data/repositories/private_contact_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/nearby_friends_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/contact_list_screen.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier() : super(AuthState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContactsNotifier extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  _FakeContactsNotifier(List<ContactItem> contacts)
      : super(AsyncValue.data(contacts));

  @override
  Future<void> refreshContacts({bool forceLoading = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNearbyNotifier extends StateNotifier<NearbyFriendsState>
    implements NearbyFriendsNotifier {
  _FakeNearbyNotifier() : super(const NearbyFriendsState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHiddenRoomIdsNotifier extends HiddenRoomIdsNotifier {
  _FakeHiddenRoomIdsNotifier(Set<String> initial)
      : super(PrivateContactRepository()) {
    state = initial;
  }

  @override
  Future<void> loadHiddenRooms() async {}
}

class _FakeHiddenContactsNotifier extends HiddenContactUserIdsNotifier {
  _FakeHiddenContactsNotifier() : super(PrivateContactRepository()) {
    state = const <String>{};
  }

  @override
  Future<void> loadHiddenContacts() async {}
}

class _FakeAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    Key? scopeKey,
    List<ContactItem> contacts = const [],
    List<Map<String, dynamic>> rooms = const [],
    Set<String> hiddenRoomIds = const {},
    Set<int> unlockedSlots = const {},
    bool isVaultUnlocked = false,
    void Function(RouteSettings)? onNavigate,
  }) {
    return ProviderScope(
      key: scopeKey,
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        authProvider.overrideWith((ref) => _FakeAuthNotifier()),
        userContactsProvider.overrideWith((ref) => _FakeContactsNotifier(contacts)),
        chatRoomsProvider.overrideWith((ref) => _FakeChatRoomsNotifier(rooms)),
        nearbyFriendsProvider.overrideWith((ref) => _FakeNearbyNotifier()),
        hiddenRoomIdsProvider.overrideWith(
          (ref) => _FakeHiddenRoomIdsNotifier(hiddenRoomIds),
        ),
        hiddenContactUserIdsProvider.overrideWith(
          (ref) => _FakeHiddenContactsNotifier(),
        ),
        unlockedVaultSlotsProvider.overrideWith((ref) => unlockedSlots),
        privateVaultUnlockedProvider.overrideWith((ref) => isVaultUnlocked),
      ],
      child: MaterialApp(
        home: const ContactListScreen(),
        onGenerateRoute: (settings) {
          onNavigate?.call(settings);
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(body: Text('Route: ${settings.name}')),
          );
        },
      ),
    );
  }

  group('ContactListScreen 3 Filter Tabs (Kontak | Grup | Sekitar)', () {
    testWidgets('Merender 3 filter tab Kontak, Grup, dan Sekitar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Header title 'Kontak' + Tab 'Kontak'
      expect(find.text('Kontak'), findsNWidgets(2));
      expect(find.text('Grup'), findsOneWidget);
      expect(find.text('Sekitar'), findsOneWidget);
    });

    testWidgets('Tab Grup hanya menampilkan grup dengan jumlah anggota & mengubah tombol aksi header menjadi Buat Grup Baru', (tester) async {
      final rooms = [
        {
          'id': 'room_direct_1',
          'name': 'Chat Pribadi Salma',
          'isGroup': false,
          'roomType': 'normal',
          'memberCount': 2,
        },
        {
          'id': 'room_group_1',
          'name': 'Tim Mekaar Inti',
          'isGroup': true,
          'roomType': 'group',
          'memberCount': 5,
          'encryptionVersion': 1,
        },
      ];

      await tester.pumpWidget(buildTestWidget(rooms: rooms));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('contact_header_add_contact_btn')),
        findsOneWidget,
      );

      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('contact_header_create_group_btn')),
        findsOneWidget,
      );
      expect(find.text('Tim Mekaar Inti'), findsOneWidget);
      expect(find.text('5 Anggota • Terenkripsi'), findsOneWidget);
      expect(find.text('Chat Pribadi Salma'), findsNothing);
    });

    testWidgets('Grup tersembunyi tidak tampil saat Vault terkunci dan tampil saat Vault terbuka', (tester) async {
      final rooms = [
        {
          'id': 'room_group_secret',
          'name': 'Grup Rahasia',
          'isGroup': true,
          'memberCount': 3,
        },
      ];

      await tester.pumpWidget(
        buildTestWidget(
          scopeKey: const ValueKey('vault_locked'),
          rooms: rooms,
          hiddenRoomIds: {'room_group_secret'},
          unlockedSlots: const {},
          isVaultUnlocked: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      expect(find.text('Grup Rahasia'), findsNothing);
      expect(find.text('Belum Ada Grup'), findsOneWidget);

      await tester.pumpWidget(
        buildTestWidget(
          scopeKey: const ValueKey('vault_unlocked'),
          rooms: rooms,
          hiddenRoomIds: {'room_group_secret'},
          unlockedSlots: const {1, 2, 3},
          isVaultUnlocked: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      expect(find.text('Grup Rahasia'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
    });

    testWidgets('Empty state tab Grup menampilkan CTA Buat Grup Baru yang mengarah ke createGroupSelectMembers', (tester) async {
      String? pushedRoute;
      await tester.pumpWidget(
        buildTestWidget(
          rooms: const [],
          onNavigate: (settings) => pushedRoute = settings.name,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Grup'), findsOneWidget);
      expect(find.text('Buat Grup Baru'), findsOneWidget);

      await tester.tap(find.text('Buat Grup Baru'));
      await tester.pumpAndSettle();

      expect(pushedRoute, AppRoutes.createGroupSelectMembers);
    });
  });
}
