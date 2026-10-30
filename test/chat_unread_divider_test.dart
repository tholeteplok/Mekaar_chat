import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/call_model.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_message_list_view.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_unread_divider.dart';

void main() {
  group('Karakterisasi buildItemEntries (Tanpa Unread Divider)', () {
    test(
      'mengurutkan pesan descending dan menyisipkan pemisah tanggal pada hari berbeda',
      () {
        final now = DateTime(2026, 10, 30, 10, 0);
        final yesterday = DateTime(2026, 10, 29, 15, 0);

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

        // Urutan descending: msg1 -> dateSeparator (hari ini) -> msg2 -> dateSeparator (kemarin)
        expect(entries.length, 4);
        expect(entries[0].kind, ChatItemKind.message);
        expect(entries[0].message?.id, 'msg_1');
        expect(entries[1].kind, ChatItemKind.dateSeparator);
        expect(entries[2].kind, ChatItemKind.message);
        expect(entries[2].message?.id, 'msg_2');
        expect(entries[3].kind, ChatItemKind.dateSeparator);
      },
    );

    test('menyertakan riwayat panggilan yang terurut sesuai timestamp', () {
      final now = DateTime(2026, 10, 30, 10, 0);
      final earlier = DateTime(2026, 10, 30, 9, 30);

      final msg1 = Message(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'user_a',
        content: 'Halo',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      final call1 = CallModel(
        id: 'call_1',
        roomId: 'room_1',
        callerId: 'user_b',
        receiverId: 'user_a',
        status: 'ended',
        callType: 'voice',
        createdAt: earlier,
        updatedAt: earlier,
      );

      final entries = ChatMessageListView.buildItemEntries([msg1], [call1]);

      expect(entries.length, 3);
      expect(entries[0].kind, ChatItemKind.message);
      expect(entries[1].kind, ChatItemKind.call);
      expect(entries[2].kind, ChatItemKind.dateSeparator);
    });
  });

  group('Penyisipan ChatUnreadDivider di buildItemEntries (UX-08)', () {
    const myId = 'user_me';
    const otherId = 'user_other';
    final baseTime = DateTime(2026, 10, 30, 10, 0);
    final lastRead = DateTime(2026, 10, 30, 10, 15);

    test(
      'tidak menyisipkan unread divider jika entryLastReadAt null atau currentUserId null',
      () {
        final msg = Message(
          id: 'm1',
          roomId: 'r1',
          senderId: otherId,
          content: 'Halo',
          type: MessageType.text,
          createdAt: baseTime.add(const Duration(minutes: 20)),
          updatedAt: baseTime.add(const Duration(minutes: 20)),
        );

        final entries1 = ChatMessageListView.buildItemEntries(
          [msg],
          [],
          entryLastReadAt: null,
          currentUserId: myId,
        );
        expect(
          entries1.any((e) => e.kind == ChatItemKind.unreadDivider),
          isFalse,
        );

        final entries2 = ChatMessageListView.buildItemEntries(
          [msg],
          [],
          entryLastReadAt: lastRead,
          currentUserId: null,
        );
        expect(
          entries2.any((e) => e.kind == ChatItemKind.unreadDivider),
          isFalse,
        );
      },
    );

    test(
      'menyisipkan unread divider dengan count 1 tepat di atas pesan masuk yang belum dibaca',
      () {
        final oldMsg = Message(
          id: 'm_old',
          roomId: 'r1',
          senderId: otherId,
          content: 'Pesan lama',
          type: MessageType.text,
          createdAt: baseTime,
          updatedAt: baseTime,
        );
        final newMsg = Message(
          id: 'm_new',
          roomId: 'r1',
          senderId: otherId,
          content: 'Pesan baru',
          type: MessageType.text,
          createdAt: baseTime.add(const Duration(minutes: 30)),
          updatedAt: baseTime.add(const Duration(minutes: 30)),
        );

        final entries = ChatMessageListView.buildItemEntries(
          [oldMsg, newMsg],
          [],
          entryLastReadAt: lastRead,
          currentUserId: myId,
        );

        final unreadEntry = entries.firstWhere(
          (e) => e.kind == ChatItemKind.unreadDivider,
        );
        expect(unreadEntry.unreadCount, 1);

        final unreadIdx = entries.indexOf(unreadEntry);
        final newMsgIdx = entries.indexWhere((e) => e.message?.id == 'm_new');
        expect(unreadIdx, newMsgIdx + 1);
      },
    );

    test(
      'menghitung hanya pesan masuk lawan yang belum dibaca (tidak menghitung pesan sendiri atau terhapus)',
      () {
        final readMsg = Message(
          id: 'm_read',
          roomId: 'r1',
          senderId: otherId,
          content: 'Sudah dibaca',
          type: MessageType.text,
          createdAt: baseTime,
          updatedAt: baseTime,
        );
        final unread1 = Message(
          id: 'm_unread1',
          roomId: 'r1',
          senderId: otherId,
          content: 'Belum dibaca 1',
          type: MessageType.text,
          createdAt: baseTime.add(const Duration(minutes: 20)),
          updatedAt: baseTime.add(const Duration(minutes: 20)),
        );
        final unread2 = Message(
          id: 'm_unread2',
          roomId: 'r1',
          senderId: otherId,
          content: 'Belum dibaca 2',
          type: MessageType.text,
          createdAt: baseTime.add(const Duration(minutes: 25)),
          updatedAt: baseTime.add(const Duration(minutes: 25)),
        );
        final myMsg = Message(
          id: 'm_mine',
          roomId: 'r1',
          senderId: myId,
          content: 'Pesan saya sendiri',
          type: MessageType.text,
          createdAt: baseTime.add(const Duration(minutes: 22)),
          updatedAt: baseTime.add(const Duration(minutes: 22)),
        );
        final deletedMsg = Message(
          id: 'm_del',
          roomId: 'r1',
          senderId: otherId,
          content: 'Dihapus',
          type: MessageType.text,
          isDeleted: true,
          createdAt: baseTime.add(const Duration(minutes: 23)),
          updatedAt: baseTime.add(const Duration(minutes: 23)),
        );

        final entries = ChatMessageListView.buildItemEntries(
          [readMsg, unread1, unread2, myMsg, deletedMsg],
          [],
          entryLastReadAt: lastRead,
          currentUserId: myId,
        );

        final unreadEntries = entries
            .where((e) => e.kind == ChatItemKind.unreadDivider)
            .toList();
        expect(unreadEntries.length, 1);
        expect(unreadEntries.first.unreadCount, 2);

        final oldestUnreadIdx = entries.indexWhere(
          (e) => e.message?.id == 'm_unread1',
        );
        final dividerIdx = entries.indexOf(unreadEntries.first);
        expect(dividerIdx, oldestUnreadIdx + 1);
      },
    );

    test(
      'tidak menyisipkan divider jika seluruh pesan baru sudah dibaca atau tidak ada unread',
      () {
        final msg1 = Message(
          id: 'm1',
          roomId: 'r1',
          senderId: otherId,
          content: 'Lama',
          type: MessageType.text,
          createdAt: baseTime,
          updatedAt: baseTime,
        );

        final entries = ChatMessageListView.buildItemEntries(
          [msg1],
          [],
          entryLastReadAt: lastRead,
          currentUserId: myId,
        );

        expect(
          entries.any((e) => e.kind == ChatItemKind.unreadDivider),
          isFalse,
        );
      },
    );
  });

  group('Widget ChatUnreadDivider (UX-08)', () {
    testWidgets('menampilkan label singular "1 pesan belum dibaca"', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChatUnreadDivider(count: 1))),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 pesan belum dibaca'), findsOneWidget);
    });

    testWidgets('menampilkan label plural "5 pesan belum dibaca"', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChatUnreadDivider(count: 5))),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 pesan belum dibaca'), findsOneWidget);
    });

    testWidgets(
      'memiliki semantik header untuk pembaca layar (Accessibility)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ChatUnreadDivider(count: 3))),
        );
        await tester.pumpAndSettle();

        final semanticsWidget = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(ChatUnreadDivider),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semanticsWidget.properties.label, '3 pesan belum dibaca');
        expect(semanticsWidget.properties.header, isTrue);
      },
    );

    testWidgets('menghormati reduce motion tanpa animasi fade-in', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: Scaffold(body: ChatUnreadDivider(count: 2))),
        ),
      );

      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('2 pesan belum dibaca'), findsOneWidget);
    });
  });
}
