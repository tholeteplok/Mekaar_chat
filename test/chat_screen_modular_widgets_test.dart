import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_floating_reaction_pill.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_reconnecting_badge.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_selection_app_bar.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_swipe_action_wrapper.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  group('ChatScreen Modular Widgets Tests (Batch 4B)', () {
    testWidgets('ChatSelectionAppBar renders count and fires action callbacks',
        (tester) async {
      bool closed = false;
      bool replied = false;
      bool copied = false;
      bool forwarded = false;
      bool downloaded = false;
      bool vaulted = false;
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: ChatSelectionAppBar(
                selectedCount: 3,
                canReply: true,
                hasCopyableText: true,
                canForward: true,
                canDownload: true,
                canSaveToVault: true,
                textColor: Colors.black,
                iconColor: Colors.black,
                onClose: () => closed = true,
                onReply: () => replied = true,
                onCopy: () => copied = true,
                onForward: () => forwarded = true,
                onDownload: () => downloaded = true,
                onSaveToVault: () => vaulted = true,
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 dipilih'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.byIcon(SolarIconsOutline.closeCircle));
      expect(closed, true);

      // Tap Reply button
      await tester.tap(find.byIcon(SolarIconsOutline.reply));
      expect(replied, true);

      // Tap Copy button
      await tester.tap(find.byIcon(SolarIconsOutline.copy));
      expect(copied, true);

      // Tap Forward button
      await tester.tap(find.byIcon(SolarIconsOutline.forward));
      expect(forwarded, true);

      // Tap Download button
      await tester.tap(find.byIcon(SolarIconsOutline.download));
      expect(downloaded, true);

      // Tap Save to Vault button
      await tester.tap(find.byIcon(SolarIconsOutline.safeSquare));
      expect(vaulted, true);

      // Tap Delete button
      await tester.tap(find.byIcon(SolarIconsOutline.trashBinTrash));
      expect(deleted, true);
    });

    testWidgets('ChatFloatingReactionPill renders emojis and triggers onReact',
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

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);

      await tester.tap(find.text('❤️'));
      expect(selectedEmoji, '❤️');
    });

    testWidgets('ChatSwipeActionWrapper triggers reply on right drag',
        (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 100,
                child: ChatSwipeActionWrapper(
                  onReply: () => replied = true,
                  child: const Text('Bubble Pesan'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bubble Pesan'), findsOneWidget);

      // Drag right by 60 pixels (past threshold 48)
      await tester.drag(find.text('Bubble Pesan'), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(replied, true);
    });

    testWidgets('ChatSwipeActionWrapper triggers delete on double left drag',
        (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 100,
                child: ChatSwipeActionWrapper(
                  onDelete: () => deleted = true,
                  child: const Text('Bubble Pesan 2'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First drag left: does NOT delete yet, primes double-swipe window
      await tester.drag(find.text('Bubble Pesan 2'), const Offset(-60, 0));
      await tester.pump();
      expect(deleted, false);

      // Second drag left within 2 seconds: confirms delete
      await tester.drag(find.text('Bubble Pesan 2'), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(deleted, true);
    });

    testWidgets('ReconnectingBadge renders reconnecting text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReconnectingBadge(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Menyambung ulang…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
