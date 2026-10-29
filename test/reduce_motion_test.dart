import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/motion.dart';
import 'package:mekaar_chat/core/theme/chat_preset_resolver.dart';
import 'package:mekaar_chat/core/widgets/bubbles/animated_preset_bubble_entrance.dart';
import 'package:mekaar_chat/core/widgets/bubbles/reactions_strip.dart';
import 'package:mekaar_chat/core/widgets/scroll_to_bottom_button.dart';
import 'package:mekaar_chat/features/chat/providers/e2ee_room_status_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/e2ee_security_chip.dart';

Widget _wrapWithMediaQuery({
  required Widget child,
  required bool disableAnimations,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  const testSpec = BubbleEntranceSpec(
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    type: EntranceType.mekaarFadeSlide,
  );

  group('MekaarMotionContext Extension Tests', () {
    testWidgets('MekaarMotionContext returns normal motion when disableAnimations is false',
        (tester) async {
      late bool reduceMotionVal;
      late Duration motionVal;

      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: false,
          child: Builder(
            builder: (context) {
              reduceMotionVal = context.reduceMotion;
              motionVal = context.motion(MekaarMotion.normal);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduceMotionVal, isFalse);
      expect(motionVal, equals(MekaarMotion.normal));
    });

    testWidgets('MekaarMotionContext collapses duration to zero when disableAnimations is true',
        (tester) async {
      late bool reduceMotionVal;
      late Duration motionVal;

      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              reduceMotionVal = context.reduceMotion;
              motionVal = context.motion(MekaarMotion.normal);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduceMotionVal, isTrue);
      expect(motionVal, equals(Duration.zero));
    });
  });

  group('AnimatedPresetBubbleEntrance Reduce Motion Tests', () {
    testWidgets('Renders child directly without SlideTransition or FadeTransition when reduceMotion is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: true,
          child: const AnimatedPresetBubbleEntrance(
            spec: testSpec,
            child: Text('Halo Dunia!'),
          ),
        ),
      );

      // Pada single pump, anak langsung muncul tanpa SlideTransition / FadeTransition dari widget entrance
      expect(find.text('Halo Dunia!'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnimatedPresetBubbleEntrance),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AnimatedPresetBubbleEntrance),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('Renders with transition wrappers when reduceMotion is false',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: false,
          child: const AnimatedPresetBubbleEntrance(
            spec: testSpec,
            child: Text('Halo Dunia!'),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedPresetBubbleEntrance),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AnimatedPresetBubbleEntrance),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
    });
  });

  group('PopReaction Reduce Motion Tests', () {
    testWidgets('Renders without ScaleTransition when reduceMotion is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: true,
          child: const PopReaction(
            emoji: '👍',
            count: 3,
          ),
        ),
      );

      expect(find.text('👍 3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PopReaction),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('Renders with ScaleTransition when reduceMotion is false',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: false,
          child: const PopReaction(
            emoji: '❤️',
            count: 1,
          ),
        ),
      );

      expect(find.text('❤️ 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PopReaction),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
    });
  });

  group('ScrollToBottomButton Reduce Motion Tests', () {
    testWidgets('Applies zero duration when reduceMotion is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: true,
          child: ScrollToBottomButton(
            visible: true,
            onTap: () {},
          ),
        ),
      );

      final animatedOpacity =
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      final animatedScale =
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));

      expect(animatedOpacity.duration, equals(Duration.zero));
      expect(animatedScale.duration, equals(Duration.zero));
      expect(animatedOpacity.opacity, equals(1.0));
      expect(animatedScale.scale, equals(1.0));
    });
  });

  group('E2eeSecurityChip Reduce Motion Tests', () {
    testWidgets('CircularProgressIndicator is determinate (value: 0.8) when reduceMotion is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: true,
          child: const E2eeSecurityChip(
            status: E2eeRoomStatus.preparing,
          ),
        ),
      );

      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.8));
    });

    testWidgets('CircularProgressIndicator is indeterminate (value: null) when reduceMotion is false',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: false,
          child: const E2eeSecurityChip(
            status: E2eeRoomStatus.preparing,
          ),
        ),
      );

      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.value, isNull);
    });
  });
}
