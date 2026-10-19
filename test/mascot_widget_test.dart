import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/widgets/mika_animated.dart';
import 'package:mekaar_chat/core/widgets/mika_illustration.dart';
import 'package:mekaar_chat/core/widgets/mekaar_state_view.dart';

String _getAssetName(ImageProvider provider) {
  if (provider is ResizeImage) {
    return (provider.imageProvider as AssetImage).assetName;
  }
  return (provider as AssetImage).assetName;
}

void main() {
  group('MikaIllustration', () {
    testWidgets('renders Image.asset with correct WebP asset path', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MikaIllustration(
              pose: MikaPose.hi,
              size: 90,
              semanticLabel: 'Mika menyapa',
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(_getAssetName(image.image), 'assets/illustrations/il_onboarding_welcome.webp');
      expect(find.bySemanticsLabel('Mika menyapa'), findsOneWidget);
    });

    testWidgets('renders directly with MikaIllustrationType', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MikaIllustration(
              type: MikaIllustrationType.emptyChat,
              size: 160,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(_getAssetName(image.image), 'assets/illustrations/il_empty_chat.webp');
    });

    testWidgets('excludes semantics when no label is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MikaIllustration(pose: MikaPose.ok)),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.excludeFromSemantics, isTrue);
    });
  });

  group('MekaarStateView', () {
    testWidgets('centered layout shows title, message and illustration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              illustration: MikaIllustrationType.emptyChat,
              title: 'Belum ada obrolan',
              message: 'Mulai percakapan pertamamu.',
            ),
          ),
        ),
      );

      expect(find.text('Belum ada obrolan'), findsOneWidget);
      expect(find.text('Mulai percakapan pertamamu.'), findsOneWidget);
      expect(find.byType(MikaAnimated), findsOneWidget);
    });

    testWidgets('shows action button when actionLabel and onAction set', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              illustration: MikaIllustrationType.emptySearch,
              title: 'Kosong',
              message: 'Pesan kosong.',
              actionLabel: 'Mulai',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mulai'));
      expect(tapped, isTrue);
    });

    testWidgets('edge layout places illustration and left-aligned text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              illustration: MikaIllustrationType.emptyBlocked,
              title: 'Tidak ada yang diblokir',
              message: 'Pesan privasi.',
              layout: MekaarStateLayout.edge,
            ),
          ),
        ),
      );

      expect(find.byType(Stack), findsWidgets);
      expect(find.text('Tidak ada yang diblokir'), findsOneWidget);
    });

    testWidgets('renders circular icon badge in error mode when stateIcon is set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              stateIcon: SolarIconsOutline.cloudCross,
              title: 'Tidak Ada Koneksi',
              message: 'Periksa sambungan internet.',
            ),
          ),
        ),
      );

      expect(find.text('Tidak Ada Koneksi'), findsOneWidget);
      expect(find.text('Periksa sambungan internet.'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.cloudCross), findsOneWidget);
      expect(find.byType(MikaIllustration), findsNothing);
    });
  });
}
