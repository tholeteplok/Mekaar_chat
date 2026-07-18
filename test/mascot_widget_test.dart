import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mika_illustration.dart';
import 'package:mekaar_chat/core/widgets/mekaar_state_view.dart';

void main() {
  group('MikaIllustration', () {
    testWidgets('renders Image.asset with correct asset path', (
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
      final provider = image.image as AssetImage;
      expect(provider.assetName, 'assets/mascot/mika_hi.webp');
      expect(find.bySemanticsLabel('Mika menyapa'), findsOneWidget);
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

    testWidgets('does not animate when reduce motion is enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: MikaIllustration(pose: MikaPose.happy, animate: true),
            ),
          ),
        ),
      );

      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
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
              pose: MikaPose.phone,
              title: 'Belum ada obrolan',
              message: 'Mulai percakapan pertamamu.',
            ),
          ),
        ),
      );

      expect(find.text('Belum ada obrolan'), findsOneWidget);
      expect(find.text('Mulai percakapan pertamamu.'), findsOneWidget);
      expect(find.byType(MikaIllustration), findsOneWidget);
    });

    testWidgets('shows action button when actionLabel and onAction set', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarStateView(
              pose: MikaPose.ask,
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
              pose: MikaPose.hide,
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
  });
}
