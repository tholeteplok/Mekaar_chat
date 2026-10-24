import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  group('ChatBubble Modular Architecture Tests (Batch 4A)', () {
    testWidgets('renders standard text message and timestamp', (tester) async {
      final msg = Message(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'Halo, ini pesan teks uji modular.',
        type: MessageType.text,
        createdAt: DateTime(2026, 10, 24, 10, 15),
        updatedAt: DateTime(2026, 10, 24, 10, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Halo, ini pesan teks uji modular.'), findsOneWidget);
      expect(find.text('10:15'), findsOneWidget);
    });

    testWidgets('renders system notification message with semantics',
        (tester) async {
      final msg = Message(
        id: 'sys_1',
        roomId: 'room_1',
        senderId: 'system',
        content: 'Sesi obrolan aman terenkripsi E2EE.',
        type: MessageType.system,
        createdAt: DateTime(2026, 10, 24, 10, 0),
        updatedAt: DateTime(2026, 10, 24, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sesi obrolan aman terenkripsi E2EE.'), findsOneWidget);
    });

    testWidgets('ReadReceiptIcon renders correct icon & color for each status',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ReadReceiptIcon(
                  status: ReadReceiptStatus.pending,
                  color: Colors.grey,
                ),
                ReadReceiptIcon(
                  status: ReadReceiptStatus.sent,
                  color: Colors.grey,
                ),
                ReadReceiptIcon(
                  status: ReadReceiptStatus.delivered,
                  color: Colors.grey,
                ),
                ReadReceiptIcon(
                  status: ReadReceiptStatus.read,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.length, 4);
      // Status read uses MekaarColors.readReceiptGreen
      expect(icons[3].color, MekaarColors.readReceiptGreen);
    });

    testWidgets(
        're-exported helper functions parseMediaPayload and ViewOnceStore',
        (tester) async {
      final plainMsg = Message(
        id: 'media_plain',
        roomId: 'room_1',
        senderId: 'user_1',
        content: 'raw_key_123',
        type: MessageType.image,
        isEncrypted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final plainParsed = parseMediaPayload(plainMsg);
      expect(plainParsed.fileKeyB64, 'raw_key_123');
      expect(plainParsed.caption, '');

      final jsonMsg = Message(
        id: 'media_json',
        roomId: 'room_1',
        senderId: 'user_1',
        content: '{"key":"json_key_456","caption":"Foto pemandangan"}',
        type: MessageType.image,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final jsonParsed = parseMediaPayload(jsonMsg);
      expect(jsonParsed.fileKeyB64, 'json_key_456');
      expect(jsonParsed.caption, 'Foto pemandangan');

      // Test ViewOnceStore
      expect(await ViewOnceStore.isViewed('never_viewed_id'), false);
      await ViewOnceStore.markViewed('test_viewed_id');
      expect(await ViewOnceStore.isViewed('test_viewed_id'), true);
    });

    testWidgets('renders FileBubbleCard cleanly for document messages',
        (tester) async {
      final meta = const FileAttachmentMeta(
        fileName: 'laporan_keamanan.pdf',
        fileSize: 1024 * 500,
        caption: 'Berkas laporan',
      );

      final fileMsg = Message(
        id: 'file_msg_1',
        roomId: 'room_1',
        senderId: 'user_1',
        content: meta.toContentJson(),
        type: MessageType.file,
        createdAt: DateTime(2026, 10, 24, 11, 0),
        updatedAt: DateTime(2026, 10, 24, 11, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: fileMsg,
                isMe: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('laporan_keamanan.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Berkas laporan'), findsOneWidget);
    });
  });
}
