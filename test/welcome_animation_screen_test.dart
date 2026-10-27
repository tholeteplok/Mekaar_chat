import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/core/widgets/mekaar_scaffold.dart';
import 'package:mekaar_chat/core/widgets/mekaar_wordmark.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_chat/features/auth/screens/welcome_animation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildWelcomeApp({ThemeData? theme}) {
    return ProviderScope(
      child: MaterialApp(
        theme: theme ?? MekaarTheme.lightTheme(),
        routes: {
          AppRoutes.login: (context) => const Scaffold(
                body: Text('Login Screen'),
              ),
        },
        home: const WelcomeAnimationScreen(),
      ),
    );
  }

  group('WelcomeAnimationScreen Widget Tests', () {
    testWidgets(
        'renders initial convergence elements, micro-labels and skip button in Light Mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildWelcomeApp(theme: MekaarTheme.lightTheme()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeAnimationScreen), findsOneWidget);
      expect(find.byType(MekaarScaffold), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.chatRoundDots), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.shieldCheck), findsOneWidget);
      expect(find.text('Bicara Bebas'), findsOneWidget);
      expect(find.text('Perlindungan'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
    });

    testWidgets('renders properly in Dark Mode with centralized colors',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildWelcomeApp(theme: MekaarTheme.darkTheme()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeAnimationScreen), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.chatRoundDots), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.shieldCheck), findsOneWidget);
      expect(find.text('Bicara Bebas'), findsOneWidget);
      expect(find.text('Perlindungan'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
    });

    testWidgets('tapping "Lewati" navigates directly to login without once-seen flag',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildWelcomeApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lewati'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets(
        'full animation displays logo, wordmark, tagline, button "Mulai Sekarang" and handles tap docking',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildWelcomeApp());

      // Babak 1: Pendekatan (0ms - 1400ms)
      await tester.pump(const Duration(milliseconds: 600));

      // Babak 2: Sentuhan & Fusi Cahaya (~1600ms)
      await tester.pump(const Duration(milliseconds: 1000));

      // Babak 3: Logo mekar, Wordmark, Tagline, dan Tombol "Mulai Sekarang" (~3200ms)
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byType(MekaarWordmark), findsOneWidget);
      expect(find.text('Bicara bebas. Tetap aman.'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);

      // User menekan "Mulai Sekarang" -> memicu Babak 4: The Docking Glide
      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pump();

      // Selesaikan docking glide (480ms) dan transisi navigasi
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets(
        'OnboardingScreen embeds WelcomeAnimationView on slide 5 and allows tap to start login',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              AppRoutes.login: (context) =>
                  const Scaffold(body: Text('Mock Login Screen')),
            },
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Jump to slide 4 (the 5th dot: onboarding_dot_4)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_4')));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeAnimationView), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);

      // Tap "Mulai Sekarang"
      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Mock Login Screen'), findsOneWidget);
    });

    testWidgets('OnboardingScreen Lewati button navigates directly to Login from slide 1',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              AppRoutes.login: (context) =>
                  const Scaffold(body: Text('Mock Login Screen')),
            },
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lewati'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Mock Login Screen'), findsOneWidget);
    });
  });
}
