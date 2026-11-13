import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/data/models/room_participant_preferences.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/e2ee_room_status_provider.dart';
import 'package:mekaar_chat/features/chat/screens/group_details_screen.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_bottom_area.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class FakeGroupChatRepository extends Fake implements ChatRepository {
  Map<String, dynamic>? groupDetailsData;
  RoomParticipantPreferences? roomPreferences;
  bool leaveGroupCalled = false;
  bool disbandGroupCalled = false;

  @override
  String? get currentUserId => 'user-owner';

  @override
  Future<Map<String, dynamic>?> getGroupDetails(String roomId) async {
    return groupDetailsData;
  }

  @override
  Future<RoomParticipantPreferences?> getRoomPreferences(String roomId) async {
    return roomPreferences;
  }

  @override
  Future<void> leaveGroup(String roomId) async {
    leaveGroupCalled = true;
  }

  @override
  Future<void> disbandGroup(String roomId) async {
    disbandGroupCalled = true;
  }

  @override
  Future<void> updateRoomMute(String roomId, bool muted) async {
    roomPreferences = RoomParticipantPreferences(
      roomId: roomId,
      isMuted: muted,
    );
  }

  @override
  Future<void> updateGroupPermissions({
    required String roomId,
    required bool isAnnouncementOnly,
    required bool membersCanEditInfo,
    required bool membersCanInvite,
  }) async {
    if (groupDetailsData?['room'] != null) {
      final room = Map<String, dynamic>.from(groupDetailsData!['room']);
      room['is_announcement_only'] = isAnnouncementOnly;
      room['members_can_edit_info'] = membersCanEditInfo;
      room['members_can_invite'] = membersCanInvite;
      groupDetailsData!['room'] = room;
    }
  }
}

class FakeGroupAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeGroupAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRepo extends Fake implements AuthRepository {}

class FakeE2eeRoomStatusNotifier extends E2eeRoomStatusNotifier {
  FakeE2eeRoomStatusNotifier(super.roomId) {
    state = E2eeRoomStatus.ready;
  }

  @override
  Future<void> initializeRoomSecurity({bool isGroup = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Group Governance: ChatBottomArea Announcement Mode', () {
    testWidgets(
      'Locked indicator is rendered and ChatComposer hidden when announcement mode is active for non-admin',
      (tester) async {
        final textController = TextEditingController();
        final focusNode = FocusNode();
        final composerKey = GlobalKey<ChatComposerState>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              e2eeRoomStatusProvider('group-1').overrideWith(
                (ref) => FakeE2eeRoomStatusNotifier('group-1'),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChatBottomArea(
                  chatId: 'group-1',
                  isGroup: true,
                  isAnnouncementOnly: true,
                  canSendInAnnouncement: false,
                  composerKey: composerKey,
                  textController: textController,
                  composerFocusNode: focusNode,
                  onSend: () {},
                  onCancelReply: () {},
                  onCancelEdit: () {},
                  onSendMedia: (file, type, {caption, isViewOnce}) async {},
                  onRestoreE2ee: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.text('Hanya admin yang dapat mengirim pesan di grup ini.'),
          findsOneWidget,
        );
        expect(find.byType(ChatComposer), findsNothing);
      },
    );

    testWidgets(
      'ChatComposer is rendered when user can send messages in announcement mode',
      (tester) async {
        final textController = TextEditingController();
        final focusNode = FocusNode();
        final composerKey = GlobalKey<ChatComposerState>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              e2eeRoomStatusProvider('group-1').overrideWith(
                (ref) => FakeE2eeRoomStatusNotifier('group-1'),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChatBottomArea(
                  chatId: 'group-1',
                  isGroup: true,
                  isAnnouncementOnly: true,
                  canSendInAnnouncement: true,
                  composerKey: composerKey,
                  textController: textController,
                  composerFocusNode: focusNode,
                  onSend: () {},
                  onCancelReply: () {},
                  onCancelEdit: () {},
                  onSendMedia: (file, type, {caption, isViewOnce}) async {},
                  onRestoreE2ee: () {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.text('Hanya admin yang dapat mengirim pesan di grup ini.'),
          findsNothing,
        );
        expect(find.byType(ChatComposer), findsOneWidget);
      },
    );
  });

  group('GroupDetailsScreen: Governance and Member Management', () {
    late FakeGroupChatRepository fakeRepo;
    late Profile testProfile;

    setUp(() {
      testProfile = Profile(
        id: 'user-owner',
        username: 'budi_owner',
        email: 'budi@mekaar.id',
        pinHash: 'dummy',
        fullName: 'Budi Santoso',
        displayName: 'Budi',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      fakeRepo = FakeGroupChatRepository();
      fakeRepo.groupDetailsData = {
        'room': {
          'id': 'room-group-101',
          'name': 'Keluarga Siaga MEKAAR',
          'description': 'Grup darurat dan pantauan keluarga',
          'avatar_url': null,
          'created_by': 'user-owner',
          'is_announcement_only': false,
          'members_can_edit_info': false,
          'members_can_invite': false,
        },
        'participants': [
          {
            'profile_id': 'user-owner',
            'role': 'owner',
            'public_profiles': {
              'id': 'user-owner',
              'username': 'budi_owner',
              'full_name': 'Budi Santoso',
              'display_name': 'Budi',
              'avatar_url': null,
            },
          },
          {
            'profile_id': 'user-admin',
            'role': 'admin',
            'public_profiles': {
              'id': 'user-admin',
              'username': 'siti_admin',
              'full_name': 'Siti Rahma',
              'display_name': 'Siti',
              'avatar_url': null,
            },
          },
          {
            'profile_id': 'user-member',
            'role': 'member',
            'public_profiles': {
              'id': 'user-member',
              'username': 'andi_member',
              'full_name': 'Andi Pratama',
              'display_name': 'Andi',
              'avatar_url': null,
            },
          },
        ],
      };
    });

    testWidgets('Owner sees group permissions card and danger zone controls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authState = AuthState(
        profile: testProfile,
        user: const User(
          id: 'user-owner',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(fakeRepo),
            authProvider.overrideWith((ref) => FakeGroupAuthNotifier(authState)),
          ],
          child: const MaterialApp(
            home: GroupDetailsScreen(
              roomId: 'room-group-101',
              groupName: 'Keluarga Siaga MEKAAR',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Info header
      expect(find.text('Keluarga Siaga MEKAAR'), findsWidgets);
      expect(find.textContaining('3 anggota'), findsWidgets);

      // Roles badges in Anggota tab
      expect(find.text('Pemilik'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Anda'), findsOneWidget);

      // Switch to Pengaturan tab
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      // Permissions section (only visible to admin/owner)
      expect(find.text('IZIN & TATA KELOLA GRUP'), findsOneWidget);
      expect(find.text('Mode Siaran Darurat'), findsOneWidget);

      // Danger zone
      expect(find.text('Keluar dari Grup'), findsOneWidget);
      expect(find.text('Bubarkan Grup Ini'), findsOneWidget);
    });

    testWidgets(
      'Owner cannot leave group if other members exist (Option 1 succession guard)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authState = AuthState(
          profile: testProfile,
          user: const User(
            id: 'user-owner',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith(
                (ref) => FakeGroupAuthNotifier(authState),
              ),
            ],
            child: const MaterialApp(
              home: GroupDetailsScreen(
                roomId: 'room-group-101',
                groupName: 'Keluarga Siaga MEKAAR',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Switch to Pengaturan tab
        await tester.tap(find.text('Pengaturan'));
        await tester.pumpAndSettle();

        // Tap "Keluar dari Grup"
        final leaveBtn = find.text('Keluar dari Grup');
        await tester.ensureVisible(leaveBtn);
        await tester.tap(leaveBtn);
        await tester.pumpAndSettle();

        // Dialog warning "Alihkan Kepemilikan Terlebih Dahulu" should appear
        expect(
          find.text('Alihkan Kepemilikan Terlebih Dahulu'),
          findsOneWidget,
        );
        expect(fakeRepo.leaveGroupCalled, isFalse);

        // Tap "Mengerti"
        await tester.tap(find.text('Mengerti'));
        await tester.pumpAndSettle();

        expect(
          find.text('Alihkan Kepemilikan Terlebih Dahulu'),
          findsNothing,
        );
        expect(fakeRepo.leaveGroupCalled, isFalse);
      },
    );

    testWidgets('Tapping on a member opens member moderation sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authState = AuthState(
        profile: testProfile,
        user: const User(
          id: 'user-owner',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(fakeRepo),
            authProvider.overrideWith(
              (ref) => FakeGroupAuthNotifier(authState),
            ),
          ],
          child: const MaterialApp(
            home: GroupDetailsScreen(
              roomId: 'room-group-101',
              groupName: 'Keluarga Siaga MEKAAR',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on member Andi
      final andiMember = find.text('Andi');
      await tester.ensureVisible(andiMember);
      await tester.tap(andiMember);
      await tester.pumpAndSettle();

      // Owner sees management options for member Andi
      expect(find.text('Kirim Pesan Pribadi ke Andi'), findsOneWidget);
      expect(find.text('Jadikan Admin'), findsOneWidget);
      expect(find.text('Jadikan Pemilik Grup (Transfer)'), findsOneWidget);
      expect(find.text('Keluarkan dari Grup'), findsOneWidget);
    });

    testWidgets(
      'When getGroupDetails returns null, GroupDetailsScreen does not hang and renders fallback header',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Simulasikan database/jaringan gagal mengembalikan details (null)
        fakeRepo.groupDetailsData = null;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith(
                (ref) => FakeGroupAuthNotifier(
                  AuthState(user: User(id: 'user-owner', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: DateTime.now().toIso8601String()), profile: testProfile),
                ),
              ),
            ],
            child: const MaterialApp(
              home: GroupDetailsScreen(
                roomId: 'room-group-fallback',
                groupName: 'Grup Tangguh Mekaar',
              ),
            ),
          ),
        );

        // Awalnya mungkin sempat memuat
        await tester.pump();
        await tester.pumpAndSettle();

        // Loading view "Memuat Detail Grup" WAJIB HILANG (tidak freeze selamanya)
        expect(find.text('Memuat Detail Grup'), findsNothing);

        // Nama grup fallback dari constructor wajib tampil
        expect(find.text('Grup Tangguh Mekaar'), findsOneWidget);

        // State empty anggota ditampilkan dengan aman
        expect(
          find.text('Belum ada data anggota yang dimuat.'),
          findsOneWidget,
        );
      },
    );
  });
}
