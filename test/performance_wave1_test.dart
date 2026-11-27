import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/trip_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/trip_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/data/services/trip_monitor_service.dart';
import 'package:mekaar_chat/features/chat/controllers/chat_screen_controller.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/e2ee_room_status_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';

class _FakeTripRepository extends TripRepository {
  List<UserTrip> activeTrips;
  final List<(String, TripStatus)> statusUpdates = [];

  _FakeTripRepository(this.activeTrips) : super(SupabaseService());

  @override
  Future<List<UserTrip>> getActiveTripsForMonitoring() async => activeTrips;

  @override
  Future<void> updateTripStatus(
    String tripId,
    TripStatus status, {
    DateTime? snoozedUntil,
  }) async {
    statusUpdates.add((tripId, status));
  }
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(SupabaseService());
}

void main() {
  group('Wave 1A: Per-Room Provider autoDispose & Lifecycle Safety', () {
    test(
      'typingStateProvider otomatis ter-dispose saat subscription ditutup',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const roomId = 'room-autodispose-typing';
        final sub = container.listen(typingStateProvider(roomId), (_, _) {});
        expect(container.exists(typingStateProvider(roomId)), isTrue);

        sub.close();
        await Future<void>.delayed(Duration.zero);

        expect(container.exists(typingStateProvider(roomId)), isFalse);
      },
    );

    test(
      'e2eeRoomStatusProvider otomatis ter-dispose sebelum delay 350ms tanpa StateError',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const roomId = 'room-autodispose-e2ee';
        final sub = container.listen(
          e2eeRoomStatusProvider(roomId),
          (_, _) {},
        );
        expect(container.exists(e2eeRoomStatusProvider(roomId)), isTrue);

        sub.close();
        // Tunggu melewati dua Future.delayed(350ms) di initializeRoomSecurity
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(container.exists(e2eeRoomStatusProvider(roomId)), isFalse);
      },
    );
  });

  group('Wave 1B: ChatRepository.isMessagePersistenceEqual', () {
    final baseTime = DateTime.utc(2026, 11, 27, 10, 0, 0);
    final baseMsg = Message(
      id: 'msg-1',
      roomId: 'room-1',
      senderId: 'user-a',
      content: 'Halo dunia',
      type: MessageType.text,
      createdAt: baseTime,
      updatedAt: baseTime,
      reactions: const {
        '👍': ['user-b'],
      },
      isEncrypted: true,
    );

    test('mengembalikan true untuk pesan identik termasuk reaksi', () {
      final clone = baseMsg.copyWith(
        reactions: {
          '👍': ['user-b'],
        },
      );
      expect(
        ChatRepository.isMessagePersistenceEqual(baseMsg, clone),
        isTrue,
      );
    });

    test('mengembalikan false bila konten, reaksi, atau status berubah', () {
      expect(
        ChatRepository.isMessagePersistenceEqual(
          baseMsg,
          baseMsg.copyWith(content: 'Diubah'),
        ),
        isFalse,
      );
      expect(
        ChatRepository.isMessagePersistenceEqual(
          baseMsg,
          baseMsg.copyWith(isOpened: true),
        ),
        isFalse,
      );
      expect(
        ChatRepository.isMessagePersistenceEqual(
          baseMsg,
          baseMsg.copyWith(
            editedAt: DateTime.utc(2026, 11, 27, 10, 5, 0),
          ),
        ),
        isFalse,
      );
      expect(
        ChatRepository.isMessagePersistenceEqual(
          baseMsg,
          baseMsg.copyWith(
            autoDeleteAt: DateTime.utc(2026, 11, 27, 11, 0, 0),
          ),
        ),
        isFalse,
      );
      expect(
        ChatRepository.isMessagePersistenceEqual(
          baseMsg,
          baseMsg.copyWith(
            reactions: {
              '👍': ['user-b', 'user-c'],
            },
          ),
        ),
        isFalse,
      );
    });
  });

  group('Wave 1C: TripMonitorService Lazy GPS Gate', () {
    test('tidak memanggil fetchCurrentLocation ketika 0 trip aktif', () async {
      final tripRepo = _FakeTripRepository([]);
      final chatRepo = _FakeChatRepository();
      int gpsCalls = 0;

      await TripMonitorService.evaluate(
        tripRepository: tripRepo,
        chatRepository: chatRepo,
        fetchCurrentLocation: () async {
          gpsCalls++;
          return (lat: -6.2, lng: 106.8);
        },
      );

      expect(gpsCalls, equals(0));
    });

    test(
      'tidak memanggil fetchCurrentLocation ketika seluruh trip sudah selesai hari ini',
      () async {
        final nowLocal = DateTime.now();
        final todayDate = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
        final tripRepo = _FakeTripRepository([
          UserTrip(
            id: 'trip-done',
            userId: 'user-1',
            title: 'Kantor',
            destinationZone: const TripZone(
              label: 'Kantor',
              latitude: -6.2,
              longitude: 106.8,
            ),
            createdAt: DateTime.utc(2026, 11, 20),
            status: TripStatus.arrivedConfirmed,
            activeDate: todayDate,
          ),
          UserTrip(
            id: 'trip-snoozed',
            userId: 'user-1',
            title: 'Rumah',
            destinationZone: const TripZone(
              label: 'Rumah',
              latitude: -6.3,
              longitude: 106.9,
            ),
            createdAt: DateTime.utc(2026, 11, 20),
            status: TripStatus.snoozed,
            activeDate: todayDate,
            snoozedUntil: nowLocal.add(const Duration(minutes: 20)),
          ),
        ]);
        final chatRepo = _FakeChatRepository();
        int gpsCalls = 0;

        await TripMonitorService.evaluate(
          tripRepository: tripRepo,
          chatRepository: chatRepo,
          fetchCurrentLocation: () async {
            gpsCalls++;
            return (lat: -6.2, lng: 106.8);
          },
        );

        expect(gpsCalls, equals(0));
      },
    );

    test(
      'memanggil fetchCurrentLocation tepat 1 kali ketika ada trip aktif',
      () async {
        final tripRepo = _FakeTripRepository([
          UserTrip(
            id: 'trip-active',
            userId: 'user-1',
            title: 'Kampus',
            destinationZone: const TripZone(
              label: 'Kampus',
              latitude: -6.2000,
              longitude: 106.8000,
              radiusMeters: 200,
            ),
            createdAt: DateTime.utc(2026, 11, 20),
            status: TripStatus.scheduled,
          ),
        ]);
        final chatRepo = _FakeChatRepository();
        int gpsCalls = 0;

        await TripMonitorService.evaluate(
          tripRepository: tripRepo,
          chatRepository: chatRepo,
          fetchCurrentLocation: () async {
            gpsCalls++;
            return (lat: -6.2000, lng: 106.8000);
          },
        );

        expect(gpsCalls, equals(1));
        expect(tripRepo.statusUpdates, hasLength(1));
        expect(tripRepo.statusUpdates.first.$2, equals(TripStatus.arrivedAuto));
      },
    );
  });

  group('Wave 1C: SOSNotifier Location Ping Throttle', () {
    test('mengizinkan ping pertama, menahan spam <5s & <10m, lolos saat >=5s atau >=10m', () {
      final t0 = DateTime.utc(2026, 11, 27, 8, 0, 0);

      // 1. Ping pertama (belum ada riwayat) -> true
      expect(
        SOSNotifier.shouldSendSosLocationPing(
          lastSentAtUtc: null,
          lastLat: null,
          lastLng: null,
          nowUtc: t0,
          lat: -6.200000,
          lng: 106.800000,
        ),
        isTrue,
      );

      // 2. 2 detik kemudian di posisi nyaris sama (~2 meter) -> false (di-drop)
      expect(
        SOSNotifier.shouldSendSosLocationPing(
          lastSentAtUtc: t0,
          lastLat: -6.200000,
          lastLng: 106.800000,
          nowUtc: t0.add(const Duration(seconds: 2)),
          lat: -6.200015,
          lng: 106.800000,
        ),
        isFalse,
      );

      // 3. >= 5 detik di posisi sama -> true
      expect(
        SOSNotifier.shouldSendSosLocationPing(
          lastSentAtUtc: t0,
          lastLat: -6.200000,
          lastLng: 106.800000,
          nowUtc: t0.add(const Duration(seconds: 5)),
          lat: -6.200000,
          lng: 106.800000,
        ),
        isTrue,
      );

      // 4. Baru 1 detik tetapi berpindah >= 10 meter (~22 meter) -> true
      expect(
        SOSNotifier.shouldSendSosLocationPing(
          lastSentAtUtc: t0,
          lastLat: -6.200000,
          lastLng: 106.800000,
          nowUtc: t0.add(const Duration(seconds: 1)),
          lat: -6.200200,
          lng: 106.800000,
        ),
        isTrue,
      );
    });
  });

  group('Wave 1C: ChatScreenController Purge Gate & Lifecycle Pause/Resume', () {
    testWidgets(
      'shouldRunPurgeTimer false untuk room normal dan pause/resume lifecycle aman',
      (tester) async {
        late ChatScreenController controller;
        final focusNode = FocusNode();
        final lastSeenNotifier = ValueNotifier<DateTime?>(null);
        bool hasExpiring = false;
        addTearDown(() {
          controller.dispose();
          focusNode.dispose();
          lastSeenNotifier.dispose();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  controller = ChatScreenController(
                    chatId: 'room_welcome_mekaar',
                    ref: ref,
                    composerFocusNode: focusNode,
                    isKeyboardVisible: () => false,
                    isMounted: () => true,
                    hasExpiringMessages: () => hasExpiring,
                    otherLastSeenNotifier: lastSeenNotifier,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(controller.shouldRunPurgeTimer, isFalse);

        // Aktifkan pesan expiring -> shouldRunPurgeTimer jadi true
        hasExpiring = true;
        expect(controller.shouldRunPurgeTimer, isTrue);
        controller.syncPurgeTimerState();

        // Pause dan resume lifecycle
        controller.pauseBackgroundTimers();
        expect(controller.isPaused, isTrue);

        controller.resumeBackgroundTimers();
        expect(controller.isPaused, isFalse);

        // Nonaktifkan expiring dan aktifkan scheduled wipe
        hasExpiring = false;
        controller.testSetScheduledWipe(
          mode: 'daily',
          targetAt: DateTime.utc(2026, 11, 28, 0, 0),
        );
        expect(controller.shouldRunPurgeTimer, isTrue);
      },
    );
  });
}
