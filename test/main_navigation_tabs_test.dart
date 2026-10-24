import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/widgets/mekaar_bottom_nav.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/screens/main_navigation_screen.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<Map<String, dynamic>>> getRooms() async => [];
}

void main() {
  group('P0-1: Restrukturisasi Tab Navigasi Utama', () {
    testWidgets('MainNavigationScreen menampilkan 4 tab: Pesan, Kontak, Guardian, Setelan', (tester) async {
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
      expect(navWidget.items[3].label, 'Setelan');

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
  });
}
