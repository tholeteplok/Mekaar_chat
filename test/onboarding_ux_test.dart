import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(
        routes: {
          AppRoutes.welcomeAnimation: (context) =>
              const Scaffold(body: Text('Mock Welcome Animation')),
          AppRoutes.login: (context) =>
              const Scaffold(body: Text('Mock Login Screen')),
        },
        home: const OnboardingScreen(),
      ),
    );
  }

  group('OnboardingScreen UX Batch 3 Tests', () {
    testWidgets('renders initial slide and "Lanjut" button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang di MEKAAR'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('tapable dot jumps directly to Slide 3 with accurate Vault copy',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap dot 2 (slide 3) directly
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_2')));
      await tester.pumpAndSettle();

      // Verify Slide 3 copy: PIN, cloaking chats & contacts, and encrypted file storage
      expect(find.text('PIN & Brankas Rahasia'), findsOneWidget);
      expect(
        find.text(
          'Amankan obrolan pribadi, sembunyikan kontak sensitif, dan simpan berkas penting dalam Brankas terenkripsi PIN.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('last slide displays "Mulai Sekarang" and navigates to welcome animation',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap index 3 (last slide)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_3')));
      await tester.pumpAndSettle();

      expect(find.text('Privasi Penuh di Tanganmu'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Lanjut'), findsNothing);

      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pumpAndSettle();

      expect(find.text('Mock Welcome Animation'), findsOneWidget);
    });

    testWidgets('tapping "Lewati" navigates directly to login', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Mock Login Screen'), findsOneWidget);
    });
  });
}
