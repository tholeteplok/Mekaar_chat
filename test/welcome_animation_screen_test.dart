import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/core/widgets/mekaar_scaffold.dart';
import 'package:mekaar_chat/core/widgets/mekaar_wordmark.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_chat/features/auth/screens/welcome_animation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  group('WelcomeAnimationScreen Widget Tests (v3: Dua User Satu Ruang Aman)', () {
    testWidgets(
        'renders initial scene with CustomPaint and skip button in Light Mode',
        (tester) async {
      await tester.pumpWidget(buildWelcomeApp(theme: MekaarTheme.lightTheme()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeAnimationScreen), findsOneWidget);
      expect(find.byType(MekaarScaffold), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Lewati'), findsOneWidget);
    });

    testWidgets('renders properly in Dark Mode with centralized colors',
        (tester) async {
      await tester.pumpWidget(buildWelcomeApp(theme: MekaarTheme.darkTheme()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeAnimationScreen), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Lewati'), findsOneWidget);
    });

    testWidgets('tapping "Lewati" navigates directly to login without once-seen flag',
        (tester) async {
      await tester.pumpWidget(buildWelcomeApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lewati'), findsOneWidget);
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets(
        'full animation (7000ms) displays logo, wordmark, tagline, button "Mulai Sekarang" and handles tap docking',
        (tester) async {
      await tester.pumpWidget(buildWelcomeApp());

      // Babak 1: Dua User (0.0 - 1.4 dtk)
      await tester.pump(const Duration(milliseconds: 1000));

      // Babak 2: Percakapan & Gelembung (1.3 - 2.7 dtk)
      await tester.pump(const Duration(milliseconds: 1500));

      // Babak 3: Fokus & Penggabungan Magnet (2.6 - 4.4 dtk)
      await tester.pump(const Duration(milliseconds: 1800));

      // Babak 4 & 5: Logo MEKAAR resmi, Wordmark, Tagline, dan Tombol "Mulai Sekarang" (~6500ms)
      await tester.pump(const Duration(milliseconds: 2500));

      expect(find.byType(MekaarWordmark), findsOneWidget);
      expect(find.text('Bicara bebas. Tetap aman.'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);

      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final expectedCenterX = screenWidth / 2;

      // Verifikasi titik tengah horizontal Wordmark tepat di sumbu tengah layar
      final wordmarkCenter = tester.getCenter(find.byType(MekaarWordmark));
      expect(wordmarkCenter.dx, closeTo(expectedCenterX, 1.0));

      // Verifikasi titik tengah horizontal Tagline tepat di sumbu tengah layar
      final taglineCenter =
          tester.getCenter(find.text('Bicara bebas. Tetap aman.'));
      expect(taglineCenter.dx, closeTo(expectedCenterX, 1.0));

      // User menekan "Mulai Sekarang" -> memicu Docking Arc (480ms)
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

      // Settle animation ke Babak 5 sehingga tombol "Mulai Sekarang" muncul
      await tester.pump(const Duration(milliseconds: 6800));
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
