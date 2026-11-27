import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/core/widgets/mekaar_glass_blur_container.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/room_participant_preferences.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/e2ee_service.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/group_details_screen.dart';
import 'package:mekaar_chat/features/chat/screens/main_navigation_screen.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_swipe_action_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class _FakeGroupRepo extends Fake implements ChatRepository {
  final List<Message> messages;
  _FakeGroupRepo(this.messages);

  @override
  String? get currentUserId => 'user-owner';

  @override
  Future<Map<String, dynamic>?> getGroupDetails(String roomId) async {
    return {
      'room': {
        'id': roomId,
        'name': 'Grup Media Sliver',
        'avatar_url': null,
        'is_announcement_only': false,
        'members_can_edit_info': false,
        'members_can_invite': false,
        'created_at': '2026-11-01T10:00:00Z',
      },
      'participants': [
        {
          'profile_id': 'user-owner',
          'role': 'owner',
          'public_profiles': {
            'id': 'user-owner',
            'display_name': 'Owner',
            'username': 'owner',
            'avatar_url': null,
          },
        },
      ],
    };
  }

  @override
  Future<RoomParticipantPreferences?> getRoomPreferences(String roomId) async =>
      null;

  @override
  Stream<List<Message>> streamMessages(
    String roomId, {
    void Function(bool reconnecting)? onReconnectChange,
  }) =>
      Stream.value(messages);
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticChatRoomsNotifier extends ChatRoomsNotifier {
  _StaticChatRoomsNotifier(
    super.repo,
    super.ref,
    List<Map<String, dynamic>> initialRooms,
  ) {
    state = AsyncValue.data(initialRooms);
  }

  @override
  Future<void> refreshRooms({bool forceLoading = false}) async {}

  @override
  Future<void> reloadFromLocalCache({bool syncRemoteInBackground = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Wave 2A: Isolate Media Crypto', () {
    test(
      'encryptMedia & decryptMedia round-trip via Isolate.run mengembalikan Uint8List identik',
      () async {
        final plain = Uint8List.fromList(
          utf8.encode('Rahasia MEKAAR 3.0 Wave 2 Isolate Test! ' * 25),
        );
        final encrypted = await E2eeService.instance.encryptMedia(plain);
        expect(encrypted.bytes, isA<Uint8List>());
        expect(encrypted.bytes.length, greaterThanOrEqualTo(16384));
        expect(encrypted.keyB64, isNotEmpty);

        final decrypted = await E2eeService.instance.decryptMedia(
          encrypted.bytes,
          encrypted.keyB64,
        );
        expect(decrypted, equals(plain));
      },
    );
  });

  group('Wave 2B: ChatBubbleSpec Equality & ChatSwipeActionWrapper', () {
    test('ChatBubbleSpec dan VoxelBevelBorder mengimplementasikan == dan hashCode', () {
      const bevelA = VoxelBevelBorder(
        highlightColor: Colors.white,
        shadowColor: Colors.black,
        width: 3.0,
      );
      const bevelB = VoxelBevelBorder(
        highlightColor: Colors.white,
        shadowColor: Colors.black,
        width: 3.0,
      );
      const bevelC = VoxelBevelBorder(
        highlightColor: Colors.grey,
        shadowColor: Colors.black,
        width: 3.0,
      );
      expect(bevelA, equals(bevelB));
      expect(bevelA.hashCode, equals(bevelB.hashCode));
      expect(bevelA, isNot(equals(bevelC)));

      const specA = ChatBubbleSpec(
        backgroundColor: Colors.blue,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        textColor: Colors.white,
        textStyle: TextStyle(fontSize: 16),
        voxelBevel: bevelA,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      );
      const specB = ChatBubbleSpec(
        backgroundColor: Colors.blue,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        textColor: Colors.white,
        textStyle: TextStyle(fontSize: 16),
        voxelBevel: bevelB,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      );
      final specC = specA.copyWith(backgroundColor: Colors.red);

      expect(specA, equals(specB));
      expect(specA.hashCode, equals(specB.hashCode));
      expect(specA, isNot(equals(specC)));
    });

    testWidgets(
      'ChatSwipeActionWrapper tahan 5x swipe & recoil tanpa kebocoran listener',
      (tester) async {
        int replyCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ChatSwipeActionWrapper(
                  onReply: () => replyCount++,
                  child: const SizedBox(
                    width: 220,
                    height: 60,
                    child: Text('Pesan Uji'),
                  ),
                ),
              ),
            ),
          ),
        );

        for (int i = 0; i < 5; i++) {
          await tester.drag(find.text('Pesan Uji'), const Offset(80, 0));
          await tester.pumpAndSettle();
        }
        expect(replyCount, equals(5));

        // Unmount / dispose widget cleanly
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  });

  group('Wave 2C: Blur Container, Sliver Media Grid & Unread Provider', () {
    testWidgets(
      'MekaarGlassBlurContainer default blurSigma=10, blurSigma=0 tanpa BackdropFilter, rectangle tanpa ClipPath',
      (tester) async {
        const defaultWidget = MekaarGlassBlurContainer(child: Text('Default'));
        expect(defaultWidget.blurSigma, equals(10.0));

        await tester.pumpWidget(
          const MaterialApp(
            home: Column(
              children: [
                MekaarGlassBlurContainer(
                  blurSigma: 0,
                  child: Text('NoBlur'),
                ),
                MekaarGlassBlurContainer(
                  isFloating: true,
                  child: Text('RectBlur'),
                ),
              ],
            ),
          ),
        );

        // Hanya 1 BackdropFilter (dari RectBlur), dan 0 ClipPath (keduanya rectangle)
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(ClipPath), findsNothing);
      },
    );

    testWidgets(
      'GroupDetailsScreen tab Media memakai CustomScrollView + SliverGrid tanpa GridView shrinkWrap',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final messages = [
          Message(
            id: 'img-1',
            senderId: 'user-owner',
            roomId: 'room-sliver',
            content: 'Foto 1',
            createdAt: DateTime.utc(2026, 11, 20, 10),
            updatedAt: DateTime.utc(2026, 11, 20, 10),
            type: MessageType.image,
            mediaUrl: 'https://example.com/1.jpg',
          ),
        ];

        final fakeRepo = _FakeGroupRepo(messages);
        final profile = Profile(
          id: 'user-owner',
          username: 'owner',
          email: 'owner@mekaar.id',
          pinHash: 'x',
          displayName: 'Owner',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith(
                (_) => _FakeAuthNotifier(
                  AuthState(
                    profile: profile,
                    user: const User(
                      id: 'user-owner',
                      appMetadata: {},
                      userMetadata: {},
                      aud: 'authenticated',
                      createdAt: '',
                    ),
                  ),
                ),
              ),
              chatMessagesProvider('room-sliver').overrideWith(
                (_) => Stream.value(messages),
              ),
            ],
            child: const MaterialApp(
              home: GroupDetailsScreen(
                roomId: 'room-sliver',
                groupName: 'Grup Media Sliver',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Media & Berkas'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
      },
    );

    test('visibleTotalUnreadCountProvider mengecualikan room yang cloaked', () {
      final rooms = [
        {'id': 'r1', 'otherUserId': 'u1', 'unreadCount': 3},
        {'id': 'r2', 'otherUserId': 'u2', 'unreadCount': 5},
        {'id': 'r3', 'otherUserId': 'u3', 'unreadCount': 2},
      ];
      final fakeRepo = _FakeGroupRepo(const []);
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          chatRoomsProvider.overrideWith(
            (ref) => _StaticChatRoomsNotifier(fakeRepo, ref, rooms),
          ),
          cloakedRoomIdsProvider.overrideWithValue({'r2'}),
          cloakedContactUserIdsProvider.overrideWithValue({'u2'}),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(visibleTotalUnreadCountProvider), equals(5));
    });
  });
}
