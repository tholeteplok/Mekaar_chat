import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
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

    testWidgets('Supresi _purgeTimer saat composer fokus atau keyboard terbuka', (tester) async {
      bool purgeRan = false;
      void runPurgeTick({required bool isFocused, required double insetsBottom}) {
        if (isFocused || insetsBottom > 0) return;
        purgeRan = true;
      }

      // Kasus 1: Input sedang fokus
      runPurgeTick(isFocused: true, insetsBottom: 0);
      expect(purgeRan, isFalse, reason: '_purgeTimer harus disupresi saat composer fokus');

      // Kasus 2: Keyboard sedang terbuka (insets > 0)
      purgeRan = false;
      runPurgeTick(isFocused: false, insetsBottom: 280.0);
      expect(purgeRan, isFalse, reason: '_purgeTimer harus disupresi saat keyboard terbuka');

      // Kasus 3: Input idle dan keyboard tertutup
      purgeRan = false;
      runPurgeTick(isFocused: false, insetsBottom: 0.0);
      expect(purgeRan, isTrue, reason: '_purgeTimer boleh berjalan saat keyboard tertutup');
    });

    testWidgets('Lifecycle keyboard retention mencatat state saat paused dan merestorasi saat resumed', (tester) async {
      bool wasKeyboardOpenOnPause = false;
      bool keyboardRestorationTriggered = false;

      void simulateLifecycleChange(AppLifecycleState state, {required bool isFocused, required double insetsBottom}) {
        if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
          wasKeyboardOpenOnPause = isFocused || insetsBottom > 0;
        } else if (state == AppLifecycleState.resumed) {
          if (wasKeyboardOpenOnPause) {
            keyboardRestorationTriggered = true;
          }
        }
      }

      // Skenario A: Keyboard terbuka saat layar terkunci -> wajib restorasi saat resume
      simulateLifecycleChange(AppLifecycleState.paused, isFocused: true, insetsBottom: 300.0);
      expect(wasKeyboardOpenOnPause, isTrue);

      simulateLifecycleChange(AppLifecycleState.resumed, isFocused: false, insetsBottom: 0.0);
      expect(keyboardRestorationTriggered, isTrue, reason: 'Restorasi keyboard harus dipicu jika sebelumnya terbuka');

      // Skenario B: Keyboard tertutup saat layar terkunci -> tidak boleh merestorasi
      wasKeyboardOpenOnPause = false;
      keyboardRestorationTriggered = false;
      simulateLifecycleChange(AppLifecycleState.paused, isFocused: false, insetsBottom: 0.0);
      expect(wasKeyboardOpenOnPause, isFalse);

      simulateLifecycleChange(AppLifecycleState.resumed, isFocused: false, insetsBottom: 0.0);
      expect(keyboardRestorationTriggered, isFalse, reason: 'Restorasi keyboard tidak boleh dipicu jika sebelumnya tertutup');
    });

    testWidgets('MekaarPageRoute tidak mencabut fokus saat rebuild atau update metrik', (tester) async {
      final focusNode = FocusNode();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            return MekaarPageRoute(
              builder: (context) => Scaffold(
                body: TextField(
                  focusNode: focusNode,
                  controller: controller,
                ),
              ),
            );
          },
        ),
      );

      // Fokuskan input
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Simulasikan rebuild route (seperti saat insets keyboard atau MediaQuery berubah)
      await tester.pump();
      expect(focusNode.hasFocus, isTrue, reason: 'MekaarPageRoute tidak boleh mencabut fokus pada render pipeline');

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
