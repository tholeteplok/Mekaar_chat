import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/mekaar_bottom_nav.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/main_navigation_screen.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_list_screen.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<Map<String, dynamic>>> getRooms() async => [];
}

class FakeGuardiansNotifier extends StateNotifier<List<Guardian>>
    implements GuardiansNotifier {
  FakeGuardiansNotifier(super.state);

  @override
  Future<void> refreshGuardians() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWhoAddedMeNotifier extends StateNotifier<List<Guardian>>
    implements WhoAddedMeNotifier {
  FakeWhoAddedMeNotifier(super.state);

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P0-1 & P1-1: Restrukturisasi & Stabilisasi Tab Navigasi Utama', () {
    testWidgets('MainNavigationScreen menampilkan 4 tab: Pesan, Kontak, Guardian, Pengaturan', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
            cloakedRoomIdsProvider.overrideWith((ref) => <String>{}),
            cloakedContactUserIdsProvider.overrideWith((ref) => <String>{}),
            hasPendingIncomingGuardiansProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verifikasi komponen navigasi bawah muncul
      final navFinder = find.byType(MekaarBottomNav);
      expect(navFinder, findsOneWidget);

      final navWidget = tester.widget<MekaarBottomNav>(navFinder);
      expect(navWidget.items.length, 4);

      // Verifikasi urutan label tab
      expect(navWidget.items[0].label, 'Pesan');
      expect(navWidget.items[1].label, 'Kontak');
      expect(navWidget.items[2].label, 'Guardian');
      expect(navWidget.items[3].label, 'Pengaturan');

      // Verifikasi ikon tab Kontak (personal user, bukan grup multi-person)
      expect(navWidget.items[1].inactiveIcon, SolarIconsOutline.userRounded);
      expect(navWidget.items[1].activeIcon, SolarIconsBold.userRounded);

      // Verifikasi ikon tab Guardian
      expect(navWidget.items[2].inactiveIcon, SolarIconsOutline.shieldUser);
      expect(navWidget.items[2].activeIcon, SolarIconsBold.shieldUser);

      // Flush pending check update timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Tab Guardian menampilkan lencana saat ada undangan pending', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
            cloakedRoomIdsProvider.overrideWith((ref) => <String>{}),
            cloakedContactUserIdsProvider.overrideWith((ref) => <String>{}),
            hasPendingIncomingGuardiansProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      await tester.pump();

      final navFinder = find.byType(MekaarBottomNav);
      final navWidget = tester.widget<MekaarBottomNav>(navFinder);

      expect(navWidget.items[2].unreadCount, 1, reason: 'Badge aktif pada tab Guardian');

      // Flush pending check update timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Tab Guardian menampilkan jumlah riil saat ada multiple undangan pending (P2-4)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
            cloakedRoomIdsProvider.overrideWith((ref) => <String>{}),
            cloakedContactUserIdsProvider.overrideWith((ref) => <String>{}),
            pendingIncomingGuardianCountProvider.overrideWithValue(3),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      await tester.pump();

      final navFinder = find.byType(MekaarBottomNav);
      final navWidget = tester.widget<MekaarBottomNav>(navFinder);

      // Verifikasi bahwa jumlah undangan riil adalah 3, bukan hardcoded 1
      expect(navWidget.items[2].unreadCount, 3, reason: 'Badge harus menampilkan 3 sesuai jumlah undangan riil');

      // Flush pending check update timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('MainNavigationScreen tetap menampilkan 4 tab stabil saat Fitur SOS nonaktif (P1-1)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
            cloakedRoomIdsProvider.overrideWith((ref) => <String>{}),
            cloakedContactUserIdsProvider.overrideWith((ref) => <String>{}),
            hasPendingIncomingGuardiansProvider.overrideWithValue(false),
            sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, false)),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      await tester.pump();

      final navFinder = find.byType(MekaarBottomNav);
      expect(navFinder, findsOneWidget);

      final navWidget = tester.widget<MekaarBottomNav>(navFinder);
      // Memori spasial: tidak memangkas tab dari 4 menjadi 3
      expect(navWidget.items.length, 4);
      expect(navWidget.items[0].label, 'Pesan');
      expect(navWidget.items[1].label, 'Kontak');
      expect(navWidget.items[2].label, 'Guardian');
      expect(navWidget.items[3].label, 'Pengaturan');

      // Flush pending check update timer dari ChatListScreen
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('GuardianListScreen menampilkan state edukasi dan tombol aktivasi saat SOS nonaktif (P1-1)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guardianProvider.overrideWith((ref) => FakeGuardiansNotifier([])),
            whoAddedMeProvider.overrideWith((ref) => FakeWhoAddedMeNotifier([])),
            guardianLoadStatusProvider.overrideWith((ref) => GuardianLoadStatus.data),
            whoAddedMeLoadStatusProvider.overrideWith((ref) => GuardianLoadStatus.data),
            sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, false)),
          ],
          child: const MaterialApp(
            home: GuardianListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fitur Guardian Belum Aktif'), findsOneWidget);
      expect(find.text('Aktifkan Fitur Guardian'), findsOneWidget);
      expect(find.text('Buka Pengaturan Keamanan'), findsOneWidget);

      // Tekan tombol aktivasi fitur guardian
      await tester.tap(find.text('Aktifkan Fitur Guardian'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Memastikan toast/snackbar feedback muncul
      expect(find.text('Fitur Darurat SOS & Guardian berhasil diaktifkan'), findsOneWidget);

      // Setelah diaktifkan, layar beralih ke state normal 'Belum Ada Guardian'
      await tester.pumpAndSettle();
      expect(find.text('Belum Ada Guardian'), findsOneWidget);
    });
  });
}
