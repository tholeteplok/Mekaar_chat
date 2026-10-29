import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/avatar.dart';
import 'package:mekaar_chat/core/widgets/bubbles/bubble_media_helper.dart';
import 'package:mekaar_chat/core/widgets/bubbles/full_screen_image_viewer.dart';
import 'package:mekaar_chat/core/widgets/bubbles/image_bubble.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/screen_protection_repository.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/providers/screen_protection_provider.dart';

void main() {
  late Directory tempDir;
  late File dummyImageFile;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hero_test_');
    dummyImageFile = File('${tempDir.path}/test_1x1.png')
      ..writeAsBytesSync([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);
  });

  tearDownAll(() {
    clearDecryptedMemoryCacheForTesting();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('UX-06: Avatar Hero Transitions', () {
    testWidgets('Avatar with heroTag: null renders 0 Hero widgets', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Avatar(initial: 'M', size: 48, heroTag: null)),
        ),
      );

      expect(find.byType(Hero), findsNothing);
    });

    testWidgets(
      'Avatar with heroTag renders exactly 1 Hero widget with matching tag',
      (tester) async {
        const tag = 'avatar-room-room_101';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Avatar(initial: 'M', size: 48, heroTag: tag),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, equals(tag));
      },
    );
  });

  group('UX-06: Image Bubble Hero Transitions & Privacy Invariants', () {
    testWidgets(
      'Standard eligible image bubble renders Hero with unique chat-media tag',
      (tester) async {
        final message = Message(
          id: 'msg_img_standard',
          roomId: 'room_plain',
          senderId: 'user_a',
          content: '{"fileKeyB64": "dummy", "caption": ""}',
          mediaUrl: 'https://example.com/standard.png',
          type: MessageType.image,
          createdAt: DateTime(2026, 10, 30),
          updatedAt: DateTime(2026, 10, 30),
        );
        setDecryptedMemoryCacheForTesting(message.id, dummyImageFile);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomScreenProtectionProvider(message.roomId).overrideWith(
                (ref) => Stream.value(
                  const RoomScreenProtection(
                    effective: false,
                    callerEnabled: false,
                    protectorCount: 0,
                    participantCount: 2,
                    lastChange: null,
                  ),
                ),
              ),
              cloakedRoomIdsProvider.overrideWithValue(<String>{}),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImageBubble(
                  message: message,
                  textColor: Colors.black,
                  onViewOnceOpened: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, equals('chat-media-msg_img_standard'));
      },
    );

    testWidgets(
      'View-once message NEVER renders Hero widget (strict privacy invariant)',
      (tester) async {
        final message = Message(
          id: 'msg_img_view_once',
          roomId: 'room_plain',
          senderId: 'user_a',
          content: '{"fileKeyB64": "dummy", "caption": ""}',
          mediaUrl: 'https://example.com/view_once.png',
          type: MessageType.image,
          isViewOnce: true,
          createdAt: DateTime(2026, 10, 30),
          updatedAt: DateTime(2026, 10, 30),
        );
        setDecryptedMemoryCacheForTesting(message.id, dummyImageFile);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ImageBubble(
                  message: message,
                  textColor: Colors.black,
                  onViewOnceOpened: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Hero), findsNothing);
      },
    );

    testWidgets(
      'Screen protection active in room NEVER renders Hero widget (strict security invariant)',
      (tester) async {
        final message = Message(
          id: 'msg_img_protected',
          roomId: 'room_protected',
          senderId: 'user_a',
          content: '{"fileKeyB64": "dummy", "caption": ""}',
          mediaUrl: 'https://example.com/protected.png',
          type: MessageType.image,
          createdAt: DateTime(2026, 10, 30),
          updatedAt: DateTime(2026, 10, 30),
        );
        setDecryptedMemoryCacheForTesting(message.id, dummyImageFile);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomScreenProtectionProvider(message.roomId).overrideWith(
                (ref) => Stream.value(const RoomScreenProtection.failClosed()),
              ),
              cloakedRoomIdsProvider.overrideWithValue(<String>{}),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImageBubble(
                  message: message,
                  textColor: Colors.black,
                  onViewOnceOpened: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Hero), findsNothing);
      },
    );

    testWidgets(
      'Cloaked room in Private Vault NEVER renders Hero widget (strict vault invariant)',
      (tester) async {
        final message = Message(
          id: 'msg_img_vault',
          roomId: 'room_hidden_vault',
          senderId: 'user_a',
          content: '{"fileKeyB64": "dummy", "caption": ""}',
          mediaUrl: 'https://example.com/vault.png',
          type: MessageType.image,
          createdAt: DateTime(2026, 10, 30),
          updatedAt: DateTime(2026, 10, 30),
        );
        setDecryptedMemoryCacheForTesting(message.id, dummyImageFile);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomScreenProtectionProvider(message.roomId).overrideWith(
                (ref) => Stream.value(
                  const RoomScreenProtection(
                    effective: false,
                    callerEnabled: false,
                    protectorCount: 0,
                    participantCount: 2,
                    lastChange: null,
                  ),
                ),
              ),
              cloakedRoomIdsProvider.overrideWithValue({'room_hidden_vault'}),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImageBubble(
                  message: message,
                  textColor: Colors.black,
                  onViewOnceOpened: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Hero), findsNothing);
      },
    );

    testWidgets(
      'Tapping eligible ImageBubble navigates to FullScreenImageViewer with matching heroTag',
      (tester) async {
        final message = Message(
          id: 'msg_img_nav',
          roomId: 'room_nav',
          senderId: 'user_a',
          content: '{"fileKeyB64": "dummy", "caption": ""}',
          mediaUrl: 'https://example.com/nav.png',
          type: MessageType.image,
          createdAt: DateTime(2026, 10, 30),
          updatedAt: DateTime(2026, 10, 30),
        );
        setDecryptedMemoryCacheForTesting(message.id, dummyImageFile);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomScreenProtectionProvider(message.roomId).overrideWith(
                (ref) => Stream.value(
                  const RoomScreenProtection(
                    effective: false,
                    callerEnabled: false,
                    protectorCount: 0,
                    participantCount: 2,
                    lastChange: null,
                  ),
                ),
              ),
              cloakedRoomIdsProvider.overrideWithValue(<String>{}),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImageBubble(
                  message: message,
                  textColor: Colors.black,
                  onViewOnceOpened: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on image bubble to open viewer
        await tester.tap(find.byType(ImageBubble));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // FullScreenImageViewer is now pushed
        expect(find.byType(FullScreenImageViewer), findsOneWidget);

        final viewer = tester.widget<FullScreenImageViewer>(
          find.byType(FullScreenImageViewer),
        );
        expect(viewer.heroTag, equals('chat-media-msg_img_nav'));
      },
    );
  });
}
