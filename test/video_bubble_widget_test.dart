import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:mekaar_chat/data/models/message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoBubble Widget Tests', () {
    testWidgets('Merender VideoBubble dengan kartu video, badge VIDEO, dan tombol play', (tester) async {
      final message = Message(
        id: 'msg-video-001',
        roomId: 'room-1',
        senderId: 'user-1',
        content: jsonEncode({'key': 'test-key', 'caption': 'Video demo safety'}),
        mediaUrl: 'https://example.com/video.mp4',
        type: MessageType.video,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoBubble(
              message: message,
              textColor: Colors.white,
              caption: 'Video demo safety',
              isMe: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Memverifikasi teks caption muncul
      expect(find.text('Video demo safety'), findsOneWidget);

      // Memverifikasi badge "VIDEO"
      expect(find.text('VIDEO'), findsOneWidget);

      // Memverifikasi ikon play (SolarIconsBold.play)
      expect(find.byIcon(SolarIconsBold.play), findsOneWidget);

      // Memverifikasi ikon kamera (SolarIconsBold.videocamera)
      expect(find.byIcon(SolarIconsBold.videocamera), findsOneWidget);
    });

    testWidgets('Mengetuk VideoBubble memicu callback onOpenVideo', (tester) async {
      bool videoOpened = false;

      final message = Message(
        id: 'msg-video-002',
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'video test',
        mediaUrl: 'https://example.com/test.mp4',
        type: MessageType.video,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoBubble(
              message: message,
              textColor: Colors.white,
              onOpenVideo: () async {
                videoOpened = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Ketuk video bubble
      await tester.tap(find.byType(VideoBubble));
      await tester.pumpAndSettle();

      expect(videoOpened, isTrue);
    });

    testWidgets('ChatBubble mendelegasikan MessageType.video ke VideoBubble', (tester) async {
      final message = Message(
        id: 'msg-video-003',
        roomId: 'room-1',
        senderId: 'user-1',
        content: 'video chat bubble',
        mediaUrl: 'https://example.com/video3.mp4',
        type: MessageType.video,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: message,
                isMe: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(VideoBubble), findsOneWidget);
      expect(find.text('VIDEO'), findsOneWidget);
    });
  });
}
