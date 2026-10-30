import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_floating_reaction_pill.dart';

void main() {
  group('ChatFloatingReactionPill Staggered Entrance Tests (UX-09)', () {
    testWidgets(
      'renders all 6 emojis and triggers onReact synchronously with haptic',
      (tester) async {
        String? selectedEmoji;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatFloatingReactionPill(
                isMe: true,
                onReact: (emoji) => selectedEmoji = emoji,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        const expectedEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
        for (final emoji in expectedEmojis) {
          expect(find.text(emoji), findsOneWidget);
        }

        // Tap ❤️
        await tester.tap(find.text('❤️'));
        expect(selectedEmoji, equals('❤️'));
      },
    );

    testWidgets(
      'staggered animation: first emoji animates ahead of later emojis',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatFloatingReactionPill(isMe: true, onReact: (_) {}),
            ),
          ),
        );

        // Advance by 50ms: first emoji interval [0.0, 0.55] should be animating,
        // while last emoji interval [0.5, 1.0] has barely started or is 0.
        await tester.pump(const Duration(milliseconds: 50));

        final scaleTransitions = tester
            .widgetList<ScaleTransition>(find.byType(ScaleTransition))
            .toList();

        // scaleTransitions[0] is container scale.
        // scaleTransitions[1..6] are the 6 emojis.
        expect(scaleTransitions.length, greaterThanOrEqualTo(7));

        final firstEmojiScale = scaleTransitions[1].scale.value;
        final lastEmojiScale = scaleTransitions[6].scale.value;

        expect(firstEmojiScale, greaterThan(0.0));
        expect(firstEmojiScale, greaterThan(lastEmojiScale));

        // After settling, all scales are 1.0
        await tester.pumpAndSettle();
        final settledScales = tester
            .widgetList<ScaleTransition>(find.byType(ScaleTransition))
            .toList();
        for (int i = 1; i <= 6; i++) {
          expect(settledScales[i].scale.value, equals(1.0));
        }
      },
    );

    testWidgets(
      'reduceMotion active: renders immediately without animation delay',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: ChatFloatingReactionPill(isMe: false, onReact: (_) {}),
              ),
            ),
          ),
        );

        // In reduce motion, initial pump already sets controller value to 1.0
        await tester.pump();
        expect(tester.binding.transientCallbackCount, equals(0));

        final scaleTransitions = tester
            .widgetList<ScaleTransition>(find.byType(ScaleTransition))
            .toList();
        for (int i = 1; i <= 6; i++) {
          expect(scaleTransitions[i].scale.value, equals(1.0));
        }
      },
    );

    testWidgets('alignment adapts based on isMe flag', (tester) async {
      // isMe: true -> Alignment.centerRight
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFloatingReactionPill(isMe: true, onReact: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final alignWidgetMe = tester.widget<Align>(find.byType(Align).first);
      expect(alignWidgetMe.alignment, equals(Alignment.centerRight));

      // isMe: false -> Alignment.centerLeft
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFloatingReactionPill(isMe: false, onReact: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final alignWidgetPeer = tester.widget<Align>(find.byType(Align).first);
      expect(alignWidgetPeer.alignment, equals(Alignment.centerLeft));
    });

    testWidgets(
      'accessibility: includes Semantics button labels and meets 48dp height',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatFloatingReactionPill(isMe: true, onReact: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        const expectedEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
        for (final emoji in expectedEmojis) {
          final semanticsFinder = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Reaksi $emoji',
          );
          expect(semanticsFinder, findsOneWidget);

          final renderBox = tester.renderObject<RenderBox>(
            find.ancestor(of: find.text(emoji), matching: find.byType(InkWell)),
          );
          expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
          expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
        }
      },
    );
  });
}
