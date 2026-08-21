import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mika_illustration.dart';
import 'package:mekaar_chat/core/widgets/mika_animated.dart';
import 'package:mekaar_chat/core/widgets/mekaar_state_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MikaIllustration & MikaPose Unit Tests', () {
    test('Semua 25 index ekspresi (0..24) terpetakan dengan benar', () {
      for (int i = 0; i <= 24; i++) {
        final pose = MikaPose.fromIndex(i);
        expect(pose.poseIndex, equals(i));
        expect(pose.spec.assetPath(isDark: false), contains('mika_light/mika_$i.png'));
        expect(pose.spec.assetPath(isDark: true), contains('mika_dark/mika_dark_$i.png'));
      }
    });

    test('Backward-compatible aliases terpetakan ke spesifikasi yang tepat', () {
      expect(MikaPose.neutral.poseIndex, equals(1));
      expect(MikaPose.happy.poseIndex, equals(3));
      expect(MikaPose.hi.poseIndex, equals(0));
      expect(MikaPose.ok.poseIndex, equals(17));
      expect(MikaPose.love.poseIndex, equals(2));
      expect(MikaPose.ask.poseIndex, equals(9));
      expect(MikaPose.huft.poseIndex, equals(24));
      expect(MikaPose.hide.poseIndex, equals(21));
      expect(MikaPose.phone.poseIndex, equals(18));
      expect(MikaPose.shield.poseIndex, equals(12));
      expect(MikaPose.pin.poseIndex, equals(16));
      expect(MikaPose.sleep.poseIndex, equals(7));
      expect(MikaPose.welcome.poseIndex, equals(20));
      expect(MikaPose.key.poseIndex, equals(16));
    });

    test('Ekspresi baru terdefinisi dengan tepat', () {
      expect(MikaPose.surprised.poseIndex, equals(4));
      expect(MikaPose.angry.poseIndex, equals(5));
      expect(MikaPose.shocked.poseIndex, equals(6));
      expect(MikaPose.playful.poseIndex, equals(8));
      expect(MikaPose.sad.poseIndex, equals(10));
      expect(MikaPose.bawling.poseIndex, equals(11));
      expect(MikaPose.pout.poseIndex, equals(13));
      expect(MikaPose.touched.poseIndex, equals(14));
      expect(MikaPose.celebrate.poseIndex, equals(15));
      expect(MikaPose.cool.poseIndex, equals(16));
      expect(MikaPose.thumbsUp.poseIndex, equals(17));
      expect(MikaPose.handOk.poseIndex, equals(18));
      expect(MikaPose.party.poseIndex, equals(19));
      expect(MikaPose.pray.poseIndex, equals(20));
      expect(MikaPose.awkward.poseIndex, equals(21));
      expect(MikaPose.confused.poseIndex, equals(22));
      expect(MikaPose.heartEyes.poseIndex, equals(23));
      expect(MikaPose.sigh.poseIndex, equals(24));
    });
  });

  group('MikaIllustration Widget & Theme Resolution Tests', () {
    testWidgets('Render MikaIllustration dalam Light Mode memuat mika_light', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: MikaIllustration(pose: MikaPose.happy),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/mascot/mika_light/mika_3.png'));
    });

    testWidgets('Render MikaIllustration dalam Dark Mode memuat mika_dark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MikaIllustration(pose: MikaPose.happy),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/mascot/mika_dark/mika_dark_3.png'));
    });

    testWidgets('MikaIllustration dengan isDarkOverride bekerja independen dari Theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: MikaIllustration(
              pose: MikaPose.shield,
              isDarkOverride: true,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/mascot/mika_dark/mika_dark_12.png'));
    });

    testWidgets('MekaarStateView meneruskan pose dan adaptif tema', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MekaarStateView(
              pose: MikaPose.huft,
              title: 'Gagal Memuat',
              message: 'Terjadi kesalahan pada jaringan.',
            ),
          ),
        ),
      );

      expect(find.text('Gagal Memuat'), findsOneWidget);
      expect(find.text('Terjadi kesalahan pada jaringan.'), findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/mascot/mika_dark/mika_dark_24.png'));
    });

    testWidgets('MikaAnimated merender pose adaptif tema dengan animasi breathing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: MikaAnimated(
              pose: MikaPose.celebrate,
              idle: true,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/mascot/mika_light/mika_15.png'));
    });
  });
}
