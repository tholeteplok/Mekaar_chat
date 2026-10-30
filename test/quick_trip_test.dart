import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/saved_place_model.dart';
import 'package:mekaar_chat/data/models/trip_model.dart';
import 'package:mekaar_chat/data/repositories/saved_places_repository.dart';
import 'package:mekaar_chat/data/repositories/trip_repository.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/guardian/widgets/active_trip_card.dart';
import 'package:mekaar_chat/features/guardian/widgets/quick_trip_sheet.dart';
import 'package:mekaar_chat/features/settings/providers/trip_provider.dart';

class FakeTripRepository extends Fake implements TripRepository {
  final List<UserTrip> trips;
  bool createTripCalled = false;
  Map<String, dynamic>? lastCreatedTripParams;
  String? confirmedTripId;
  String? snoozedTripId;
  int? snoozedMinutes;

  FakeTripRepository({List<UserTrip>? initialTrips})
    : trips = initialTrips ?? [];

  @override
  Future<List<UserTrip>> getUserTrips() async => trips;

  @override
  Future<UserTrip> createTrip({
    required String title,
    String? originLabel,
    required TripZone destinationZone,
    String? expectedTime,
    int gracePeriodMinutes = 30,
    required List<TripGuardianPermission> guardians,
    List<int> recurrenceDays = const [],
    List<int>? activeDays,
  }) async {
    createTripCalled = true;
    lastCreatedTripParams = {
      'title': title,
      'originLabel': originLabel,
      'destinationZone': destinationZone,
      'expectedTime': expectedTime,
      'gracePeriodMinutes': gracePeriodMinutes,
      'guardians': guardians,
      'recurrenceDays': recurrenceDays,
    };

    final newTrip = UserTrip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user-1',
      title: title,
      originLabel: originLabel,
      destinationZone: destinationZone,
      expectedTime: expectedTime,
      gracePeriodMinutes: gracePeriodMinutes,
      guardians: guardians,
      recurrenceDays: recurrenceDays,
      createdAt: DateTime.now(),
      status: TripStatus.scheduled,
      isActive: true,
      activeDate: DateTime.now(),
    );
    trips.insert(0, newTrip);
    return newTrip;
  }

  @override
  Future<void> confirmArrivalManually(String tripId) async {
    confirmedTripId = tripId;
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final old = trips[index];
      trips[index] = UserTrip(
        id: old.id,
        userId: old.userId,
        title: old.title,
        destinationZone: old.destinationZone,
        expectedTime: old.expectedTime,
        gracePeriodMinutes: old.gracePeriodMinutes,
        guardians: old.guardians,
        recurrenceDays: old.recurrenceDays,
        createdAt: old.createdAt,
        status: TripStatus.arrivedConfirmed,
        isActive: old.isActive,
        activeDate: DateTime.now(),
      );
    }
  }

  @override
  Future<void> snoozeTrip(String tripId, int minutes) async {
    snoozedTripId = tripId;
    snoozedMinutes = minutes;
    final index = trips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final old = trips[index];
      trips[index] = UserTrip(
        id: old.id,
        userId: old.userId,
        title: old.title,
        destinationZone: old.destinationZone,
        expectedTime: old.expectedTime,
        gracePeriodMinutes: old.gracePeriodMinutes,
        guardians: old.guardians,
        recurrenceDays: old.recurrenceDays,
        createdAt: old.createdAt,
        status: TripStatus.snoozed,
        isActive: old.isActive,
        activeDate: DateTime.now(),
        snoozedUntil: DateTime.now().add(Duration(minutes: minutes)),
      );
    }
  }
}

class FakeSavedPlacesRepository extends Fake implements SavedPlacesRepository {
  final Map<String, SavedPlace> places;
  FakeSavedPlacesRepository({Map<String, SavedPlace>? initialPlaces})
    : places = initialPlaces ?? {};

  @override
  Future<Map<String, SavedPlace>> getSavedPlaces() async => places;
}

class FakeGuardiansNotifier extends StateNotifier<List<Guardian>>
    implements GuardiansNotifier {
  FakeGuardiansNotifier(super.state);

  @override
  Future<void> refreshGuardians() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UX-14 Unit: Logika Perhitungan Waktu & Lintas Tengah Malam', () {
    test('Perhitungan ETA menghasilkan format HH:mm yang tepat', () {
      final base = DateTime(2026, 10, 30, 14, 0);
      final eta30 = base.add(const Duration(minutes: 30));
      expect(DateFormat('HH:mm').format(eta30), '14:30');

      final eta45 = base.add(const Duration(minutes: 45));
      expect(DateFormat('HH:mm').format(eta45), '14:45');
    });

    test(
      'Lintas tengah malam (23:45 + 30m) menyertakan hari esok pada recurrenceDays',
      () {
        final departure = DateTime(2026, 10, 30, 23, 45); // Friday (5)
        final arrival = departure.add(
          const Duration(minutes: 30),
        ); // Saturday (6)

        final nowDay = departure.weekday;
        final arrivalDay = arrival.weekday;
        final recurrenceDays = (nowDay == arrivalDay)
            ? <int>[nowDay]
            : <int>[nowDay, arrivalDay];

        expect(recurrenceDays, contains(5));
        expect(recurrenceDays, contains(6));
        expect(recurrenceDays.length, 2);
      },
    );

    test(
      'activeTripTodayProvider mengabaikan trip yang sudah selesai tiba',
      () {
        final now = DateTime.now();
        final finishedTrip = UserTrip(
          id: 'trip-1',
          userId: 'u-1',
          title: 'Perjalanan Selesai',
          destinationZone: const TripZone(
            label: 'Rumah',
            latitude: -6.2,
            longitude: 106.8,
          ),
          createdAt: now,
          status: TripStatus.arrivedConfirmed,
          activeDate: now,
          isActive: true,
        );

        final container = ProviderContainer(
          overrides: [
            userTripsProvider.overrideWith((ref) => [finishedTrip]),
          ],
        );
        addTearDown(container.dispose);

        // Provider harus menghasilkan null karena status sudah arrivedConfirmed
        final activeTrip = container.read(activeTripTodayProvider);
        expect(activeTrip, isNull);
        expect(finishedTrip.effectiveStatus, TripStatus.arrivedConfirmed);
      },
    );
  });

  group('UX-14 Widget: QuickTripSheet', () {
    testWidgets(
      'Merender pilihan tempat dan guardian lengkap dengan chip ETA',
      (tester) async {
        final fakeRepo = FakeTripRepository();
        final samplePlaces = {
          'home': SavedPlace(
            id: 'home',
            name: 'Rumah',
            iconName: 'home',
            latitude: -6.2,
            longitude: 106.8,
            address: 'Jl. Merdeka No. 10',
            updatedAt: DateTime.now(),
          ),
          'office': SavedPlace(
            id: 'office',
            name: 'Kantor',
            iconName: 'building',
            latitude: -6.19,
            longitude: 106.82,
            address: 'Gedung Wisma 46',
            updatedAt: DateTime.now(),
          ),
        };

        final sampleGuardian = Guardian(
          id: 'g-1',
          ownerId: 'u-1',
          guardianId: 'u-guardian-1',
          name: 'Siti Rahma',
          email: 'siti@example.com',
          permissions: {'gps': true},
          storageOption: 'cloud',
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(fakeRepo),
              userTripsProvider.overrideWith((ref) => []),
              savedPlacesProvider.overrideWith((ref) => samplePlaces),
              guardianProvider.overrideWith(
                (ref) => FakeGuardiansNotifier([sampleGuardian]),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: QuickTripSheet())),
          ),
        );

        await tester.pumpAndSettle();

        // Memastikan elemen utama hadir
        expect(find.text('PILIH TEMPAT TUJUAN'), findsOneWidget);
        expect(find.text('Rumah'), findsOneWidget);
        expect(find.text('Kantor'), findsOneWidget);
        expect(find.text('PERKIRAAN TIBA (ETA)'), findsOneWidget);
        expect(find.text('15 mnt'), findsOneWidget);
        expect(find.text('30 mnt'), findsOneWidget);
        expect(find.text('45 mnt'), findsOneWidget);
        expect(find.text('60 mnt'), findsOneWidget);
        expect(find.text('Siti Rahma'), findsOneWidget);
        expect(find.text('Mulai Perjalanan Sekarang'), findsOneWidget);

        // Memilih chip ETA 45 mnt
        await tester.tap(find.text('45 mnt'));
        await tester.pumpAndSettle();

        // Menekan Mulai Perjalanan
        await tester.tap(find.text('Mulai Perjalanan Sekarang'));
        await tester.pumpAndSettle();

        expect(fakeRepo.createTripCalled, isTrue);
        expect(fakeRepo.lastCreatedTripParams?['title'], 'Perjalanan ke Rumah');
        expect(
          fakeRepo.lastCreatedTripParams?['destinationZone']?.label,
          'Rumah',
        );
      },
    );

    testWidgets(
      'Menampilkan empty state tempat tersimpan jika daftar tempat kosong',
      (tester) async {
        final fakeRepo = FakeTripRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(fakeRepo),
              userTripsProvider.overrideWith((ref) => []),
              savedPlacesProvider.overrideWith((ref) => {}),
              guardianProvider.overrideWith((ref) => FakeGuardiansNotifier([])),
            ],
            child: const MaterialApp(home: Scaffold(body: QuickTripSheet())),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Belum ada Tempat Tersimpan'), findsOneWidget);
        expect(find.text('Buat Rute / Atur Tujuan'), findsOneWidget);
        expect(find.text('Belum Ada Guardian'), findsOneWidget);
        expect(find.text('Tambah Guardian'), findsOneWidget);
      },
    );

    testWidgets(
      'Menampilkan pemberitahuan jika sudah ada trip aktif hari ini',
      (tester) async {
        final now = DateTime.now();
        final activeTrip = UserTrip(
          id: 'trip-active-1',
          userId: 'u-1',
          title: 'Perjalanan Pulang Malam',
          destinationZone: const TripZone(
            label: 'Rumah',
            latitude: -6.2,
            longitude: 106.8,
          ),
          expectedTime: '22:30',
          createdAt: now,
          status: TripStatus.scheduled,
          activeDate: now,
          isActive: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userTripsProvider.overrideWith((ref) => [activeTrip]),
            ],
            child: const MaterialApp(home: Scaffold(body: QuickTripSheet())),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Perjalanan sedang berjalan: Perjalanan Pulang Malam',
          ),
          findsOneWidget,
        );
        expect(find.text('Tutup'), findsOneWidget);
      },
    );
  });

  group('UX-14 Widget: ActiveTripCard', () {
    testWidgets('Merender SizedBox.shrink saat tidak ada trip aktif', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [userTripsProvider.overrideWith((ref) => [])],
          child: const MaterialApp(home: Scaffold(body: ActiveTripCard())),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Aku Sudah Sampai'), findsNothing);
      expect(find.text('+15 mnt'), findsNothing);
    });

    testWidgets(
      'Merender kartu dengan tombol Aku Sudah Sampai & +15 mnt saat ada trip aktif',
      (tester) async {
        final now = DateTime.now();
        final activeTrip = UserTrip(
          id: 'trip-current',
          userId: 'u-1',
          title: 'Perjalanan ke Rumah',
          destinationZone: const TripZone(
            label: 'Rumah',
            latitude: -6.2,
            longitude: 106.8,
          ),
          expectedTime: '21:30',
          createdAt: now,
          status: TripStatus.scheduled,
          activeDate: now,
          isActive: true,
        );

        final fakeRepo = FakeTripRepository(initialTrips: [activeTrip]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tripRepositoryProvider.overrideWithValue(fakeRepo),
              userTripsProvider.overrideWith((ref) => [activeTrip]),
            ],
            child: const MaterialApp(home: Scaffold(body: ActiveTripCard())),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Perjalanan ke Rumah'), findsOneWidget);
        expect(find.textContaining('Tujuan: Rumah'), findsOneWidget);
        expect(find.text('Sedang Berjalan'), findsOneWidget);
        expect(find.text('Aku Sudah Sampai'), findsOneWidget);
        expect(find.text('+15 mnt'), findsOneWidget);

        // Tekan tombol +15 mnt
        await tester.tap(find.text('+15 mnt'));
        await tester.pumpAndSettle();

        expect(fakeRepo.snoozedTripId, 'trip-current');
        expect(fakeRepo.snoozedMinutes, 15);

        // Tekan tombol Aku Sudah Sampai
        await tester.tap(find.text('Aku Sudah Sampai'));
        await tester.pumpAndSettle();

        expect(fakeRepo.confirmedTripId, 'trip-current');
      },
    );
  });
}
