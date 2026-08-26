import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/models/nearby_friend_model.dart';
import 'package:mekaar_chat/features/chat/widgets/nearby_consent_dialog.dart';
import 'package:mekaar_chat/features/chat/widgets/nearby_friends_canvas.dart';
import 'package:mekaar_chat/features/chat/providers/nearby_friends_provider.dart';
import 'package:mekaar_chat/data/repositories/nearby_repository.dart';

import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class FakeNearbyRepository implements NearbyRepository {
  NearbyPreferences _prefs = const NearbyPreferences(enabled: false);
  List<NearbyFriendModel> mockFriends = [];

  @override
  Future<NearbyPreferences> getPreferences() async => _prefs;

  @override
  Future<NearbyPreferences> updatePreferences({
    required bool enabled,
    String? visibilityMode,
  }) async {
    _prefs = NearbyPreferences(
      enabled: enabled,
      visibilityMode: visibilityMode ?? _prefs.visibilityMode,
      updatedAt: DateTime.now(),
    );
    return _prefs;
  }

  @override
  Future<List<NearbyFriendModel>> updateLocationAndFetchNearby({
    required double latitude,
    required double longitude,
  }) async {
    return mockFriends;
  }

  @override
  Future<void> disableNearbySharing() async {
    _prefs = const NearbyPreferences(enabled: false);
  }
}

class FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  FakeChatRoomsNotifier(List<Map<String, dynamic>> rooms)
      : super(AsyncValue.data(rooms));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<String> getOrCreateRoom(
    String otherUserId,
    String type, {
    bool screenshotEnabled = true,
  }) async => 'mock-room-id';
}

class FakeHiddenRoomIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenRoomIdsNotifier {
  FakeHiddenRoomIdsNotifier(super.ids);

  @override
  Future<void> loadHiddenRooms() async {}

  @override
  Future<bool> toggleHide(String roomId) async => false;

  @override
  bool isHidden(String roomId) => state.contains(roomId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NearbyFriendModel & NearbyBand Unit Tests', () {
    test('NearbyBand enum properties and parsing', () {
      expect(NearbyBand.fromString('very_close'), equals(NearbyBand.veryClose));
      expect(NearbyBand.fromString('close'), equals(NearbyBand.close));
      expect(NearbyBand.fromString('same_city'), equals(NearbyBand.sameCity));
      expect(NearbyBand.fromString('unknown'), equals(NearbyBand.sameCity));

      expect(NearbyBand.veryClose.avatarSize, equals(68.0));
      expect(NearbyBand.close.avatarSize, equals(54.0));
      expect(NearbyBand.sameCity.avatarSize, equals(42.0));

      expect(NearbyBand.veryClose.shortLabel, equals('Dekatmu'));
      expect(NearbyBand.close.shortLabel, equals('Sekitarmu'));
      expect(NearbyBand.sameCity.shortLabel, equals('Di kotamu'));
    });

    test('NearbyFriendModel serialization and deserialization', () {
      final json = {
        'user_id': 'user-abc',
        'display_name': 'Budi Santoso',
        'avatar_url': 'https://example.com/avatar.jpg',
        'band': 'very_close',
        'is_recent': true,
        'is_contact': true,
        'chat_invitation_mode': 'all',
      };

      final model = NearbyFriendModel.fromJson(json);
      expect(model.userId, equals('user-abc'));
      expect(model.displayName, equals('Budi Santoso'));
      expect(model.band, equals(NearbyBand.veryClose));
      expect(model.isRecent, isTrue);
      expect(model.isContact, isTrue);

      final encoded = model.toJson();
      expect(encoded['user_id'], equals('user-abc'));
      expect(encoded['band'], equals('very_close'));
    });

    test('NearbyPreferences serialization', () {
      final prefs = const NearbyPreferences(
        enabled: true,
        visibilityMode: 'everyone',
      );

      final json = prefs.toJson();
      expect(json['enabled'], isTrue);
      expect(json['visibility_mode'], equals('everyone'));

      final parsed = NearbyPreferences.fromJson(json);
      expect(parsed.enabled, isTrue);
      expect(parsed.visibilityMode, equals('everyone'));
    });

    test('NearbyFriendsState filteredFriends filtering logic', () {
      const friendContact = NearbyFriendModel(
        userId: 'u1',
        displayName: 'Contact Friend',
        band: NearbyBand.veryClose,
        isRecent: true,
        isContact: true,
      );
      const friendNonContact = NearbyFriendModel(
        userId: 'u2',
        displayName: 'Stranger',
        band: NearbyBand.close,
        isRecent: true,
        isContact: false,
      );

      final stateAll = const NearbyFriendsState(
        visibilityMode: 'everyone',
        friends: [friendContact, friendNonContact],
      );
      expect(stateAll.filteredFriends.length, equals(2));

      final stateContactsOnly = const NearbyFriendsState(
        visibilityMode: 'contacts_only',
        friends: [friendContact, friendNonContact],
      );
      expect(stateContactsOnly.filteredFriends.length, equals(1));
      expect(stateContactsOnly.filteredFriends.first.displayName, equals('Contact Friend'));
    });
  });

  group('NearbyConsentDialog Widget Tests', () {
    testWidgets('Membatalkan consent dialog memicu onCancel', (tester) async {
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyConsentDialog(
              onAccept: () {},
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Nanti Saja'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets('Menerima consent dialog memicu onAccept', (tester) async {
      var accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyConsentDialog(
              onAccept: () => accepted = true,
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aktifkan Fitur'));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
    });
  });

  group('NearbyFriendsCanvas Widget Tests', () {
    testWidgets('Saat fitur disabled, menampilkan CTA Banner "Teman Sekitar" & tombol "Aktifkan"', (tester) async {
      final fakeRepo = FakeNearbyRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyRepositoryProvider.overrideWithValue(fakeRepo),
            nearbyFriendsProvider.overrideWith(
              (ref) => NearbyFriendsNotifier(
                fakeRepo,
                requestPermission: () async => true,
                getLocation: () async => (latitude: -6.2088, longitude: 106.8456),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NearbyFriendsCanvas(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Teman Sekitar'), findsOneWidget);
      expect(find.text('Aktifkan'), findsOneWidget);
    });

    testWidgets('Saat fitur enabled dan kosong, menampilkan empty state', (tester) async {
      final fakeRepo = FakeNearbyRepository();
      await fakeRepo.updatePreferences(enabled: true, visibilityMode: 'everyone');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyRepositoryProvider.overrideWithValue(fakeRepo),
            nearbyFriendsProvider.overrideWith(
              (ref) => NearbyFriendsNotifier(
                fakeRepo,
                requestPermission: () async => true,
                getLocation: () async => (latitude: -6.2088, longitude: 106.8456),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NearbyFriendsCanvas(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Teman Sekitar'), findsOneWidget);
      expect(find.text('Belum ada teman di sekitar'), findsOneWidget);
    });

    testWidgets('Saat fitur enabled dan ada teman, merender filter [Semua] & [Kontak] serta memfilter daftar', (tester) async {
      final fakeRepo = FakeNearbyRepository();
      await fakeRepo.updatePreferences(enabled: true, visibilityMode: 'everyone');
      fakeRepo.mockFriends = [
        const NearbyFriendModel(
          userId: 'friend-1',
          displayName: 'Alya Rahma',
          band: NearbyBand.veryClose,
          isRecent: true,
          isContact: true,
        ),
        const NearbyFriendModel(
          userId: 'friend-2',
          displayName: 'Dimas Seto',
          band: NearbyBand.close,
          isRecent: false, // offline < 1h
          isContact: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyRepositoryProvider.overrideWithValue(fakeRepo),
            nearbyFriendsProvider.overrideWith(
              (ref) => NearbyFriendsNotifier(
                fakeRepo,
                requestPermission: () async => true,
                getLocation: () async => (latitude: -6.2088, longitude: 106.8456),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NearbyFriendsCanvas(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Teman Sekitar'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Kontak'), findsOneWidget);

      // Mode 'Semua': Baik Alya maupun Dimas tampil
      expect(find.text('Alya Rahma'), findsOneWidget);
      expect(find.text('Dimas Seto'), findsOneWidget);

      // Tap filter [Kontak]
      await tester.tap(find.text('Kontak'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Mode 'Kontak': Hanya Alya yang tampil, Dimas (non-kontak) disaring
      expect(find.text('Alya Rahma'), findsOneWidget);
      expect(find.text('Dimas Seto'), findsNothing);

      // Tap filter [Semua] kembali
      await tester.tap(find.text('Semua'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Alya Rahma'), findsOneWidget);
      expect(find.text('Dimas Seto'), findsOneWidget);
    });

    testWidgets('Saat Private Vault terkunci, kontak dalam hiddenRoomIds disaring dari canvas', (tester) async {
      final fakeRepo = FakeNearbyRepository();
      await fakeRepo.updatePreferences(enabled: true, visibilityMode: 'everyone');
      fakeRepo.mockFriends = [
        const NearbyFriendModel(
          userId: 'friend-public',
          displayName: 'Teman Publik',
          band: NearbyBand.veryClose,
          isRecent: true,
          isContact: true,
        ),
        const NearbyFriendModel(
          userId: 'friend-vault',
          displayName: 'Teman Rahasia',
          band: NearbyBand.close,
          isRecent: true,
          isContact: true,
        ),
      ];

      final mockRooms = [
        {
          'id': 'room-normal',
          'otherUserId': 'friend-public',
          'name': 'Teman Publik',
        },
        {
          'id': 'room-vault-secret',
          'otherUserId': 'friend-vault',
          'name': 'Teman Rahasia',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyRepositoryProvider.overrideWithValue(fakeRepo),
            nearbyFriendsProvider.overrideWith(
              (ref) => NearbyFriendsNotifier(
                fakeRepo,
                requestPermission: () async => true,
                getLocation: () async => (latitude: -6.2088, longitude: 106.8456),
              ),
            ),
            chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier(mockRooms)),
            hiddenRoomIdsProvider.overrideWith((ref) => FakeHiddenRoomIdsNotifier({'room-vault-secret'})),
            privateVaultUnlockedProvider.overrideWith((ref) => false), // Vault terkunci
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NearbyFriendsCanvas(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Teman publik tampil
      expect(find.text('Teman Publik'), findsOneWidget);
      // Teman rahasia (vault terkunci) disaring demi privasi
      expect(find.text('Teman Rahasia'), findsNothing);
    });

    testWidgets('Saat Private Vault terbuka, kontak vault tampil di canvas dengan badge gembok', (tester) async {
      final fakeRepo = FakeNearbyRepository();
      await fakeRepo.updatePreferences(enabled: true, visibilityMode: 'everyone');
      fakeRepo.mockFriends = [
        const NearbyFriendModel(
          userId: 'friend-public',
          displayName: 'Teman Publik',
          band: NearbyBand.veryClose,
          isRecent: true,
          isContact: true,
        ),
        const NearbyFriendModel(
          userId: 'friend-vault',
          displayName: 'Teman Rahasia',
          band: NearbyBand.close,
          isRecent: true,
          isContact: true,
        ),
      ];

      final mockRooms = [
        {
          'id': 'room-normal',
          'otherUserId': 'friend-public',
          'name': 'Teman Publik',
        },
        {
          'id': 'room-vault-secret',
          'otherUserId': 'friend-vault',
          'name': 'Teman Rahasia',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyRepositoryProvider.overrideWithValue(fakeRepo),
            nearbyFriendsProvider.overrideWith(
              (ref) => NearbyFriendsNotifier(
                fakeRepo,
                requestPermission: () async => true,
                getLocation: () async => (latitude: -6.2088, longitude: 106.8456),
              ),
            ),
            chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier(mockRooms)),
            hiddenRoomIdsProvider.overrideWith((ref) => FakeHiddenRoomIdsNotifier({'room-vault-secret'})),
            privateVaultUnlockedProvider.overrideWith((ref) => true), // Vault terbuka
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NearbyFriendsCanvas(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Keduanya tampil
      expect(find.text('Teman Publik'), findsOneWidget);
      expect(find.text('Teman Rahasia'), findsOneWidget);

      // Menampilkan badge lock icon untuk kontak vault
      expect(find.byIcon(SolarIconsOutline.lock), findsOneWidget);
    });

    test('NearbyFriendsNotifier toggleSharing & setVisibilityMode merespons secara non-blocking', () async {
      final fakeRepo = FakeNearbyRepository();
      final notifier = NearbyFriendsNotifier(
        fakeRepo,
        requestPermission: () async => true,
        getLocation: () async => (latitude: -6.2088, longitude: 106.8456),
      );

      final success = await notifier.toggleSharing(true);
      expect(success, isTrue);
      expect(notifier.state.isEnabled, isTrue);

      await notifier.setVisibilityMode('everyone');
      expect(notifier.state.visibilityMode, 'everyone');

      await notifier.setVisibilityMode('contacts_only');
      expect(notifier.state.visibilityMode, 'contacts_only');
    });
  });
}
