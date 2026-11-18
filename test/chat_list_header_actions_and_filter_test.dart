import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/core/widgets/mekaar_sliding_segment_bar.dart';
import 'package:mekaar_chat/data/models/blocked_user_model.dart';
import 'package:mekaar_chat/data/models/contact_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/contact_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/chat_list_screen.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/settings/providers/block_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

class MockChatRoomsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>>
    implements ChatRoomsNotifier {
  MockChatRoomsNotifier(List<Map<String, dynamic>> rooms)
      : super(AsyncValue.data(rooms));

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
  }) {}
}

class FakeContactsNotifier
    extends StateNotifier<AsyncValue<List<ContactItem>>>
    implements ContactsNotifier {
  FakeContactsNotifier(List<ContactItem> items)
      : super(AsyncValue.data(items));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHiddenRoomIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenRoomIdsNotifier {
  FakeHiddenRoomIdsNotifier(super.ids);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHiddenContactUserIdsNotifier extends StateNotifier<Set<String>>
    implements HiddenContactUserIdsNotifier {
  FakeHiddenContactUserIdsNotifier(super.ids);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBlockNotifier
    extends StateNotifier<AsyncValue<List<BlockedUser>>>
    implements BlockNotifier {
  FakeBlockNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<Map<String, dynamic>>> getRooms() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final fakeActiveRoom = {
    'id': 'room-1',
    'name': 'Budi Santoso',
    'lastMessage': 'Halo apa kabar?',
    'timestamp': DateTime.utc(2026, 10, 19, 10, 0),
    'unreadCount': 0,
    'isArchived': false,
    'isGuardian': false,
    'isMuted': false,
  };

  final fakeArchivedRoomWithUnread = {
    'id': 'room-2',
    'name': 'Proyek Rahasia',
    'lastMessage': 'Dokumen rahasia masuk',
    'timestamp': DateTime.utc(2026, 10, 18, 12, 0),
    'unreadCount': 3,
    'isArchived': true,
    'isGuardian': false,
    'isMuted': false,
  };

  Widget createSubject({
    required List<Map<String, dynamic>> rooms,
    bool isDuress = false,
  }) {
    return ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        chatRoomsProvider.overrideWith((ref) => MockChatRoomsNotifier(rooms)),
        sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, true)),
        authProvider.overrideWith((ref) {
          final authRepo = ref.watch(authRepositoryProvider);
          final notifier = AuthNotifier(authRepo);
          notifier.state = AuthState(
            isPinSet: true,
            unlockMode: isDuress ? AuthUnlockMode.duress : AuthUnlockMode.master,
            lastUnlockWasDuress: isDuress,
          );
          return notifier;
        }),
        cloakedRoomIdsProvider.overrideWith((ref) => <String>{}),
        cloakedContactUserIdsProvider.overrideWith((ref) => <String>{}),
        hiddenRoomIdsProvider.overrideWith((ref) => FakeHiddenRoomIdsNotifier(<String>{})),
        hiddenContactUserIdsProvider.overrideWith((ref) => FakeHiddenContactUserIdsNotifier(<String>{})),
        userContactsProvider.overrideWith((ref) => FakeContactsNotifier(<ContactItem>[])),
        blockProvider.overrideWith((ref) => FakeBlockNotifier()),
        hasPendingIncomingGuardiansProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        routes: {
          AppRoutes.archivedChats: (context) => const Scaffold(
                body: Center(child: Text('Screen Arsip Percakapan')),
              ),
        },
        home: const ChatListScreen(),
      ),
    );
  }

  group('K-1: Penghapusan Segment Filter "Semua | Guardian" di ChatListScreen', () {
    testWidgets('MekaarSlidingSegmentBar dan filter tab Guardian tidak lagi ditampilkan', (tester) async {
      await tester.pumpWidget(
        createSubject(rooms: [fakeActiveRoom]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // MekaarSlidingSegmentBar tidak boleh ada di layar daftar chat
      expect(find.byType(MekaarSlidingSegmentBar), findsNothing);

      // Teks tab 'Guardian' tidak boleh ada di header segmen
      expect(find.text('Guardian'), findsNothing);

      // Room normal tetap tampil di daftar
      expect(find.text('Budi Santoso'), findsOneWidget);

      // Flush pending update check timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('K-2: Ikon Header Aksi Langsung Arsip Percakapan', () {
    testWidgets('Header menampilkan tombol Arsip Percakapan dengan tooltip dan ikon yang benar', (tester) async {
      await tester.pumpWidget(
        createSubject(rooms: [fakeActiveRoom]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tombol arsip dengan tooltip 'Arsip Percakapan' harus ada
      final archiveButtonFinder = find.byTooltip('Arsip Percakapan');
      expect(archiveButtonFinder, findsOneWidget);

      // Memastikan ikon yang digunakan adalah archiveCheck
      final iconFinder = find.descendant(
        of: archiveButtonFinder,
        matching: find.byIcon(SolarIconsOutline.archiveCheck),
      );
      expect(iconFinder, findsOneWidget);

      // Karena tidak ada unread pada arsip (unreadCount 0), badge count tidak muncul
      expect(find.text('3'), findsNothing);

      // Flush pending update check timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Badge unread counter muncul pada tombol Arsip jika ada pesan terarsip yang belum dibaca', (tester) async {
      await tester.pumpWidget(
        createSubject(rooms: [fakeActiveRoom, fakeArchivedRoomWithUnread]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tombol arsip ada
      expect(find.byTooltip('Arsip Percakapan'), findsOneWidget);

      // Badge unread '3' harus muncul pada badge arsip
      expect(find.text('3'), findsOneWidget);

      // Flush pending update check timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Mengetuk tombol Arsip Percakapan menavigasikan ke AppRoutes.archivedChats', (tester) async {
      await tester.pumpWidget(
        createSubject(rooms: [fakeActiveRoom]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byTooltip('Arsip Percakapan'));
      await tester.pumpAndSettle();

      // Memastikan layar arsip terbuka
      expect(find.text('Screen Arsip Percakapan'), findsOneWidget);

      // Flush pending update check timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('PopupMenuButton tidak lagi menyertakan opsi Arsip Percakapan', (tester) async {
      await tester.pumpWidget(
        createSubject(rooms: [fakeActiveRoom]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Buka popup menu titik tiga (tooltip 'Menu Tambahan')
      final menuButton = find.byTooltip('Menu Tambahan');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Opsi popup menu yang sah
      expect(find.text('Antar Aku Pulang'), findsOneWidget);
      expect(find.text('Brankas Berkas'), findsOneWidget);

      // Opsi Arsip TIDAK boleh ada di popup menu lagi
      expect(find.text('Arsip Percakapan'), findsNothing);

      // Flush pending update check timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Mode Duress (PIN Paksaan) menyembunyikan kluster aksi header sepenuhnya', (tester) async {
      await tester.pumpWidget(
        createSubject(rooms: [fakeActiveRoom], isDuress: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Pada duress mode, action adalah null sehingga tidak ada tombol aksi di header
      expect(find.byTooltip('Cari Obrolan'), findsNothing);
      expect(find.byTooltip('Arsip Percakapan'), findsNothing);
      expect(find.byTooltip('Menu Tambahan'), findsNothing);

      // Flush pending update check timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
