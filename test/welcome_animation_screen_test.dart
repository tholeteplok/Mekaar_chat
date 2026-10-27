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
    testWidgets('renders initial convergence elements, micro-labels and skip button in Light Mode',
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

    testWidgets('tapping "Lewati" sets has_seen_welcome_animation and navigates to login',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(buildWelcomeApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lewati'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_welcome_animation'), isTrue);
    });

    testWidgets('full animation displays logo, wordmark, tagline, button "Mulai Sekarang" and handles tap docking',
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

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_welcome_animation'), isTrue);
    });

    testWidgets('OnboardingScreen navigates to WelcomeAnimationScreen on first run',
        (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_welcome_animation': false});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              AppRoutes.welcomeAnimation: (context) =>
                  const Scaffold(body: Text('Mock Welcome Animation')),
              AppRoutes.login: (context) =>
                  const Scaffold(body: Text('Mock Login Screen')),
            },
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Jump to last dot (dot 3)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_3')));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Mock Welcome Animation'), findsOneWidget);
    });

    testWidgets('OnboardingScreen navigates directly to Login if already seen',
        (tester) async {
      SharedPreferences.setMockInitialValues({'has_seen_welcome_animation': true});

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              AppRoutes.welcomeAnimation: (context) =>
                  const Scaffold(body: Text('Mock Welcome Animation')),
              AppRoutes.login: (context) =>
                  const Scaffold(body: Text('Mock Login Screen')),
            },
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Jump to last dot (dot 3)
      await tester.tap(find.byKey(const ValueKey('onboarding_dot_3')));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Mock Login Screen'), findsOneWidget);
    });
  });
}
