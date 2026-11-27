import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/core/constants/media_attachment_limits.dart';
import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/core/widgets/bubbles/bubble_media_helper.dart';
import 'package:mekaar_chat/core/widgets/bubbles/media_album_bubble.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/handlers/chat_media_handler.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_message_list_view.dart';
import 'package:mekaar_chat/features/chat/widgets/document_send_preview_sheet.dart';
import 'package:mekaar_chat/features/chat/widgets/image_send_preview_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  late Directory tempDir;
  late List<File> sampleImages;
  late List<File> sampleDocs;

  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('mekaar_multi_attach_');
    sampleImages = List.generate(
      4,
      (i) => File('${tempDir.path}/img_$i.png')..writeAsBytesSync(pngBytes),
    );
    sampleDocs = List.generate(
      3,
      (i) => File('${tempDir.path}/doc_$i.pdf')..writeAsStringSync('pdf_$i'),
    );
  });

  tearDownAll(() async {
    clearDecryptedMemoryCacheForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MediaAttachmentLimits (Ultra Ketat)', () {
    test('Memvalidasi batas jumlah, 10 MB/file, dan total 20 MB/batch', () {
      final items = [
        (name: 'a.jpg', size: 6 * 1024 * 1024),
        (name: 'b.jpg', size: 11 * 1024 * 1024), // > 10 MB (ditolak)
        (name: 'c.jpg', size: 8 * 1024 * 1024),
        (name: 'd.jpg', size: 8 * 1024 * 1024), // total > 20 MB (ditolak)
        (name: 'e.jpg', size: 1 * 1024 * 1024), // > max 4 item (dilewati)
      ];

      final res = MediaAttachmentLimits.validateBatch(
        items: items,
        sizeOf: (e) => e.size,
        nameOf: (e) => e.name,
        maxItems: MediaAttachmentLimits.maxImagesPerBatch,
      );

      expect(res.accepted.map((e) => e.name).toList(), ['a.jpg', 'c.jpg']);
      expect(res.warnings.length, 3);
    });

    test('Membatasi dokumen maksimal 3 berkas per batch', () {
      final docs = List.generate(5, (i) => (name: 'f$i.pdf', size: 1024));
      final res = MediaAttachmentLimits.validateBatch(
        items: docs,
        sizeOf: (e) => e.size,
        nameOf: (e) => e.name,
        maxItems: MediaAttachmentLimits.maxDocumentsPerBatch,
      );

      expect(res.accepted.length, 3);
      expect(res.warnings.length, 1);
    });
  });

  group('Payload Album E2EE & Pengelompokan ChatMessageListView', () {
    test('buildImageContentPayload & parseMediaPayload menjaga kompatibilitas mundur + album_id', () {
      final albumPayload = ChatMediaHandler.buildImageContentPayload(
        fileKeyB64: 'key_abc',
        caption: 'Liburan aman',
        albumId: 'album-123',
      );
      final parsedAlbum = parseMediaPayload(
        Message(
          id: 'm1',
          roomId: 'r1',
          senderId: 'u1',
          content: albumPayload,
          type: MessageType.image,
          isEncrypted: true,
          createdAt: DateTime.utc(2026, 11, 27, 10, 0),
          updatedAt: DateTime.utc(2026, 11, 27, 10, 0),
        ),
      );
      expect(parsedAlbum.fileKeyB64, 'key_abc');
      expect(parsedAlbum.caption, 'Liburan aman');
      expect(parsedAlbum.albumId, 'album-123');

      final legacyPayload = ChatMediaHandler.buildImageContentPayload(
        fileKeyB64: 'raw_key_only',
      );
      expect(legacyPayload, 'raw_key_only');
    });

    test('buildItemEntries mengelompokkan 3 foto album berurutan menjadi 1 mediaAlbum oldest->newest', () {
      final msgs = [
        Message(
          id: 'p1',
          roomId: 'r1',
          senderId: 'u1',
          content: '{"key":"k1","caption":"Album uji","album_id":"alb-1"}',
          type: MessageType.image,
          isEncrypted: true,
          createdAt: DateTime.utc(2026, 11, 27, 10, 0, 1),
          updatedAt: DateTime.utc(2026, 11, 27, 10, 0, 1),
        ),
        Message(
          id: 'p2',
          roomId: 'r1',
          senderId: 'u1',
          content: '{"key":"k2","album_id":"alb-1"}',
          type: MessageType.image,
          isEncrypted: true,
          createdAt: DateTime.utc(2026, 11, 27, 10, 0, 2),
          updatedAt: DateTime.utc(2026, 11, 27, 10, 0, 2),
        ),
        Message(
          id: 'p3',
          roomId: 'r1',
          senderId: 'u1',
          content: '{"key":"k3","album_id":"alb-1"}',
          type: MessageType.image,
          isEncrypted: true,
          createdAt: DateTime.utc(2026, 11, 27, 10, 0, 3),
          updatedAt: DateTime.utc(2026, 11, 27, 10, 0, 3),
        ),
        // Foto View Once dengan album_id tidak boleh digabung
        Message(
          id: 'p4_vo',
          roomId: 'r1',
          senderId: 'u1',
          content: '{"key":"k4","album_id":"alb-1"}',
          type: MessageType.image,
          isEncrypted: true,
          isViewOnce: true,
          createdAt: DateTime.utc(2026, 11, 27, 10, 0, 4),
          updatedAt: DateTime.utc(2026, 11, 27, 10, 0, 4),
        ),
      ];

      final entries = ChatMessageListView.buildItemEntries(msgs, const []);
      final albumEntries =
          entries.where((e) => e.kind == ChatItemKind.mediaAlbum).toList();
      final msgEntries =
          entries.where((e) => e.kind == ChatItemKind.message).toList();

      expect(albumEntries.length, 1);
      expect(albumEntries.first.albumMessages!.map((m) => m.id).toList(), [
        'p1',
        'p2',
        'p3',
      ]);
      expect(msgEntries.length, 1);
      expect(msgEntries.first.message!.id, 'p4_vo');
    });
  });

  group('Widget Pratinjau Multi-Item & MediaAlbumBubble', () {
    testWidgets(
      'ImageSendPreviewSheet.multi menampilkan counter, hapus item, nonaktif ViewOnce, dan kirim caption bersama',
      (tester) async {
        ImageSendResult? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: MekaarTheme.lightTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<ImageSendResult>(
                      MaterialPageRoute(
                        builder: (_) => ImageSendPreviewSheet.multi(
                          imageFiles: sampleImages.take(3).toList(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();

        expect(find.text('Pratinjau Foto (1/3)'), findsOneWidget);
        expect(find.text('(1)'), findsNothing);

        // Hapus foto aktif lewat tombol trash di AppBar
        await tester.tap(find.byIcon(SolarIconsOutline.trashBinMinimalistic));
        await tester.pumpAndSettle();

        expect(find.text('Pratinjau Foto (1/2)'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Caption album');
        await tester.tap(find.byIcon(SolarIconsBold.plain));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.files.length, 2);
        expect(result!.caption, 'Caption album');
        expect(result!.isViewOnce, isFalse);
      },
    );

    testWidgets(
      'DocumentSendPreviewSheet.multi menampilkan daftar dokumen, hapus item, dan kirim',
      (tester) async {
        DocumentSendResult? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: MekaarTheme.lightTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result =
                        await Navigator.of(context).push<DocumentSendResult>(
                      MaterialPageRoute(
                        builder: (_) => DocumentSendPreviewSheet.multi(
                          documents: [
                            DocumentDraftItem(
                              file: sampleDocs[0],
                              fileName: 'doc_0.pdf',
                              fileSize: 5,
                            ),
                            DocumentDraftItem(
                              file: sampleDocs[1],
                              fileName: 'doc_1.pdf',
                              fileSize: 5,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('BukaDoc'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('BukaDoc'));
        await tester.pumpAndSettle();

        expect(find.text('Kirim Dokumen (2/3)'), findsOneWidget);
        expect(find.text('doc_0.pdf'), findsOneWidget);
        expect(find.text('doc_1.pdf'), findsOneWidget);

        await tester.tap(find.byIcon(SolarIconsOutline.closeCircle).first);
        await tester.pumpAndSettle();

        expect(find.text('Kirim Dokumen'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Lampiran PDF');
        await tester.tap(find.byIcon(SolarIconsBold.plain2));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.items.length, 1);
        expect(result!.caption, 'Lampiran PDF');
      },
    );

    testWidgets('MediaAlbumBubble merender kolase 4 foto + caption bersama', (
      tester,
    ) async {
      final albumMsgs = List.generate(4, (i) {
        final id = 'alb_msg_$i';
        setDecryptedMemoryCacheForTesting(id, sampleImages[i]);
        return Message(
          id: id,
          roomId: 'room_alb',
          senderId: 'u1',
          content: i == 0
              ? '{"key":"k$i","caption":"Empat foto kolase","album_id":"a1"}'
              : '{"key":"k$i","album_id":"a1"}',
          mediaUrl: 'https://example.supabase.co/storage/v1/object/public/chat-media/blobs/$i.bin',
          type: MessageType.image,
          isEncrypted: true,
          createdAt: DateTime.utc(2026, 11, 27, 10, 0, i),
          updatedAt: DateTime.utc(2026, 11, 27, 10, 0, i),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: MekaarTheme.lightTheme(),
            home: Scaffold(
              body: Center(
                child: MediaAlbumBubble(
                  messages: albumMsgs,
                  isMe: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(4));
      expect(find.text('Empat foto kolase'), findsOneWidget);
    });
  });
}
