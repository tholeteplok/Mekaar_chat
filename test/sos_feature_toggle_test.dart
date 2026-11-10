import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/sos_button.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/auth/screens/pin_screen.dart';

class FakeWhoAddedMeNotifier extends StateNotifier<List<Guardian>>
    implements WhoAddedMeNotifier {
  FakeWhoAddedMeNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  group('shouldShowGuardianTabProvider Tests', () {
    test('Saat SOS aktif, Tab Guardian selalu tampil (true)', () {
      final ref = ProviderContainer(
        overrides: [
          sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, true)),
          whoAddedMeProvider.overrideWith((ref) => FakeWhoAddedMeNotifier([])),
        ],
      );
      addTearDown(ref.dispose);

      expect(ref.read(shouldShowGuardianTabProvider), isTrue);
    });

    test('Saat SOS nonaktif dan user hanya dijaga (whoAddedMe kosong), Tab Guardian disembunyikan (false)', () {
      final ref = ProviderContainer(
        overrides: [
          sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, false)),
          whoAddedMeProvider.overrideWith((ref) => FakeWhoAddedMeNotifier([])),
        ],
      );
      addTearDown(ref.dispose);

      expect(ref.read(shouldShowGuardianTabProvider), isFalse);
    });

    test('Saat SOS nonaktif TETAPI user bertindak sebagai penjaga aktif (whoAddedMe ada), Tab Guardian WAJIB tampil (true)', () {
      final activeWard = Guardian(
        id: 'rel_1',
        ownerId: 'ward_user',
        guardianId: 'me_guardian',
        name: 'Anak Tercinta',
        email: 'anak@mekaar.id',
        permissions: {'gps': true, 'mic': true, 'video': false},
        storageOption: 'stream_only',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ref = ProviderContainer(
        overrides: [
          sosFeatureEnabledProvider.overrideWith((ref) => SOSFeatureEnabledNotifier(null, false)),
          whoAddedMeProvider.overrideWith((ref) => FakeWhoAddedMeNotifier([activeWard])),
        ],
      );
      addTearDown(ref.dispose);

      expect(ref.read(shouldShowGuardianTabProvider), isTrue);
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
    test('SettingsScreen memuat toggle Fitur Darurat SOS, modal konfirmasi, dan wizard setup', () {
      final file = File('lib/features/settings/screens/settings_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('Fitur Darurat SOS'), isTrue);
      expect(content.contains('sosFeatureEnabledProvider'), isTrue);
      expect(content.contains('_handleSosToggle'), isTrue);
      expect(content.contains('_showSafetySetupWizard'), isTrue);
      expect(content.contains('Nonaktifkan Fitur Darurat SOS?'), isTrue);
      expect(content.contains('Lengkapi Proteksi SOS'), isTrue);
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

    test('MainNavigationScreen mengadaptasi 3 vs 4 tab navigasi bawah dengan shouldShowGuardianTabProvider', () {
      final file = File('lib/features/chat/screens/main_navigation_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('shouldShowGuardianTabProvider'), isTrue);
      expect(content.contains('item.label != \'Guardian\''), isTrue);
    });
  });
}
