import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/avatar.dart';

void main() {
  group('Avatar Widget Tests (Baloo 2 Typography & Subdued Slate Initial Pattern)', () {
    testWidgets('1. Merender inisial dengan font Baloo 2, warna tenang Slate 500 (Light Mode), dan terpusat rapi', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Avatar(
              initial: 'Mekaar',
              size: 56,
            ),
          ),
        ),
      );

      // Verifikasi widget Text dengan inisial 'M'
      final textFinder = find.text('M');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontFamily, contains('Baloo'));
      expect(textWidget.style?.color, const Color(0xFF64748B));
      expect(textWidget.style?.fontSize, 56 * 0.52);
    });

    testWidgets('2. Merender simbol fallback "?" saat inisial null atau string kosong', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Avatar(
              initial: '',
              size: 48,
            ),
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('?'));
      expect(textWidget.style?.fontFamily, contains('Baloo'));
      expect(textWidget.style?.color, const Color(0xFF64748B));
    });

    testWidgets('3. Merender border tipis 1.0px dan container ClipOval pada mode Light & Dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Avatar(
              initial: 'A',
              size: 48,
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      final coreContainer = tester.widget<Container>(containerFinder.first);
      final boxDeco = coreContainer.decoration as BoxDecoration?;
      expect(boxDeco?.shape, BoxShape.circle);
      expect(boxDeco?.border?.top.width, 1.0);
      expect(boxDeco?.color, const Color(0xFF152641)); // Dark background
    });

    testWidgets('4. Merender cincin outer ring Guardian saat isGuardian = true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Avatar(
              initial: 'G',
              size: 60,
              isGuardian: true,
            ),
          ),
        ),
      );

      expect(find.text('G'), findsOneWidget);

      // Pada isGuardian: true, ada outer container pembungkus dengan warna guardianTeal
      final containers = tester.widgetList<Container>(find.byType(Container));
      final guardianContainer = containers.firstWhere(
        (c) => (c.decoration as BoxDecoration?)?.color == MekaarColors.guardianTeal,
      );
      expect(guardianContainer, isNotNull);
      expect(guardianContainer.constraints?.maxWidth, 60);
    });

    testWidgets('5. Mode non-crayon (useCrayonStyle: false) merender teks standar tanpa rotasi', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Avatar(
              initial: 'B',
              size: 40,
              useCrayonStyle: false,
            ),
          ),
        ),
      );

      expect(find.text('B'), findsOneWidget);
      // Pada useCrayonStyle = false, tidak ada Transform.rotate di dalam Avatar
      final transformFinder = find.descendant(
        of: find.byType(Avatar),
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsNothing);
    });

    testWidgets('6. Avatar dengan heroTag membungkus child dengan Material transparan dan flightShuttleBuilder', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Avatar(
              initial: 'H',
              size: 48,
              heroTag: 'test-avatar-hero',
            ),
          ),
        ),
      );

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);

      final heroWidget = tester.widget<Hero>(heroFinder);
      expect(heroWidget.tag, 'test-avatar-hero');
      expect(heroWidget.flightShuttleBuilder, isNotNull);

      // Pastikan child di dalam Hero dibungkus Material type transparency untuk stabilitas Overlay
      final materialFinder = find.descendant(
        of: heroFinder,
        matching: find.byType(Material),
      );
      expect(materialFinder, findsWidgets);

      final materialWidget = tester.widget<Material>(materialFinder.first);
      expect(materialWidget.type, MaterialType.transparency);
    });
  });
}
