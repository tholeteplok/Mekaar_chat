import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/constants/theme_preference.dart';
import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/core/providers/theme_provider.dart';
import 'package:mekaar_chat/core/widgets/mekaar_canvas.dart';
import 'package:mekaar_chat/core/widgets/mekaar_scaffold.dart';
import 'package:mekaar_chat/core/widgets/mekaar_wordmark.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/features/auth/screens/splash_screen.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';

class FakeAuthRepository extends Fake implements AuthRepository {}

class MockSOSRepository extends Fake implements SOSRepository {
  @override
  Future<SOSSession?> getActiveSOS() async => null;
}

class FakeAuthNotifier extends AuthNotifier {
  final Completer<void> _completer = Completer<void>();

  FakeAuthNotifier(super.repo, AuthState initialState) {
    state = initialState;
    _completer.complete();
  }

  @override
  Future<void> get initializationComplete => _completer.future;
}

class FakeThemePreferenceNotifier extends ThemePreferenceNotifier {
  FakeThemePreferenceNotifier(ThemePreference initial) {
    state = AsyncValue.data(initial);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSplashScreen({
    required ThemePreference themePref,
    required ThemeData themeData,
  }) {
    return ProviderScope(
      overrides: [
        themePreferenceProvider.overrideWith((ref) => FakeThemePreferenceNotifier(themePref)),
        authProvider.overrideWith(
          (ref) => FakeAuthNotifier(
            FakeAuthRepository(),
            AuthState(),
          ),
        ),
        sosProvider.overrideWith(
          (ref) => SOSNotifier(MockSOSRepository()),
        ),
      ],
      child: MaterialApp(
        theme: themeData,
        routes: {
          '/onboarding': (c) => const Scaffold(body: Text('Onboarding')),
          '/pin': (c) => const Scaffold(body: Text('PIN')),
          '/home': (c) => const Scaffold(body: Text('Home')),
        },
        home: const SplashScreen(),
      ),
    );
  }

  group('SplashScreen Day/Night Theme Support Tests', () {
    testWidgets('SplashScreen menampilkan tema Siang (Light Mode) dengan flat canvas dan teks kontras', (tester) async {
      final lightTheme = MekaarTheme.lightTheme();

      await tester.pumpWidget(
        buildSplashScreen(
          themePref: ThemePreference.light,
          themeData: lightTheme,
        ),
      );

      // Verifikasi komponen utama muncul
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(MekaarScaffold), findsOneWidget);
      expect(find.byType(MekaarWordmark), findsOneWidget);
      expect(find.text('Bicara bebas. Tetap aman.'), findsOneWidget);

      // Verifikasi MekaarScaffold menggunakan flat: true dan forceDark: false
      final scaffoldWidget = tester.widget<MekaarScaffold>(find.byType(MekaarScaffold));
      expect(scaffoldWidget.flat, isTrue);
      expect(scaffoldWidget.forceDark, isFalse);

      // Verifikasi MekaarCanvas menerapkan warna background terang (scaffoldBackgroundColor dari lightTheme)
      final canvasFinder = find.descendant(
        of: find.byType(MekaarCanvas),
        matching: find.byType(Container),
      ).first;
      final canvasContainer = tester.widget<Container>(canvasFinder);
      expect(canvasContainer.color, equals(lightTheme.scaffoldBackgroundColor));

      // Verifikasi warna teks tagline menggunakan textSecondaryLight
      final taglineText = tester.widget<Text>(find.text('Bicara bebas. Tetap aman.'));
      expect(taglineText.style?.color, equals(MekaarColors.textSecondaryLight));

      // Tuntaskan timer navigasi 800ms
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    });

    testWidgets('SplashScreen menampilkan tema Malam (Dark Mode) dengan flat canvas dan teks kontras', (tester) async {
      final darkTheme = MekaarTheme.darkTheme();

      await tester.pumpWidget(
        buildSplashScreen(
          themePref: ThemePreference.dark,
          themeData: darkTheme,
        ),
      );

      // Verifikasi komponen utama muncul
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(MekaarScaffold), findsOneWidget);
      expect(find.byType(MekaarWordmark), findsOneWidget);
      expect(find.text('Bicara bebas. Tetap aman.'), findsOneWidget);

      // Verifikasi MekaarScaffold menggunakan flat: true dan forceDark: false
      final scaffoldWidget = tester.widget<MekaarScaffold>(find.byType(MekaarScaffold));
      expect(scaffoldWidget.flat, isTrue);
      expect(scaffoldWidget.forceDark, isFalse);

      // Verifikasi MekaarCanvas menerapkan warna background gelap (scaffoldBackgroundColor dari darkTheme)
      final canvasFinder = find.descendant(
        of: find.byType(MekaarCanvas),
        matching: find.byType(Container),
      ).first;
      final canvasContainer = tester.widget<Container>(canvasFinder);
      expect(canvasContainer.color, equals(darkTheme.scaffoldBackgroundColor));

      // Verifikasi warna teks tagline menggunakan textSecondaryDark
      final taglineText = tester.widget<Text>(find.text('Bicara bebas. Tetap aman.'));
      expect(taglineText.style?.color, equals(MekaarColors.textSecondaryDark));

      // Tuntaskan timer navigasi 800ms
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    });
  });
}
