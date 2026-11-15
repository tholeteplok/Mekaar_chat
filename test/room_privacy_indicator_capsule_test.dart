import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/mekaar_camera_off_icon.dart';
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

    testWidgets('renders iconWidget with MekaarCameraOffIcon correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomPrivacyIndicatorCapsule(
              items: [
                RoomPrivacyIndicatorItem(
                  iconWidget: MekaarCameraOffIcon(
                    size: 14,
                    color: MekaarColors.blue,
                  ),
                  color: MekaarColors.blue,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MekaarCameraOffIcon), findsOneWidget);
    });

    testWidgets('renders all 6 active privacy icons with semantic centralized colors and hourglass', (tester) async {
      const activeItems = [
        RoomPrivacyIndicatorItem(
          iconWidget: MekaarCameraOffIcon(
            size: 14,
            color: MekaarColors.blue,
          ),
          color: MekaarColors.blue,
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
          icon: SolarIconsBold.hourglass,
          color: MekaarColors.blue,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.clockCircle,
          color: MekaarColors.blue,
        ),
        RoomPrivacyIndicatorItem(
          icon: SolarIconsBold.fire,
          color: MekaarColors.sosRed,
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
      expect(find.byType(MekaarCameraOffIcon), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.forbiddenCircle), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.eyeClosed), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.hourglass), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.clockCircle), findsOneWidget);
      expect(find.byIcon(SolarIconsBold.fire), findsOneWidget);
    });
  });
}
