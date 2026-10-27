import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/screen_protection_widgets.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  group('RoomPrivacyIndicatorCapsule Widget Tests', () {
    testWidgets('renders SizedBox.shrink when items list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomPrivacyIndicatorCapsule(items: []),
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
              items: const [
                RoomPrivacyIndicatorItem(
                  icon: SolarIconsBold.shieldCheck,
                  color: MekaarColors.safeTeal,
                ),
              ],
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

    testWidgets('renders all 6 active privacy icons with semantic centralized colors', (tester) async {
      const activeItems = [
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.shieldCheck,
          color: MekaarColors.safeTeal,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.forbiddenCircle,
          color: MekaarColors.blue,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.eyeClosed,
          color: MekaarColors.blue,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.history,
          color: MekaarColors.warnAmber,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.clockCircle,
          color: MekaarColors.warnAmber,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.fire,
          color: MekaarColors.sosCoral,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomPrivacyIndicatorCapsule(
              items: activeItems,
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      for (final item in activeItems) {
        expect(find.byIcon(item.icon), findsOneWidget);
        final widget = tester.widget<Icon>(find.byIcon(item.icon));
        expect(widget.color, equals(item.color));
      }
    });
  });
}
