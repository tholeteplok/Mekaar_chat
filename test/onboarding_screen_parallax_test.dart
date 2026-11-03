import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_chat/features/auth/widgets/mekaar_stage_grounding_line.dart';
import 'package:mekaar_chat/features/auth/widgets/mekaar_lottie_parallax_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableOnboarding({
    int initialPage = 0,
    bool disableAnimations = false,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: disableAnimations,
            size: const Size(400, 800),
          ),
          child: OnboardingScreen(initialPage: initialPage),
        ),
      ),
    );
  }

  group('OnboardingScreen Parallax Stage Tests', () {
    testWidgets('Merender halaman awal dengan Garis Pijakan Bersama dan Slide 0',
        (tester) async {
      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pump();

      // Memastikan elemen panggung dasar terpasang
      expect(find.byType(MekaarStageGroundingLine), findsOneWidget);
      expect(find.text('Selamat Datang di MEKAAR'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('Navigasi tombol Lanjut memajukan ke Slide 1',
        (tester) async {
      await tester.pumpWidget(buildTestableOnboarding());
      await tester.pump();

      // Ketuk tombol Lanjut
      await tester.tap(find.byKey(const ValueKey('onboarding_btn_next')));
      await tester.pumpAndSettle();

      expect(find.text('Guardian Tepercaya'), findsOneWidget);
    });

    testWidgets('Halaman terakhir (Slide 4) menampilkan Mulai Sekarang',
        (tester) async {
      await tester.pumpWidget(buildTestableOnboarding(initialPage: 4));
      await tester.pump();

      expect(find.text('Mulai Sekarang'), findsOneWidget);
    });

    testWidgets('Mendukung mode Reduce Motion sistem tanpa translasi bergerak',
        (tester) async {
      await tester.pumpWidget(buildTestableOnboarding(disableAnimations: true));
      await tester.pump();

      expect(find.byType(MekaarStageGroundingLine), findsOneWidget);
      expect(find.text('Selamat Datang di MEKAAR'), findsOneWidget);
    });

    testWidgets('MekaarStageGroundingLine merender garis dan bayangan kontak',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarStageGroundingLine(
                accentColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MekaarStageGroundingLine), findsOneWidget);
    });

    testWidgets('MekaarLottieParallaxItem merender animasi Lottie dengan benar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarLottieParallaxItem(
                assetPath: 'assets/animations/frog_waving_greeting.json',
                distance: 0.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MekaarLottieParallaxItem), findsOneWidget);

      // Ketuk maskot untuk menguji easter egg tap
      await tester.tap(find.byType(MekaarLottieParallaxItem));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MekaarLottieParallaxItem), findsOneWidget);
    });
  });
}
