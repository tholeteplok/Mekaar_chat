import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mekaar_chat/core/providers/time_tick_provider.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/models/chat_theme_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/call_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/screen_protection_repository.dart';
import 'package:mekaar_chat/data/repositories/forwarding_protection_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/e2ee_room_status_provider.dart';
import 'package:mekaar_chat/features/chat/providers/forwarding_protection_provider.dart';
import 'package:mekaar_chat/features/chat/providers/screen_protection_provider.dart';
import 'package:mekaar_chat/features/chat/screens/chat_screen.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_app_bar.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_bottom_area.dart';
import 'package:mekaar_chat/features/settings/providers/chat_theme_provider.dart';

class FakeAuthRepository extends Fake implements AuthRepository {}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier() : super(FakeAuthRepository()) {
    state = AuthState(
      profile: Profile(
        id: 'user_me',
        username: 'pengguna_test',
        fullName: 'Pengguna Test',
        displayName: 'Pengguna',
        email: 'test@example.com',
        pinHash: 'test_pin_hash',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      isPinSet: true,
      unlockMode: AuthUnlockMode.master,
    );
  }
}

class FakeChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  FakeChatRoomsNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChatActionsNotifier extends Fake implements ChatActionsNotifier {
  @override
  Future<void> markRoomRead(String roomId) async {}

  @override
  Future<void> stopLiveLocationShare() async {}

  @override
  bool canEdit(Message message, {required bool isGuardianRoom}) => true;

  @override
  bool canForward(Message message, {bool forwardingProtectionActive = false}) =>
      true;
}

class FakeCallRepository extends Fake implements CallRepository {
  @override
  Future<void> hideCalls(Set<String> callIds) async {}
}

class FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<Map<String, dynamic>>> getRooms() async => [];

  @override
  Future<List<Map<String, dynamic>>> getCachedRooms() async => [];

  @override
  Future<int> getRoomDisappearingHours(String roomId) async => 0;

  @override
  Future<bool> getRoomBurnOnExit(String roomId) async => false;

  @override
  Future<Map<String, dynamic>?> getRoomScheduledWipe(String roomId) async =>
      null;

  @override
  Future<void> updateLastSeen() async {}

  @override
  Future<DateTime?> getLastSeen(String userId) async => null;

  @override
  Future<DateTime?> getOtherParticipantLastRead(String roomId) async => null;

  @override
  Future<DateTime?> getMyLastRead(String roomId) async => null;

  @override
  Future<int> purgeExpiredMessages({String? targetRoomId}) async => 0;

  @override
  Future<void> markRoomRead(String roomId) async {}

  @override
  bool canForwardMessage(
    Message message, {
    bool forwardingProtectionActive = false,
  }) => true;

  @override
  bool canEditMessage(
    Message message, {
    required bool isGuardianRoom,
    DateTime? now,
  }) => true;

  @override
  String? getEditRestrictionReason(
    Message message, {
    required bool isGuardianRoom,
    DateTime? now,
  }) => null;

  @override
  Future<Message> sendMessage(
    String roomId,
    String content, {
    String? mediaUrl,
    MessageType type = MessageType.text,
    bool isViewOnce = false,
    String? replyToId,
    DateTime? autoDeleteAt,
    bool isGroup = false,
  }) async {
    return Message(
      id: 'sent_msg_smoke',
      roomId: roomId,
      senderId: 'user_me',
      content: content,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class _FakeChatThemeNotifier extends ChatThemeNotifier {
  _FakeChatThemeNotifier() {
    state = const AsyncValue.data(ChatThemePreference());
  }
}

class FakeE2eeRoomStatusNotifier extends E2eeRoomStatusNotifier {
  FakeE2eeRoomStatusNotifier(super.roomId) {
    state = E2eeRoomStatus.ready;
  }

  @override
  Future<void> initializeRoomSecurity({bool isGroup = false}) async {
    state = isGroup
        ? E2eeRoomStatus.groupServerEncrypted
        : E2eeRoomStatus.ready;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testRoomId = 'room_smoke_1';
  final now = DateTime.now().toUtc();

  final initialMessages = [
    Message(
      id: 'msg_initial_1',
      roomId: testRoomId,
      senderId: 'user_other_1',
      content: 'Halo dari rekan chat',
      type: MessageType.text,
      createdAt: now.subtract(const Duration(minutes: 5)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
    ),
  ];

  Widget buildSmokeHarness({required Widget child, List<Message>? messages}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier()),
        chatActionsProvider.overrideWithValue(FakeChatActionsNotifier()),
        chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier()),
        callRepositoryProvider.overrideWithValue(FakeCallRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        chatMessagesProvider(
          testRoomId,
        ).overrideWith((ref) => Stream.value(messages ?? initialMessages)),
        roomScreenProtectionProvider(testRoomId).overrideWith(
          (ref) => Stream.value(const RoomScreenProtection.failClosed()),
        ),
        roomForwardingProtectionProvider(testRoomId).overrideWith(
          (ref) => Stream.value(const RoomForwardingProtection.failClosed()),
        ),
        chatThemeProvider.overrideWith((ref) => _FakeChatThemeNotifier()),
        e2eeRoomStatusProvider(
          testRoomId,
        ).overrideWith((ref) => FakeE2eeRoomStatusNotifier(testRoomId)),
        timeTickProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('ChatScreen Integration Smoke Tests (Post-Refactoring)', () {
    testWidgets(
      '1. Full-Tree Mounting merender ChatAppBar, ChatMessageListView, dan ChatBottomArea secara harmonis',
      (tester) async {
        await tester.pumpWidget(
          buildSmokeHarness(
            child: const ChatScreen(
              chatId: testRoomId,
              chatName: 'Kontak Smoke Test',
              chatAvatar: 'K',
              isGroup: false,
              otherUserId: 'user_other_1',
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verifikasi layer terpasang lengkap
        expect(find.byType(ChatAppBar), findsOneWidget);
        expect(find.byType(ChatMessageListView), findsOneWidget);
        expect(find.byType(ChatBottomArea), findsOneWidget);

        // Verifikasi data kontak di app bar
        expect(find.text('Kontak Smoke Test'), findsOneWidget);
        expect(find.text('Halo dari rekan chat'), findsOneWidget);

        // Pastikan tidak ada exception layout overflow
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets('2. Input Composer & Typing State merespons pengetikan teks', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSmokeHarness(
          child: const ChatScreen(
            chatId: testRoomId,
            chatName: 'Kontak Smoke Test',
            chatAvatar: 'K',
            isGroup: false,
            otherUserId: 'user_other_1',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsWidgets);

      // Simulasikan input pengguna
      await tester.enterText(textFieldFinder.first, 'Pesan integrasi stabil');
      await tester.pump();

      expect(find.text('Pesan integrasi stabil'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets(
      '3. Safe Route Disposal & Lifecycle Cleanup berjalan bersih tanpa memory leak',
      (tester) async {
        final key = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => FakeAuthNotifier()),
              chatActionsProvider.overrideWithValue(FakeChatActionsNotifier()),
              chatRoomsProvider.overrideWith((ref) => FakeChatRoomsNotifier()),
              callRepositoryProvider.overrideWithValue(FakeCallRepository()),
              chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
              chatMessagesProvider(
                testRoomId,
              ).overrideWith((ref) => Stream.value(initialMessages)),
              roomScreenProtectionProvider(testRoomId).overrideWith(
                (ref) => Stream.value(const RoomScreenProtection.failClosed()),
              ),
              roomForwardingProtectionProvider(testRoomId).overrideWith(
                (ref) =>
                    Stream.value(const RoomForwardingProtection.failClosed()),
              ),
              chatThemeProvider.overrideWith((ref) => _FakeChatThemeNotifier()),
              e2eeRoomStatusProvider(
                testRoomId,
              ).overrideWith((ref) => FakeE2eeRoomStatusNotifier(testRoomId)),
              timeTickProvider.overrideWith(
                (ref) => Stream.value(DateTime.now()),
              ),
            ],
            child: MaterialApp(
              navigatorKey: key,
              home: const Scaffold(body: Text('Halaman Root')),
            ),
          ),
        );

        await tester.pump();

        // Navigasi masuk ke ChatScreen
        key.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => const ChatScreen(
              chatId: testRoomId,
              chatName: 'Kontak Smoke Test',
              chatAvatar: 'K',
              isGroup: false,
              otherUserId: 'user_other_1',
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ChatScreen), findsOneWidget);

        // Navigasi keluar (Pop)
        key.currentState?.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(ChatScreen), findsNothing);
        expect(find.text('Halaman Root'), findsOneWidget);

        // Pastikan seluruh focus node dan controller ter-dispose tanpa exception
        expect(tester.takeException(), isNull);
      },
    );
  });
}
