import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/avatar.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Group Chat Bubble Avatar & Layout Tests', () {
    testWidgets('Tampilkan avatar pengirim pada pesan masuk grup', (tester) async {
      final msg = Message(
        id: 'msg_group_1',
        roomId: 'room_group',
        senderId: 'member_alice',
        content: 'Halo semuanya!',
        type: MessageType.text,
        createdAt: DateTime.utc(2026, 11, 13, 10, 0),
        updatedAt: DateTime.utc(2026, 11, 13, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: false,
                senderName: 'Alice',
                senderAvatarUrl: null,
                showSenderAvatar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Memastikan Avatar ditampilkan
      final avatarFinder = find.byType(Avatar);
      expect(avatarFinder, findsOneWidget);

      final avatarWidget = tester.widget<Avatar>(avatarFinder);
      expect(avatarWidget.size, 38.0);
      expect(avatarWidget.initial, 'A');

      // Teks pesan dan pengirim
      expect(find.text('Halo semuanya!'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('Jangan tampilkan avatar untuk pesan keluar (isMe: true)', (tester) async {
      final msg = Message(
        id: 'msg_group_2',
        roomId: 'room_group',
        senderId: 'current_user',
        content: 'Pesan saya sendiri',
        type: MessageType.text,
        createdAt: DateTime.utc(2026, 11, 13, 10, 1),
        updatedAt: DateTime.utc(2026, 11, 13, 10, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: true,
                senderName: 'Saya',
                senderAvatarUrl: 'https://example.com/me.png',
                showSenderAvatar: true, // Akan diabaikan karena isMe == true
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Avatar), findsNothing);
      expect(find.text('Pesan saya sendiri'), findsOneWidget);
    });

    testWidgets('Jangan tampilkan avatar untuk obrolan 1-on-1 (showSenderAvatar: false)', (tester) async {
      final msg = Message(
        id: 'msg_direct_1',
        roomId: 'room_direct',
        senderId: 'other_user',
        content: 'Pesan obrolan pribadi',
        type: MessageType.text,
        createdAt: DateTime.utc(2026, 11, 13, 10, 2),
        updatedAt: DateTime.utc(2026, 11, 13, 10, 2),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: false,
                senderName: null,
                showSenderAvatar: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Avatar), findsNothing);
      expect(find.text('Pesan obrolan pribadi'), findsOneWidget);
    });

    testWidgets('ReactionsStrip terindentasi sejajar dengan bubble saat avatar aktif', (tester) async {
      final msg = Message(
        id: 'msg_reacted_1',
        roomId: 'room_group',
        senderId: 'member_bob',
        content: 'Pesan dengan reaksi',
        type: MessageType.text,
        createdAt: DateTime.utc(2026, 11, 13, 10, 3),
        updatedAt: DateTime.utc(2026, 11, 13, 10, 3),
        reactions: {
          '👍': ['user_1'],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: false,
                senderName: 'Bob',
                showSenderAvatar: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reactionsStripFinder = find.byType(ReactionsStrip);
      expect(reactionsStripFinder, findsOneWidget);

      final reactionsStrip = tester.widget<ReactionsStrip>(reactionsStripFinder);
      expect(reactionsStrip.leftIndent, 50.0);
    });

    testWidgets('Mengetuk avatar atau nama pengirim memicu onSenderTap', (tester) async {
      int tapCount = 0;
      final msg = Message(
        id: 'msg_tap_test_1',
        roomId: 'room_group',
        senderId: 'member_charlie',
        content: 'Ketuk foto profil saya!',
        type: MessageType.text,
        createdAt: DateTime.utc(2026, 11, 13, 10, 4),
        updatedAt: DateTime.utc(2026, 11, 13, 10, 4),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: false,
                senderName: 'Charlie',
                showSenderAvatar: true,
                onSenderTap: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Ketuk Avatar
      await tester.tap(find.byType(Avatar));
      await tester.pumpAndSettle();
      expect(tapCount, 1);

      // 2. Ketuk Nama Pengirim
      await tester.tap(find.text('Charlie'));
      await tester.pumpAndSettle();
      expect(tapCount, 2);
    });
  });
}
