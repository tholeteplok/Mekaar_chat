import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/sos_button.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SOSFeatureEnabledNotifier Tests', () {
    test('Default status fitur SOS adalah true (aktif)', () {
      final notifier = SOSFeatureEnabledNotifier();
      expect(notifier.state, isTrue);
    });

    test('Mematikan fitur SOS memperbarui state dan tersimpan di SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = SOSFeatureEnabledNotifier(prefs);

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool(SOSFeatureEnabledNotifier.prefKey), isFalse);

      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool(SOSFeatureEnabledNotifier.prefKey), isTrue);
    });

    test('Reload state dari SharedPreferences yang telah berisi false mengembalikan false', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SOSFeatureEnabledNotifier.prefKey, false);

      final notifier = SOSFeatureEnabledNotifier(prefs);
      expect(notifier.state, isFalse);
    });
  });

  group('PinScreen Adaptive SOS Bar Tests', () {
    testWidgets('PinScreen menyembunyikan bar SOS jika sosFeatureEnabledProvider bernilai false', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, false)),
          ],
          child: const MaterialApp(
            home: PinScreen(),
          ),
        ),
      );
      await tester.pump();

      // Bar SOS bawah ("Tahan 2 dtk untuk darurat" & SOSButton) tidak boleh muncul
      expect(find.text('Tahan 2 dtk untuk darurat'), findsNothing);
      expect(find.byType(SOSButton), findsNothing);
    });

    testWidgets('PinScreen menampilkan bar SOS jika sosFeatureEnabledProvider bernilai true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, true)),
          ],
          child: const MaterialApp(
            home: PinScreen(),
          ),
        ),
      );
      await tester.pump();

      // Bar SOS bawah ("Tahan 2 dtk untuk darurat" & SOSButton) wajib muncul
      expect(find.text('Tahan 2 dtk untuk darurat'), findsOneWidget);
      expect(find.byType(SOSButton), findsOneWidget);
    });
  });

  group('Settings & Pin Management Code Integration Inspection Tests', () {
    test('SettingsScreen memuat toggle Fitur Darurat SOS dan membungkus tile turunan SOS', () {
      final file = File('lib/features/settings/screens/settings_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('Fitur Darurat SOS'), isTrue);
      expect(content.contains('sosFeatureEnabledProvider'), isTrue);
      expect(content.contains('Tombol darurat, pemantauan Guardian, dan siaga SOS'), isTrue);
    });

    test('PinManagementScreen mengadaptasi kartu PIN Darurat saat SOS nonaktif', () {
      final file = File('lib/features/settings/screens/pin_management_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('sosFeatureEnabledProvider'), isTrue);
      expect(content.contains('Nonaktif (SOS Mati)'), isTrue);
      expect(content.contains('Fitur SOS Nonaktif'), isTrue);
    });

    test('ChatListScreen mengondisikan SOSButton dan segment tab bar dengan sosFeatureEnabledProvider', () {
      final file = File('lib/features/chat/screens/chat_list_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('sosFeatureEnabledProvider'), isTrue);
      expect(content.contains('isSosEnabled'), isTrue);
      expect(content.contains('MainAxisAlignment.spaceBetween'), isTrue);
      expect(content.contains('MainAxisAlignment.end'), isTrue);
      expect(content.contains('if (isSosEnabled)'), isTrue);
    });
  });
}
