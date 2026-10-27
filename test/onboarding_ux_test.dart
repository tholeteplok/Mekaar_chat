import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_chat/features/auth/screens/welcome_animation_screen.dart';

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

  group('OnboardingScreen 5-Slide UX Tests', () {
    testWidgets('renders initial slide and "Lanjut" button with 5 dots',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang di MEKAAR'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      // Verify all 5 dots exist
      for (int i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('onboarding_dot_$i')), findsOneWidget);
      }
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
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets(
        'slide 4 (Privacy) advances to slide 5 (Welcome Animation) with "Mulai Sekarang" button',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap index 3 (slide 4)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_3')));
      await tester.pumpAndSettle();

      expect(find.text('Privasi Penuh di Tanganmu'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      // Tap "Lanjut" to advance to slide 5 (the climactic welcome animation)
      await tester.tap(find.text('Lanjut'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(WelcomeAnimationView), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.chatRoundDots), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.shieldCheck), findsOneWidget);

      // Settle animations up to Babak 3
      await tester.pump(const Duration(milliseconds: 3800));

      // Tap "Mulai Sekarang" -> triggers docking glide
      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Mock Login Screen'), findsOneWidget);
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
