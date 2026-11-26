import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/error_resolver.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';

class _ResilienceStubChatRepository extends ChatRepository {
  List<Map<String, dynamic>> cachedRooms = [];
  List<Map<String, dynamic>> remoteRooms = [];
  Object? remoteError;
  Duration remoteDelay = Duration.zero;
  int getRoomsCallCount = 0;

  _ResilienceStubChatRepository() : super(SupabaseService());

  @override
  String? get currentUserId => 'user_me';

  @override
  Future<List<Map<String, dynamic>>> getCachedRooms() async => cachedRooms;

  @override
  Future<List<Map<String, dynamic>>> getRooms() async {
    getRoomsCallCount++;
    if (remoteDelay > Duration.zero) {
      await Future<void>.delayed(remoteDelay);
    }
    if (remoteError != null) {
      throw remoteError!;
    }
    return remoteRooms;
  }
}

void main() {
  group('Resilience: ChatRoomsNotifier Empty State & Deduplication', () {
    test(
      'reloadFromLocalCache dengan cache kosong pada mode Master TIDAK menimpa state dengan AsyncData([]) dan memunculkan AsyncError jika remote gagal',
      () async {
        final repo = _ResilienceStubChatRepository()
          ..cachedRooms = []
          ..remoteDelay = const Duration(milliseconds: 20)
          ..remoteError = const SocketException('Network unreachable');

        final notifier = ChatRoomsNotifier(repo);
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // Panggil reloadFromLocalCache ketika cache kosong
        await notifier.reloadFromLocalCache(syncRemoteInBackground: true);

        // Tidak boleh menjadi AsyncData([]) palsu saat masih loading
        expect(notifier.state.isLoading, isTrue);
        expect(notifier.state.hasValue, isFalse);

        // Tunggu remote gagal -> harus masuk ke AsyncError, bukan terjebak Empty State
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(notifier.state.hasError, isTrue);
        expect(notifier.state.hasValue, isFalse);

        notifier.dispose();
      },
    );

    test(
      'reloadFromLocalCache dengan cache kosong TIDAK menghapus daftar room yang sudah ada di memori saat sinkronisasi berjalan',
      () async {
        final existingRooms = [
          {
            'id': 'room_1',
            'name': 'Budi',
            'timestamp': DateTime.utc(2026, 11, 26, 10, 0, 0),
          },
        ];
        final repo = _ResilienceStubChatRepository()
          ..cachedRooms = existingRooms
          ..remoteRooms = existingRooms;

        final notifier = ChatRoomsNotifier(repo);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(notifier.state.value, hasLength(1));

        // Simulasikan cache disk kosong namun memori sudah punya data valid & remote gagal
        repo.cachedRooms = [];
        repo.remoteError = const SocketException('Timeout');

        await notifier.reloadFromLocalCache(syncRemoteInBackground: true);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(notifier.state.hasValue, isTrue);
        expect(notifier.state.value, hasLength(1));
        expect(notifier.state.value!.first['id'], 'room_1');

        notifier.dispose();
      },
    );

    test(
      'reloadFromLocalCache dengan syncRemoteInBackground=false (Decoy) langsung memuat cache termasuk [] tanpa menyentuh remote',
      () async {
        final repo = _ResilienceStubChatRepository()
          ..cachedRooms = [
            {
              'id': 'room_decoy',
              'name': 'Mekaar Official',
              'timestamp': DateTime.utc(2026, 11, 26, 10, 0, 0),
            },
          ];

        final notifier = ChatRoomsNotifier(repo);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        repo.getRoomsCallCount = 0;

        repo.cachedRooms = [];
        await notifier.reloadFromLocalCache(syncRemoteInBackground: false);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(notifier.state.hasValue, isTrue);
        expect(notifier.state.value, isEmpty);
        expect(repo.getRoomsCallCount, 0);

        notifier.dispose();
      },
    );

    test(
      'refreshRooms melakukan deduplikasi panggilan in-flight yang terjadi bersamaan',
      () async {
        final repo = _ResilienceStubChatRepository()
          ..cachedRooms = [
            {
              'id': 'room_1',
              'name': 'Ani',
              'timestamp': DateTime.utc(2026, 11, 26, 10, 0, 0),
            },
          ]
          ..remoteDelay = const Duration(milliseconds: 30)
          ..remoteRooms = [
            {
              'id': 'room_1',
              'name': 'Ani',
              'timestamp': DateTime.utc(2026, 11, 26, 10, 1, 0),
            },
          ];

        final notifier = ChatRoomsNotifier(repo);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        repo.getRoomsCallCount = 0;

        // 3 panggilan refreshRooms bersamaan -> cukup 1 eksekusi getRooms()
        await Future.wait([
          notifier.refreshRooms(forceLoading: false),
          notifier.refreshRooms(forceLoading: false),
          notifier.refreshRooms(forceLoading: false),
        ]);

        expect(repo.getRoomsCallCount, 1);

        notifier.dispose();
      },
    );
  });

  group('Resilience: ErrorResolver.isRealtimeError', () {
    test('membedakan error Realtime WebSocket dari error jaringan murni', () {
      expect(
        ErrorResolver.isRealtimeError('RealtimeSubscribeException(timedOut)'),
        isTrue,
      );
      expect(
        ErrorResolver.isRealtimeError('Realtime channel error'),
        isTrue,
      );
      expect(
        ErrorResolver.isNetworkError('RealtimeSubscribeException(timedOut)'),
        isTrue,
      );

      expect(
        ErrorResolver.isRealtimeError(const SocketException('No route to host')),
        isFalse,
      );
      expect(
        ErrorResolver.isRealtimeError(TimeoutException('HTTP timeout')),
        isFalse,
      );
      expect(ErrorResolver.isRealtimeError(null), isFalse);
    });
  });
}
