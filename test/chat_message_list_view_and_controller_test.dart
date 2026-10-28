import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/core/widgets/scroll_to_bottom_button.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/controllers/chat_screen_controller.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_message_list_view.dart';

void main() {
  group('ChatScreenController Unit Tests', () {
    testWidgets('Nilai default controller terinisialisasi dengan benar', (
      tester,
    ) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final focusNode = FocusNode();
      final lastSeenNotifier = ValueNotifier<DateTime?>(null);
      addTearDown(() {
        focusNode.dispose();
        lastSeenNotifier.dispose();
      });

      final controller = ChatScreenController(
        chatId: 'room_test_123',
        ref: widgetRef,
        composerFocusNode: focusNode,
        isKeyboardVisible: () => false,
        isMounted: () => true,
        otherLastSeenNotifier: lastSeenNotifier,
        effectiveOtherUserId: 'user_456',
      );

      expect(controller.chatId, 'room_test_123');
      expect(controller.autoDeleteHours, 0);
      expect(controller.burnOnExit, isFalse);
      expect(controller.burnTriggered, isFalse);
      expect(controller.scheduledWipeMode, 'off');
      expect(controller.scheduledWipeTargetAt, isNull);
      expect(controller.isViewOnce, isFalse);
      expect(controller.isMuted, isFalse);
      expect(controller.isDisposed, isFalse);
      expect(controller.currentOtherUserId, 'user_456');

      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });

    testWidgets('setViewOnce dan setMuted memperbarui state dan memanggil listeners', (
      tester,
    ) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final focusNode = FocusNode();
      final lastSeenNotifier = ValueNotifier<DateTime?>(null);
      addTearDown(() {
        focusNode.dispose();
        lastSeenNotifier.dispose();
      });

      final controller = ChatScreenController(
        chatId: 'room_test_123',
        ref: widgetRef,
        composerFocusNode: focusNode,
        isKeyboardVisible: () => false,
        isMounted: () => true,
        otherLastSeenNotifier: lastSeenNotifier,
      );

      var notifiedCount = 0;
      controller.addListener(() => notifiedCount++);

      controller.setViewOnce(true);
      expect(controller.isViewOnce, isTrue);
      expect(notifiedCount, 1);

      controller.setViewOnce(true); // idempoten, tidak trigger lagi
      expect(notifiedCount, 1);

      controller.setMuted(true);
      expect(controller.isMuted, isTrue);
      expect(notifiedCount, 2);

      controller.dispose();
    });
  });

  group('ChatMessageListView Item Entries & UiMode Tests', () {
    test('chatMessagesUiMode memetakan status stream secara tepat (stale-while-revalidate)', () {
      expect(
        chatMessagesUiMode(const AsyncLoading()),
        ChatMessagesUiMode.loading,
      );

      final errorWithoutData = AsyncValue<List<Message>>.error(
        Exception('Network error'),
        StackTrace.empty,
      );
      expect(
        chatMessagesUiMode(errorWithoutData),
        ChatMessagesUiMode.error,
      );

      final dataValid = AsyncValue.data(<Message>[]);
      expect(
        chatMessagesUiMode(dataValid),
        ChatMessagesUiMode.data,
      );
    });

    test('buildItemEntries menyortir descending dan menyisipkan ChatDateSeparator', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final msg1 = Message(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'user_a',
        content: 'Pesan hari ini',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      final msg2 = Message(
        id: 'msg_2',
        roomId: 'room_1',
        senderId: 'user_b',
        content: 'Pesan kemarin',
        type: MessageType.text,
        createdAt: yesterday,
        updatedAt: yesterday,
      );

      final entries = ChatMessageListView.buildItemEntries([msg1, msg2], []);

      // Ekspektasi:
      // index 0: msg1 (terbaru)
      // index 1: separator tanggal hari ini
      // index 2: msg2 (kemarin)
      // index 3: separator tanggal kemarin
      expect(entries.length, 4);
      expect(entries[0].kind, ChatItemKind.message);
      expect(entries[0].message?.id, 'msg_1');
      expect(entries[1].kind, ChatItemKind.dateSeparator);
      expect(entries[2].kind, ChatItemKind.message);
      expect(entries[2].message?.id, 'msg_2');
      expect(entries[3].kind, ChatItemKind.dateSeparator);
    });
  });

  group('ChatMessageListView Widget Rendering Tests', () {
    testWidgets('Merender ScrollToBottomButton saat showScrollButton aktif', (
      tester,
    ) async {
      final scrollController = ScrollController();
      final showScrollButton = ValueNotifier<bool>(true);
      final newMessageCount = ValueNotifier<int>(3);

      addTearDown(() {
        scrollController.dispose();
        showScrollButton.dispose();
        newMessageCount.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatMessageListView(
                chatId: 'room_test',
                isGroup: false,
                isGuardian: false,
                topAreaHeight: 56,
                searchQuery: '',
                scrollController: scrollController,
                isEmojiPickerOpen: false,
                hiddenCallIds: const {},
                otherLastRead: null,
                selectedMessageIds: const {},
                selectedCallIds: const {},
                reactionAnchorMessageId: null,
                participantNames: const {},
                showScrollButton: showScrollButton,
                newMessageCount: newMessageCount,
                onScrollToBottom: () {},
                onToggleMessageSelection: (_) {},
                onMessageLongPress: (_) {},
                onToggleCallSelection: (_) {},
                onCallLongPress: (_) {},
                onInitiateCall: (_) {},
                onDeleteSingleCall: (_) {},
                onDeleteMessage: (_) {},
                onSwipeDeleteMessage: (_) {},
                onUnsendMessage: (_) {},
                onReplyMessage: (_) {},
                onForwardMessage: (_) {},
                onReactToMessage: (msg, emoji) {},
                onSaveToVault: (_) {},
                getSenderDisplayName: (_) => 'User',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // ScrollToBottomButton harus ada dan menampilkan hitungan 3 pesan baru
      expect(find.byType(ScrollToBottomButton), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
