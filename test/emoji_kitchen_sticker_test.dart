import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mekaar_chat/core/utils/message_preview_resolver.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/screen_protection_repository.dart';
import 'package:mekaar_chat/features/chat/handlers/chat_media_handler.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/features/chat/providers/private_vault_provider.dart';
import 'package:mekaar_chat/features/chat/providers/screen_protection_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late File dummyImageFile;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('emoji_kitchen_test_');
    dummyImageFile = File('${tempDir.path}/sticker_1x1.png')
      ..writeAsBytesSync(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    clearDecryptedMemoryCacheForTesting();
  });

  tearDownAll(() {
    clearDecryptedMemoryCacheForTesting();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Deteksi & Payload Stiker Dapur Emoji (E2EE & Non-E2EE)', () {
    test('inferKeyboardMediaKind membedakan gboard PNG/WebP, GIF, dan foto biasa', () {
      expect(inferKeyboardMediaKind('/tmp/gboard_12345.png'), 'sticker');
      expect(inferKeyboardMediaKind(r'C:\tmp\gboard_12345.webp'), 'sticker');
      expect(inferKeyboardMediaKind('/tmp/gboard_12345.gif'), 'gif');
      expect(inferKeyboardMediaKind('/storage/DCIM/Camera/IMG_001.png'), isNull);
      expect(inferKeyboardMediaKind('/storage/DCIM/Camera/photo.jpg'), isNull);
    });

    test('ChatMediaHandler.buildImageContentPayload menyematkan kind dan tetap kompatibel mundur', () {
      final e2eeSticker = ChatMediaHandler.buildImageContentPayload(
        fileKeyB64: 'key_abc',
        mediaKind: 'sticker',
      );
      expect(
        jsonDecode(e2eeSticker),
        {'key': 'key_abc', 'kind': 'sticker'},
      );

      final plainSticker = ChatMediaHandler.buildImageContentPayload(
        mediaKind: 'gif',
      );
      expect(jsonDecode(plainSticker), {'kind': 'gif'});

      final normalE2eePhoto = ChatMediaHandler.buildImageContentPayload(
        fileKeyB64: 'key_photo',
      );
      expect(normalE2eePhoto, 'key_photo');
    });

    test('parseMediaPayload & isStickerOrGifMessage mengenali stiker E2EE URL anonim blobs/*.bin', () {
      final now = DateTime.utc(2026, 11, 23, 2, 50);
      final stickerMsg = Message(
        id: 'msg_sticker_e2ee',
        roomId: 'room_1',
        senderId: 'user_a',
        content: '{"key":"secret_key_b64","kind":"sticker"}',
        mediaUrl: 'https://example.supabase.co/storage/v1/object/public/chat-media/blobs/uuid-123.bin',
        type: MessageType.image,
        createdAt: now,
        updatedAt: now,
      );

      final parsed = parseMediaPayload(stickerMsg);
      expect(parsed.fileKeyB64, 'secret_key_b64');
      expect(parsed.caption, '');
      expect(parsed.kind, 'sticker');
      expect(isStickerOrGifMessage(stickerMsg), isTrue);

      final normalPhotoMsg = Message(
        id: 'msg_photo_e2ee',
        roomId: 'room_1',
        senderId: 'user_a',
        content: 'secret_key_b64',
        mediaUrl: 'https://example.supabase.co/storage/v1/object/public/chat-media/blobs/uuid-456.bin',
        type: MessageType.image,
        createdAt: now,
        updatedAt: now,
      );
      expect(parseMediaPayload(normalPhotoMsg).kind, isNull);
      expect(isStickerOrGifMessage(normalPhotoMsg), isFalse);
    });
  });

  group('Rendering Stiker Dapur Emoji di ChatBubble & ImageBubble', () {
    testWidgets(
      'Stiker Dapur Emoji tampil max 160x160 BoxFit.contain, timestamp tetap muncul, dan tap tidak membuka FullScreenImageViewer',
      (tester) async {
        final now = DateTime.utc(2026, 11, 23, 2, 50);
        final expectedTime = DateFormat('HH:mm').format(now.toLocal());
        final stickerMsg = Message(
          id: 'msg_widget_sticker',
          roomId: 'room_sticker',
          senderId: 'user_a',
          content: '{"key":"secret_key_b64","kind":"sticker"}',
          mediaUrl: 'https://example.supabase.co/storage/v1/object/public/chat-media/blobs/uuid-123.bin',
          type: MessageType.image,
          createdAt: now,
          updatedAt: now,
        );
        setDecryptedMemoryCacheForTesting(stickerMsg.id, dummyImageFile);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roomScreenProtectionProvider(stickerMsg.roomId).overrideWith(
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
                body: ChatBubble(
                  message: stickerMsg,
                  isMe: true,
                  animateEntrance: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.fit, BoxFit.contain);

        final constrainedBox = tester.widget<ConstrainedBox>(
          find.ancestor(
            of: find.byType(Image),
            matching: find.byType(ConstrainedBox),
          ).first,
        );
        expect(constrainedBox.constraints.maxWidth, 160);
        expect(constrainedBox.constraints.maxHeight, 160);
        expect(find.text(expectedTime), findsOneWidget);
        expect(find.byType(Hero), findsNothing);

        await tester.tap(find.byType(ImageBubble));
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenImageViewer), findsNothing);
      },
    );

    testWidgets('Foto PNG biasa tanpa kind tetap menggunakan BoxFit.cover & Hero', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 23, 2, 50);
      final photoMsg = Message(
        id: 'msg_widget_photo',
        roomId: 'room_photo',
        senderId: 'user_a',
        content: 'secret_key_b64',
        mediaUrl: 'https://example.supabase.co/storage/v1/object/public/chat-media/blobs/uuid-999.bin',
        type: MessageType.image,
        createdAt: now,
        updatedAt: now,
      );
      setDecryptedMemoryCacheForTesting(photoMsg.id, dummyImageFile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomScreenProtectionProvider(photoMsg.roomId).overrideWith(
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
              body: ChatBubble(
                message: photoMsg,
                isMe: true,
                animateEntrance: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.fit, BoxFit.cover);
      expect(find.byType(Hero), findsOneWidget);
    });
  });

  group('Preview Daftar Chat & Notifikasi Stiker/GIF', () {
    test('MessagePreviewResolver memformat stiker dan GIF secara akurat', () {
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.image,
          content: '{"key":"abc","kind":"sticker"}',
        ),
        '✨ Stiker',
      );
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.image,
          content: '{"key":"abc","kind":"sticker"}',
          isUnreadFromOther: true,
        ),
        '✨ Stiker baru',
      );
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.image,
          content: '{"key":"abc","kind":"gif"}',
        ),
        '🎞️ GIF',
      );
      expect(
        MessagePreviewResolver.sanitizeLastMessage('{"key":"abc","kind":"sticker"}'),
        '✨ Stiker',
      );
    });

    test('MessageNotificationListener.formatNotificationBody memformat stiker dan GIF', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'image',
          content: '{"key":"abc","kind":"sticker"}',
        ),
        '✨ Stiker',
      );
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'image',
          content: '{"key":"abc","kind":"gif"}',
        ),
        '🎞️ GIF',
      );
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'image',
          content: 'raw_key_only',
        ),
        '📷 Foto',
      );
    });
  });
}
