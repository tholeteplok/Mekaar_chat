import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/mekaar_dialog.dart';
import 'package:mekaar_chat/features/chat/widgets/nearby_friends_canvas.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/data/repositories/nearby_repository.dart';
import 'package:mekaar_chat/data/models/nearby_friend_model.dart';
import 'package:mekaar_chat/data/services/location_service.dart';

class FakeNearbyRepository implements NearbyRepository {
  NearbyPreferences _prefs = const NearbyPreferences(enabled: false);

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
    return [];
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
  }) async =>
      'mock-room-id';
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

  group('MekaarDialog.showLocationPermissionRequiredDialog Tests', () {
    testWidgets(
      'Menampilkan dialog izin lokasi diperlukan dengan judul, deskripsi, dan tombol aksi',
      (tester) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result =
                          await MekaarDialog.showLocationPermissionRequiredDialog(
                        context: context,
                      );
                    },
                    child: const Text('Buka Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        // Verifikasi dialog muncul dengan konten yang tepat
        expect(find.text('Izin Lokasi Diperlukan'), findsOneWidget);
        expect(
          find.textContaining('Fitur Teman Sekitar membutuhkan akses lokasi'),
          findsOneWidget,
        );
        expect(find.text('Nanti Saja'), findsOneWidget);
        expect(find.text('Buka Pengaturan'), findsOneWidget);

        // Uji tombol "Nanti Saja" mengembalikan false
        await tester.tap(find.text('Nanti Saja'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
      },
    );

    testWidgets(
      'Menekan tombol "Buka Pengaturan" mengembalikan nilai true',
      (tester) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      result =
                          await MekaarDialog.showLocationPermissionRequiredDialog(
                        context: context,
                      );
                    },
                    child: const Text('Buka Dialog'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buka Pengaturan'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      },
    );
  });

  group('LocationService GPS Service Helper Tests', () {
    test('isServiceEnabled dan requestService dapat dipanggil tanpa melempar exception', () async {
      // Mock / fallback check
      expect(() async => await LocationService.isServiceEnabled(), returnsNormally);
      expect(() async => await LocationService.requestService(), returnsNormally);
    });
  });

  group('NearbyFriendsCanvas Integration Tests', () {
    testWidgets(
      'NearbyFriendsCanvas menerima onSettingsOpened callback dan merender TeaserCard saat disabled',
      (tester) async {
        final fakeRepo = FakeNearbyRepository();
        var settingsOpenedCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nearbyRepositoryProvider.overrideWithValue(fakeRepo),
              chatRoomsProvider.overrideWith(
                (ref) => FakeChatRoomsNotifier([]),
              ),
              hiddenRoomIdsProvider.overrideWith(
                (ref) => FakeHiddenRoomIdsNotifier({}),
              ),
              privateVaultUnlockedProvider.overrideWith((ref) => false),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: NearbyFriendsCanvas(
                  collapseProgress: 0.0,
                  onSettingsOpened: () {
                    settingsOpenedCalled = true;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Kartu teaser harus muncul dengan tombol Aktifkan
        expect(find.text('Aktifkan'), findsOneWidget);
        expect(find.text('Teman Sekitar'), findsOneWidget);
        expect(settingsOpenedCalled, isFalse);
      },
    );
  });
}
