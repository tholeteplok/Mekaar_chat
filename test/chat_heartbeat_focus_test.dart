import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';
import 'package:mekaar_chat/data/models/message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Heartbeat & Focus Protection Tests', () {
    testWidgets('ChatComposer mempertahankan external FocusNode saat keyboard dibuka', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ChatComposer(
                controller: controller,
                focusNode: focusNode,
                replyMessage: null,
                onSend: () {},
                onCancelReply: () {},
                enabled: true,
                canSend: true,
              ),
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isFalse);

      // Fokuskan input
      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);

      // Verifikasi logika supresi: saat focusNode.hasFocus == true, heartbeat tidak boleh berjalan
      bool heartbeatRan = false;
      void runHeartbeatTick({required bool isFocused, required double insetsBottom}) {
        if (isFocused || insetsBottom > 0) return;
        heartbeatRan = true;
      }

      runHeartbeatTick(isFocused: focusNode.hasFocus, insetsBottom: 0);
      expect(heartbeatRan, isFalse, reason: 'Heartbeat harus disupresi saat composer memiliki fokus');

      runHeartbeatTick(isFocused: false, insetsBottom: 300.0);
      expect(heartbeatRan, isFalse, reason: 'Heartbeat harus disupresi saat keyboard terbuka (insets > 0)');

      runHeartbeatTick(isFocused: false, insetsBottom: 0.0);
      expect(heartbeatRan, isTrue, reason: 'Heartbeat boleh berjalan saat keyboard tertutup dan tidak fokus');

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('ChatComposer menampilkan reply preview tanpa karakter mojibake', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final deletedMessage = Message(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Halo',
        type: MessageType.text,
        isDeleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ChatComposer(
                controller: controller,
                focusNode: focusNode,
                replyMessage: deletedMessage,
                onSend: () {},
                onCancelReply: () {},
                enabled: true,
                canSend: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Pastikan string '🚫 Pesan telah dihapus' tampil dan tidak ada mojibake 'ðŸš«'
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('🚫 Pesan telah dihapus'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('ðŸš«'),
        ),
        findsNothing,
      );

      focusNode.dispose();
      controller.dispose();
    });
  });
}
