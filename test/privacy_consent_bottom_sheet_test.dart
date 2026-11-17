import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/core/widgets/mekaar_privacy_consent_bottom_sheet.dart';
import 'package:mekaar_chat/data/services/privacy_consent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await PrivacyConsentService.instance.clearConsent();
  });

  Widget buildTestApp({Widget? child}) {
    return MaterialApp(
      theme: MekaarTheme.lightTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: const ValueKey('open_sheet_button'),
                onPressed: () {
                  MekaarPrivacyConsentBottomSheet.show(context: context);
                },
                child: const Text('Buka Lembar Privasi'),
              ),
            );
          },
        ),
      ),
    );
  }

  group('MekaarPrivacyConsentBottomSheet Tests', () {
    testWidgets('menampilkan seluruh bagian naskah komunikasi privasi secara lengkap', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_sheet_button')));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Sebelum Mulai: Cara Kerja Ruang Aman Ini'), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.shieldCheck), findsOneWidget);

      // 1. Yang Dilindungi
      expect(find.text('Yang Dilindungi'), findsOneWidget);
      expect(
        find.textContaining('Percakapanmu terenkripsi ujung ke ujung'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Tanpa nomor HP. Identitasmu di sini hanya username'),
        findsOneWidget,
      );

      // 2. Yang Dikorbankan
      expect(find.text('Yang Dikorbankan (baca ini baik-baik)'), findsOneWidget);
      expect(
        find.textContaining('Ganti HP atau install ulang = semua riwayat percakapan hilang selamanya'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Lupa PIN berarti memulai sebagai identitas baru'),
        findsOneWidget,
      );

      // 3. Batas Perlindungan
      expect(find.text('Batas Perlindungannya'), findsOneWidget);
      expect(
        find.textContaining('Server tetap mengetahui siapa terhubung dengan siapa'),
        findsOneWidget,
      );

      // Checkbox & Tombol
      expect(
        find.textContaining('Saya paham: jika saya berganti perangkat'),
        findsOneWidget,
      );
      expect(find.text('Saya Paham & Lanjutkan'), findsOneWidget);
    });

    testWidgets('tombol lanjutkan nonaktif sebelum dicentang, aktif setelah dicentang', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open_sheet_button')));
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const ValueKey('privacy_consent_continue_button'));
      expect(buttonFinder, findsOneWidget);

      // Status awal: tombol tidak bisa ditekan (onPressed == null)
      ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);

      // Scroll to checkbox & centang
      await tester.ensureVisible(find.byKey(const ValueKey('privacy_consent_checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacy_consent_checkbox')));
      await tester.pumpAndSettle();

      button = tester.widget(buttonFinder);
      expect(button.onPressed, isNotNull);

      // Uncheck checkbox
      await tester.tap(find.byKey(const ValueKey('privacy_consent_checkbox')));
      await tester.pumpAndSettle();

      button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('menekan tombol lanjutkan menyimpan stempel waktu lokal dan menutup bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: MekaarTheme.lightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      dialogResult = await MekaarPrivacyConsentBottomSheet.show(context: context);
                    },
                    child: const Text('Buka Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka Sheet'));
      await tester.pumpAndSettle();

      // Scroll to checkbox tap
      await tester.ensureVisible(find.byKey(const ValueKey('privacy_consent_checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacy_consent_checkbox')));
      await tester.pumpAndSettle();

      // Ensure button is visible & tap Tombol Lanjutkan
      final continueButton = find.byKey(const ValueKey('privacy_consent_continue_button'));
      expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Sheet tertutup & mengembalikan true
      expect(find.byType(MekaarPrivacyConsentBottomSheet), findsNothing);
      expect(dialogResult, isTrue);

      // Verifikasi timestamp tersimpan di PrivacyConsentService
      final hasConsented = await PrivacyConsentService.instance.hasConsented();
      expect(hasConsented, isTrue);

      final timestamp = await PrivacyConsentService.instance.getConsentTimestamp();
      expect(timestamp, isNotNull);
      expect(DateTime.tryParse(timestamp!), isNotNull);
    });
  });

  group('PrivacyConsentService Unit Tests', () {
    test('recordConsent, getConsentTimestamp, hasConsented, and clearConsent work properly', () async {
      expect(await PrivacyConsentService.instance.hasConsented(), isFalse);
      expect(await PrivacyConsentService.instance.getConsentTimestamp(), isNull);

      final testTime = DateTime.utc(2026, 11, 17, 10, 0);
      await PrivacyConsentService.instance.recordConsent(timestamp: testTime);

      expect(await PrivacyConsentService.instance.hasConsented(), isTrue);
      expect(await PrivacyConsentService.instance.getConsentTimestamp(), testTime.toIso8601String());

      await PrivacyConsentService.instance.clearConsent();
      expect(await PrivacyConsentService.instance.hasConsented(), isFalse);
    });
  });
}
