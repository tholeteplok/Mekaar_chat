import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/widgets/mika_illustration.dart';
import 'package:mekaar_chat/core/widgets/mika_animated.dart';
import 'package:mekaar_chat/core/widgets/mekaar_state_view.dart';

String _getAssetName(ImageProvider provider) {
  if (provider is ResizeImage) {
    return (provider.imageProvider as AssetImage).assetName;
  }
  return (provider as AssetImage).assetName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MikaIllustrationType Tests', () {
    test('Semua 14 tipe ilustrasi WebP terdaftar dengan path yang valid', () {
      expect(MikaIllustrationType.values.length, equals(14));
      for (final type in MikaIllustrationType.values) {
        expect(type.assetPath, startsWith('assets/illustrations/il_'));
        expect(type.assetPath, endsWith('.webp'));
      }
    });

    test('10 Empty states dan 4 Onboarding types terpetakan presisi', () {
      expect(MikaIllustrationType.emptyArchive.assetPath, 'assets/illustrations/il_empty_archive.webp');
      expect(MikaIllustrationType.emptyChat.assetPath, 'assets/illustrations/il_empty_chat.webp');
      expect(MikaIllustrationType.emptyContacts.assetPath, 'assets/illustrations/il_empty_contacts.webp');
      expect(MikaIllustrationType.emptyGuardian.assetPath, 'assets/illustrations/il_empty_guardian.webp');
      expect(MikaIllustrationType.emptyVault.assetPath, 'assets/illustrations/il_empty_vault.webp');
      expect(MikaIllustrationType.emptyAutoCheckin.assetPath, 'assets/illustrations/il_empty_autocheckin.webp');
      expect(MikaIllustrationType.emptySosHistory.assetPath, 'assets/illustrations/il_empty_sos_history.webp');
      expect(MikaIllustrationType.emptyBlocked.assetPath, 'assets/illustrations/il_empty_blocked.webp');
      expect(MikaIllustrationType.emptySearch.assetPath, 'assets/illustrations/il_empty_search.webp');
      expect(MikaIllustrationType.emptyOffline.assetPath, 'assets/illustrations/il_empty_offline.webp');

      expect(MikaIllustrationType.onboardingWelcome.assetPath, 'assets/illustrations/il_onboarding_welcome.webp');
      expect(MikaIllustrationType.onboardingGuardian.assetPath, 'assets/illustrations/il_onboarding_guardian.webp');
      expect(MikaIllustrationType.onboardingSecurity.assetPath, 'assets/illustrations/il_onboarding_security.webp');
      expect(MikaIllustrationType.onboardingSuccess.assetPath, 'assets/illustrations/il_onboarding_success.webp');
    });
  });

  group('MikaPose Backward-Compatibility Tests', () {
    test('Semua 25 index ekspresi (0..24) terpetakan dengan benar ke WebP', () {
      for (int i = 0; i <= 24; i++) {
        final pose = MikaPose.fromIndex(i);
        expect(pose.poseIndex, equals(i));
        expect(pose.spec.assetPath(isDark: false), startsWith('assets/illustrations/il_'));
        expect(pose.spec.assetPath(isDark: true), startsWith('assets/illustrations/il_'));
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
  });

  group('MikaIllustration Widget & MekaarStateView Tests', () {
    testWidgets('Render MikaIllustration langsung dengan MikaIllustrationType', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MikaIllustration(type: MikaIllustrationType.emptyChat),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(_getAssetName(image.image), equals('assets/illustrations/il_empty_chat.webp'));
    });

    testWidgets('Render MikaIllustration via MikaPose fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MikaIllustration(pose: MikaPose.happy),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(_getAssetName(image.image), equals('assets/illustrations/il_onboarding_success.webp'));
    });

    testWidgets('MekaarStateView merender ilustrasi dan teks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              illustration: MikaIllustrationType.emptyOffline,
              title: 'Offline',
              message: 'Terjadi kesalahan pada jaringan.',
            ),
          ),
        ),
      );

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Terjadi kesalahan pada jaringan.'), findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(_getAssetName(image.image), equals('assets/illustrations/il_empty_offline.webp'));
    });

    testWidgets('MekaarStateView merender icon badge saat stateIcon diset', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              stateIcon: SolarIconsOutline.serverSquare,
              title: 'Server Error',
              message: 'Gagal memproses data.',
            ),
          ),
        ),
      );

      expect(find.text('Server Error'), findsOneWidget);
      expect(find.text('Gagal memproses data.'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.serverSquare), findsOneWidget);
      expect(find.byType(MikaIllustration), findsNothing);
    });

    testWidgets('MikaAnimated merender wrapper MikaIllustration dengan tepat', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MikaAnimated(
              illustration: MikaIllustrationType.onboardingSuccess,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(_getAssetName(image.image), equals('assets/illustrations/il_onboarding_success.webp'));
    });
  });
}
