import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/screen_protection_widgets.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  group('RoomPrivacyIndicatorCapsule Widget Tests', () {
    testWidgets('renders SizedBox.shrink when icons list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomPrivacyIndicatorCapsule(icons: []),
          ),
        ),
      );

      expect(find.byType(RoomPrivacyIndicatorCapsule), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders single icon with Safe Teal and BackdropFilter blur', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomPrivacyIndicatorCapsule(
              icons: const [SolarIconsBold.shieldCheck],
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.shieldCheck), findsOneWidget);

      final iconWidget = tester.widget<Icon>(find.byIcon(SolarIconsBold.shieldCheck));
      expect(iconWidget.color, equals(MekaarColors.safeTeal));

      // Test tap
      await tester.tap(find.byType(RoomPrivacyIndicatorCapsule));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('renders all active privacy icons adaptively in a single capsule', (tester) async {
      const activeIcons = [
        SolarIconsBold.shieldCheck,
        SolarIconsBold.forbiddenCircle,
        SolarIconsBold.history,
        SolarIconsBold.clockCircle,
        SolarIconsBold.fire,
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomPrivacyIndicatorCapsule(
              icons: activeIcons,
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      for (final icon in activeIcons) {
        expect(find.byIcon(icon), findsOneWidget);
      }
    });
  });
}
