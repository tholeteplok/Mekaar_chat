import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/features/chat/providers/e2ee_room_status_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:mekaar_chat/features/chat/widgets/e2ee_security_chip.dart';

void main() {
  group('E2eeSecurityChip Widget Tests', () {
    testWidgets('Renders preparing state with mini spinner and feedback text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: E2eeSecurityChip(
                status: E2eeRoomStatus.preparing,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Percakapan privat sedang dipersiapkan...'),
        findsOneWidget,
      );
    });

    testWidgets('Renders peerMissingKey state with interactive Coba Lagi button',
        (tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: E2eeSecurityChip(
                status: E2eeRoomStatus.peerMissingKey,
                onRetry: () => retryTriggered = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kunci penerima belum aktif (Pesan ditahan)'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      await tester.pump();

      expect(retryTriggered, isTrue);
    });

    testWidgets('Renders needsRestore state with Pulihkan PIN button and callback',
        (tester) async {
      bool restoreTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: E2eeSecurityChip(
                status: E2eeRoomStatus.needsRestore,
                onRestore: () => restoreTriggered = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Kunci E2EE perlu dipulihkan via PIN'), findsOneWidget);
      expect(find.text('Pulihkan'), findsOneWidget);

      await tester.tap(find.text('Pulihkan'));
      await tester.pump();

      expect(restoreTriggered, isTrue);
    });

    testWidgets('Renders ready state and auto-dismisses after delay',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: E2eeSecurityChip(
                status: E2eeRoomStatus.ready,
                autoDismissDelay: Duration(milliseconds: 100),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Terenkripsi End-to-End'), findsOneWidget);

      // Advance clock past the dismiss delay
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Chip has faded out and collapsed
      expect(find.text('Terenkripsi End-to-End'), findsNothing);
    });

    testWidgets('ChatComposer embeds E2eeSecurityChip when e2eeStatus is provided',
        (tester) async {
      final textController = TextEditingController();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposer(
                controller: textController,
                replyMessage: null,
                onSend: () {},
                onCancelReply: () {},
                e2eeStatus: E2eeRoomStatus.preparing,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(E2eeSecurityChip), findsOneWidget);
      expect(
        find.text('Percakapan privat sedang dipersiapkan...'),
        findsOneWidget,
      );

      textController.dispose();
    });
  });
}
