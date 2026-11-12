import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/repositories/forwarding_protection_repository.dart';
import 'package:mekaar_chat/data/repositories/screen_protection_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/forwarding_protection_provider.dart';
import 'package:mekaar_chat/features/chat/providers/message_search_provider.dart';
import 'package:mekaar_chat/features/chat/providers/screen_protection_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_app_bar.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_room_privacy_sheet.dart';

class _FakeChatRepository extends Fake implements ChatRepository {
  Map<String, dynamic>? groupDetailsData;

  @override
  Future<Map<String, dynamic>?> getGroupDetails(String roomId) async {
    return groupDetailsData;
  }

  @override
  Future<int> getRoomDisappearingHours(String roomId) async => 0;

  @override
  Future<bool> getRoomBurnOnExit(String roomId) async => false;

  @override
  Future<Map<String, dynamic>?> getRoomScheduledWipe(String roomId) async =>
      null;
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Group Chat Identity & AppBar Governance', () {
    testWidgets(
      'ChatAppBar pada grup menyembunyikan tombol call, menampilkan nama grup & jumlah anggota, dan menu Info Grup',
      (tester) async {
        final lastSeenNotifier = ValueNotifier<DateTime?>(null);
        String? selectedAction;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatAppBar(
                  chatId: 'group-room-1',
                  chatName: 'Tim Keamanan Kota',
                  avatarInitial: 'T',
                  isGuardian: false,
                  isGroup: true,
                  participantCount: 5,
                  otherLastSeenNotifier: lastSeenNotifier,
                  isMuted: false,
                  isSelectionMode: false,
                  totalSelectedCount: 0,
                  selectedMessageIds: const {},
                  selectedCallIds: const {},
                  rawMessages: const [],
                  onClearSelection: () {},
                  onReplySelectedMessage: () {},
                  onEditSelectedMessage: (_) {},
                  onCopySelectedMessages: () {},
                  onForwardSelectedMessages: () {},
                  onDownloadSelectedFiles: (_) {},
                  onSaveSelectedToVault: (_) {},
                  onDeleteSelectedMessages: (_) {},
                  isSearching: false,
                  searchQuery: '',
                  searchController: TextEditingController(),
                  inChatSearchFocusNode: FocusNode(),
                  onCloseSearch: () {},
                  onSearchChanged: (_) {},
                  onClearSearchQuery: () {},
                  onAvatarTap: () {},
                  onInitiateCall: (_) {},
                  onMenuActionSelected: (val) {
                    selectedAction = val;
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Nama grup tampil dengan benar (bukan hardcoded 'Grup Mekaar')
        expect(find.text('Tim Keamanan Kota'), findsOneWidget);
        expect(find.text('Grup Mekaar'), findsNothing);

        // Subtitle menampilkan jumlah anggota, bukan status Daring 1-on-1
        expect(find.text('5 anggota • Enkripsi Server'), findsOneWidget);
        expect(find.text('Daring'), findsNothing);

        // Tombol panggilan video & suara disembunyikan untuk grup
        expect(find.byIcon(SolarIconsOutline.videocamera), findsNothing);
        expect(find.byIcon(SolarIconsOutline.phoneRounded), findsNothing);

        // Buka menu 3-titik dan pastikan "Info Grup" muncul di paling atas
        await tester.tap(find.byIcon(SolarIconsOutline.menuDots));
        await tester.pumpAndSettle();

        expect(find.text('Info Grup'), findsOneWidget);
        expect(find.text('Info Kontak'), findsNothing);

        // Ketuk "Info Grup" dan pastikan callback value = 'info'
        await tester.tap(find.text('Info Grup'));
        await tester.pumpAndSettle();
        expect(selectedAction, 'info');
      },
    );

    testWidgets(
      'ChatAppBar pada chat pribadi (isGroup: false) menampilkan Info Kontak dan tombol panggilan',
      (tester) async {
        final lastSeenNotifier = ValueNotifier<DateTime?>(null);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatAppBar(
                  chatId: 'dm-room-1',
                  chatName: 'Budi Santoso',
                  avatarInitial: 'B',
                  isGuardian: false,
                  isGroup: false,
                  otherLastSeenNotifier: lastSeenNotifier,
                  isMuted: false,
                  isSelectionMode: false,
                  totalSelectedCount: 0,
                  selectedMessageIds: const {},
                  selectedCallIds: const {},
                  rawMessages: const [],
                  onClearSelection: () {},
                  onReplySelectedMessage: () {},
                  onEditSelectedMessage: (_) {},
                  onCopySelectedMessages: () {},
                  onForwardSelectedMessages: () {},
                  onDownloadSelectedFiles: (_) {},
                  onSaveSelectedToVault: (_) {},
                  onDeleteSelectedMessages: (_) {},
                  isSearching: false,
                  searchQuery: '',
                  searchController: TextEditingController(),
                  inChatSearchFocusNode: FocusNode(),
                  onCloseSearch: () {},
                  onSearchChanged: (_) {},
                  onClearSearchQuery: () {},
                  onAvatarTap: () {},
                  onInitiateCall: (_) {},
                  onMenuActionSelected: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(SolarIconsOutline.videocamera), findsOneWidget);
        expect(find.byIcon(SolarIconsOutline.phoneRounded), findsOneWidget);

        await tester.tap(find.byIcon(SolarIconsOutline.menuDots));
        await tester.pumpAndSettle();

        expect(find.text('Info Kontak'), findsOneWidget);
        expect(find.text('Info Grup'), findsNothing);
      },
    );
  });

  group('Group Privacy Governance: ChatRoomPrivacySheet', () {
    testWidgets(
      'Anggota biasa (non-admin) di grup melihat banner read-only dan kontrol kebijakan grup terkunci, sedangkan Mode Sekali Lihat tetap aktif',
      (tester) async {
        final fakeRepo = _FakeChatRepository()
          ..groupDetailsData = {
            'room': {'id': 'group-priv-1', 'name': 'Grup Rahasia'},
            'participants': [
              {'profile_id': 'user-admin', 'role': 'owner'},
              {'profile_id': 'user-member', 'role': 'member'},
            ],
          };

        final fakeAuth = _FakeAuthNotifier(
          AuthState(
            user: const User(
              id: 'user-member',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00Z',
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith((ref) => fakeAuth),
              roomScreenProtectionProvider('group-priv-1').overrideWith(
                (ref) => Stream.value(const RoomScreenProtection.failClosed()),
              ),
              roomForwardingProtectionProvider('group-priv-1').overrideWith(
                (ref) =>
                    Stream.value(const RoomForwardingProtection.failClosed()),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ChatRoomPrivacySheet(
                  roomId: 'group-priv-1',
                  isGroup: true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Banner read-only admin tampil
        expect(
          find.text('Kebijakan privasi grup ini dikelola oleh Admin.'),
          findsOneWidget,
        );

        // Header section khusus grup
        expect(find.text('Penghapusan Otomatis (Grup)'), findsOneWidget);

        // Switch untuk kebijakan grup (Proteksi Layar, Larang Teruskan, Burn on Exit) harus disabled (onChanged == null)
        // Sedangkan Mode Sekali Lihat Default tetap enabled (onChanged != null)
        final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
        expect(switches.length, 4);
        expect(switches[0].onChanged, isNull); // Proteksi Layar & Screenshot
        expect(switches[1].onChanged, isNull); // Larang Teruskan Pesan
        expect(switches[2].onChanged, isNotNull); // Mode Sekali Lihat Default
        expect(switches[3].onChanged, isNull); // Burn on Exit

        // Ikon gembok muncul pada item yang terkunci (banner + 2 nav tiles = 3)
        expect(find.byIcon(SolarIconsBold.lock), findsNWidgets(3));
      },
    );

    testWidgets(
      'Admin/Owner di grup dapat mengelola seluruh kontrol kebijakan privasi grup tanpa banner pembatasan',
      (tester) async {
        final fakeRepo = _FakeChatRepository()
          ..groupDetailsData = {
            'room': {'id': 'group-priv-2', 'name': 'Grup Admin'},
            'participants': [
              {'profile_id': 'user-admin', 'role': 'admin'},
              {'profile_id': 'user-member', 'role': 'member'},
            ],
          };

        final fakeAuth = _FakeAuthNotifier(
          AuthState(
            user: const User(
              id: 'user-admin',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00Z',
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith((ref) => fakeAuth),
              roomScreenProtectionProvider('group-priv-2').overrideWith(
                (ref) => Stream.value(const RoomScreenProtection.failClosed()),
              ),
              roomForwardingProtectionProvider('group-priv-2').overrideWith(
                (ref) =>
                    Stream.value(const RoomForwardingProtection.failClosed()),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ChatRoomPrivacySheet(
                  roomId: 'group-priv-2',
                  isGroup: true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Kebijakan privasi grup ini dikelola oleh Admin.'),
          findsNothing,
        );

        final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
        expect(switches.length, 4);
        for (final sw in switches) {
          expect(sw.onChanged, isNotNull);
        }
        expect(find.byIcon(SolarIconsBold.lock), findsNothing);
      },
    );
  });

  group('RoomSearchResultGroup isGroup Metadata', () {
    test('RoomSearchResultGroup menyimpan status isGroup dengan akurat', () {
      const groupResult = RoomSearchResultGroup(
        roomId: 'r-1',
        roomName: 'Tim Lapangan',
        roomAvatar: 'T',
        isGuardian: false,
        isGroup: true,
        messages: [],
      );
      expect(groupResult.isGroup, isTrue);
      expect(groupResult.otherUserId, isNull);
    });
  });
}
