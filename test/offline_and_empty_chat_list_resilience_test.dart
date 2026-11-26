import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/error_resolver.dart';
import 'package:mekaar_chat/data/models/blocked_user_model.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/chat_list_screen.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/settings/providers/block_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

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

class _ErrorChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  _ErrorChatRoomsNotifier(Object error)
      : super(AsyncValue.error(error, StackTrace.empty));

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
    bool isCurrentlyInRoom = false,
    bool isSending = false,
  }) {}

  @override
  void updateOtherLastReadLocally(String roomId, DateTime readAt) {}
}

class _ErrorContactsNotifier
    extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  _ErrorContactsNotifier(Object error)
      : super(AsyncValue.error(error, StackTrace.empty));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ErrorBlockNotifier
    extends StateNotifier<AsyncValue<List<BlockedUser>>>
    implements BlockNotifier {
  _ErrorBlockNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHiddenRoomIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenRoomIdsNotifier {
  _StubHiddenRoomIdsNotifier(super.ids);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHiddenContactUserIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenContactUserIdsNotifier {
  _StubHiddenContactUserIdsNotifier(super.ids);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      expect(
        ErrorResolver.isRealtimeError(null),
        isFalse,
      );
    });
  });

  group('Resilience: Anti-Grey-Screen AsyncError Regression Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'cloakedContactUserIdsProvider dan cloakedRoomIdsProvider tidak melempar exception saat chatRoomsProvider & userContactsProvider berstatus AsyncError',
      () {
        const err = SocketException('Network unreachable');
        final container = ProviderContainer(
          overrides: [
            chatRoomsProvider.overrideWith((ref) => _ErrorChatRoomsNotifier(err)),
            userContactsProvider.overrideWith((ref) => _ErrorContactsNotifier(err)),
            hiddenRoomIdsProvider.overrideWith(
              (ref) => _StubHiddenRoomIdsNotifier(<String>{}),
            ),
            hiddenContactUserIdsProvider.overrideWith(
              (ref) => _StubHiddenContactUserIdsNotifier(<String>{}),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(cloakedContactUserIdsProvider), isEmpty);
        expect(container.read(cloakedRoomIdsProvider), isEmpty);
      },
    );

    testWidgets(
      'ChatListScreen merender UI error ramah (bukan grey screen) saat chatRoomsProvider & userContactsProvider berstatus AsyncError',
      (WidgetTester tester) async {
        const err = SocketException('Network unreachable');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(
                _ResilienceStubChatRepository(),
              ),
              chatRoomsProvider.overrideWith(
                (ref) => _ErrorChatRoomsNotifier(err),
              ),
              userContactsProvider.overrideWith(
                (ref) => _ErrorContactsNotifier(err),
              ),
              sosFeatureEnabledProvider.overrideWith(
                (ref) => SOSFeatureEnabledNotifier(null, false),
              ),
              authProvider.overrideWith((ref) {
                final authRepo = ref.watch(authRepositoryProvider);
                final notifier = AuthNotifier(authRepo);
                notifier.state = AuthState(
                  isPinSet: true,
                  unlockMode: AuthUnlockMode.master,
                );
                return notifier;
              }),
              hiddenRoomIdsProvider.overrideWith(
                (ref) => _StubHiddenRoomIdsNotifier(<String>{}),
              ),
              hiddenContactUserIdsProvider.overrideWith(
                (ref) => _StubHiddenContactUserIdsNotifier(<String>{}),
              ),
              blockProvider.overrideWith((ref) => _ErrorBlockNotifier()),
              hasPendingIncomingGuardiansProvider.overrideWithValue(false),
            ],
            child: const MaterialApp(home: ChatListScreen()),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Gagal Memuat Chat'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);

        // Habiskan timer 1.5s _checkForAppUpdate() pada initState ChatListScreen
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });

  group('Resilience: ChatRepository.shouldFallbackToLegacyGetRooms', () {
    test('PostgrestException dari get_user_inbox selalu fallback ke legacy, sedangkan network/auth tidak', () {
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const PostgrestException(message: 'function does not exist', code: '42883'),
        ),
        isTrue,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const PostgrestException(message: 'Could not find the function', code: 'PGRST202'),
        ),
        isTrue,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const PostgrestException(message: 'column encryption_version does not exist', code: '42703'),
        ),
        isTrue,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const PostgrestException(message: 'permission denied', code: '42501'),
        ),
        isTrue,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const PostgrestException(message: 'relation does not exist', code: '42P01'),
        ),
        isTrue,
      );

      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const SocketException('Network unreachable'),
        ),
        isFalse,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          TimeoutException('Request timed out'),
        ),
        isFalse,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          'RealtimeSubscribeException(timedOut)',
        ),
        isFalse,
      );
      expect(
        ChatRepository.shouldFallbackToLegacyGetRooms(
          const AuthException('Sesi belum siap'),
        ),
        isFalse,
      );
    });
  });
}
