import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/models/room_participant_preferences.dart';
import 'package:mekaar_chat/data/models/user_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/screens/group_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class FakeGroupDetailsRepository extends Fake implements ChatRepository {
  final List<Message> messages;

  FakeGroupDetailsRepository({this.messages = const []});

  @override
  String? get currentUserId => 'user-owner';

  @override
  Future<Map<String, dynamic>?> getGroupDetails(String roomId) async {
    return {
      'room': {
        'id': roomId,
        'name': 'Keluarga Siaga MEKAAR',
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
            'display_name': 'Ayah Mekaar',
            'username': 'ayah_mekaar',
            'avatar_url': null,
          },
        },
        {
          'profile_id': 'user-admin',
          'role': 'admin',
          'public_profiles': {
            'id': 'user-admin',
            'display_name': 'Ibu Mekaar',
            'username': 'ibu_mekaar',
            'avatar_url': null,
          },
        },
        {
          'profile_id': 'user-member',
          'role': 'member',
          'public_profiles': {
            'id': 'user-member',
            'display_name': 'Anak Mekaar',
            'username': 'anak_mekaar',
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
  }) {
    return Stream.value(messages);
  }
}

class FakeGroupAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeGroupAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testProfile = Profile(
    id: 'user-owner',
    username: 'ayah_mekaar',
    email: 'ayah@mekaar.id',
    pinHash: 'dummy',
    displayName: 'Ayah Mekaar',
    createdAt: DateTime.parse('2026-11-01T10:00:00Z'),
    updatedAt: DateTime.parse('2026-11-01T10:00:00Z'),
  );

  final testMessages = <Message>[
    Message(
      id: 'msg-photo-1',
      senderId: 'user-owner',
      roomId: 'room-101',
      content: 'Foto Kegiatan',
      createdAt: DateTime.parse('2026-11-10T10:00:00Z'),
      updatedAt: DateTime.parse('2026-11-10T10:00:00Z'),
      type: MessageType.image,
      mediaUrl: 'https://example.com/photo.jpg',
    ),
    Message(
      id: 'msg-file-1',
      senderId: 'user-admin',
      roomId: 'room-101',
      content: jsonEncode({
        'file_name': 'panduan_keamanan.pdf',
        'file_size': 1024 * 500, // 500 KB
        'mime_type': 'application/pdf',
      }),
      createdAt: DateTime.parse('2026-11-11T12:00:00Z'),
      updatedAt: DateTime.parse('2026-11-11T12:00:00Z'),
      type: MessageType.file,
      mediaUrl: 'https://example.com/panduan.pdf',
    ),
  ];

  testWidgets(
    'GroupDetailsScreen: 3-tab navigation, borderless layout, and media filtering',
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

      final fakeRepo = FakeGroupDetailsRepository(messages: testMessages);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(fakeRepo),
            authProvider.overrideWith(
              (ref) => FakeGroupAuthNotifier(authState),
            ),
            chatMessagesProvider('room-101').overrideWith(
              (ref) => Stream.value(testMessages),
            ),
          ],
          child: const MaterialApp(
            home: GroupDetailsScreen(
              roomId: 'room-101',
              groupName: 'Keluarga Siaga MEKAAR',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify TopBar and Subtitle dynamic (no hardcoded subtitle)
      expect(find.text('Info Grup'), findsOneWidget);
      expect(find.text('Grup · 3 anggota'), findsOneWidget);
      expect(find.text('Dibuat untuk koordinasi & keamanan'), findsNothing);

      // 2. Verify Tab Bar labels
      expect(find.text('Anggota (3)'), findsOneWidget);
      expect(find.text('Media & Berkas'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);

      // 3. Tab 1 (Anggota) is active by default
      expect(find.text('DAFTAR ANGGOTA (3)'), findsOneWidget);
      expect(find.text('Ayah Mekaar'), findsOneWidget);
      expect(find.text('Ibu Mekaar'), findsOneWidget);
      expect(find.text('Anak Mekaar'), findsOneWidget);

      // 4. Switch to Tab 2 (Media & Berkas)
      await tester.tap(find.text('Media & Berkas'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Filter chips should be visible
      expect(find.textContaining('Semua'), findsWidgets);
      expect(find.textContaining('Foto & Video'), findsWidgets);
      expect(find.textContaining('Berkas'), findsWidgets);

      // File item should be visible
      expect(find.text('panduan_keamanan.pdf'), findsOneWidget);

      // Filter by Berkas only
      await tester.tap(find.textContaining('Berkas').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('panduan_keamanan.pdf'), findsOneWidget);

      // 5. Switch to Tab 3 (Pengaturan)
      await tester.tap(find.text('Pengaturan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Governance controls
      expect(find.text('IZIN & TATA KELOLA GRUP'), findsOneWidget);
      expect(find.text('Mode Siaran Darurat'), findsOneWidget);
      expect(find.text('Edit Info Grup'), findsOneWidget);
      expect(find.text('Tambah Anggota'), findsOneWidget);

      // Danger zone
      expect(find.text('Keluar dari Grup'), findsOneWidget);
      expect(find.text('Bubarkan Grup Ini'), findsOneWidget);
    },
  );
}
