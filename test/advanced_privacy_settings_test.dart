import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/features/settings/screens/advanced_privacy_settings_screen.dart';
import 'package:mekaar_chat/features/settings/widgets/settings_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'is_notification_masked': true,
      'is_stealth_chat_preview_enabled': false,
      'relay_calls_only': false,
    });
  });

  group('AdvancedPrivacySettingsScreen Widget Tests', () {
    testWidgets('Renders SettingsTopBar and all privacy options', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdvancedPrivacySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi Header terpusat SettingsTopBar
      expect(find.byType(SettingsTopBar), findsOneWidget);
      expect(find.text('Privasi Lanjutan'), findsOneWidget);
      expect(find.text('Manajemen vault, notifikasi & cuplikan pesan'), findsOneWidget);

      // Verifikasi opsi utama
      expect(find.text('Manajemen Vault'), findsOneWidget);
      expect(find.text('Kelola slot vault, kode akses, dan kontak terisolasi'), findsOneWidget);
      expect(find.text('Sembunyikan Notifikasi Darurat'), findsOneWidget);
      expect(find.text('Sembunyikan Cuplikan Pesan'), findsOneWidget);
      expect(find.text('Sembunyikan Alamat IP Panggilan'), findsOneWidget);
    });

    testWidgets('Tapping switch toggles state and updates switch widget UI', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdvancedPrivacySettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Awalnya: 1 'Aktif' (Notifikasi Darurat) dan 2 'Nonaktif' (Cuplikan Pesan & Relay IP)
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Nonaktif'), findsNWidgets(2));

      final stealthSwitch = find.widgetWithText(SettingsSwitchTile, 'Sembunyikan Cuplikan Pesan');
      expect(stealthSwitch, findsOneWidget);

      // Tap toggle Sembunyikan Cuplikan Pesan
      await tester.tap(stealthSwitch);
      await tester.pumpAndSettle();

      // Sekarang 2 berstatus 'Aktif' dan 1 'Nonaktif'
      expect(find.text('Aktif'), findsNWidgets(2));
      expect(find.text('Nonaktif'), findsOneWidget);

      final relaySwitch = find.widgetWithText(SettingsSwitchTile, 'Sembunyikan Alamat IP Panggilan');
      expect(relaySwitch, findsOneWidget);

      // Pastikan widget terlihat di viewport sebelum tap
      await tester.ensureVisible(relaySwitch);
      await tester.pumpAndSettle();

      // Tap toggle Sembunyikan Alamat IP Panggilan
      await tester.tap(relaySwitch);
      await tester.pumpAndSettle();

      // Sekarang seluruhnya (3) berstatus 'Aktif'
      expect(find.text('Aktif'), findsNWidgets(3));
      expect(find.text('Nonaktif'), findsNothing);
    });

    test('AppRoutes registers advancedPrivacySettings correctly', () {
      final route = AppRoutes.generateRoute(
        const RouteSettings(name: AppRoutes.advancedPrivacySettings),
      );
      expect(route, isA<MekaarPageRoute>());
    });
  });
}
