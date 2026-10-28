import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/avatar.dart';

void main() {
  group('Avatar Widget Tests (Acidic Typography & -25° Tilt Pattern)', () {
    testWidgets('1. Merender inisial dengan font Acidic, warna AppColors.blue, dan rotasi -25 derajat', (
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
      expect(textWidget.style?.fontFamily, 'Acidic');
      expect(textWidget.style?.color, AppColors.blue);
      expect(textWidget.style?.fontSize, 56 * 1.12);

      // Verifikasi Transform rotasi miring kiri 25 derajad (-25 * pi / 180)
      final transformFinder = find.descendant(
        of: find.byType(Avatar),
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsOneWidget);

      final transformWidget = tester.widget<Transform>(transformFinder);
      final expectedAngle = -25 * (math.pi / 180);
      // Evaluasi rotasi pada matrix Transform
      expect(transformWidget.transform.storage[0], closeTo(math.cos(expectedAngle), 1e-4));
      expect(transformWidget.transform.storage[1], closeTo(math.sin(expectedAngle), 1e-4));
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
      expect(textWidget.style?.fontFamily, 'Acidic');
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
  });
}
