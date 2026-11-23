import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/mekaar_text_encoding.dart';
import 'package:mekaar_chat/core/utils/message_preview_resolver.dart';
import 'package:mekaar_chat/core/widgets/avatar.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:mekaar_chat/core/widgets/mekaar_link_text.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P1 — Grapheme-Safe Initial & Avatar', () {
    test('firstGrapheme menjaga grapheme cluster emoji dan bendera tetap utuh', () {
      expect(MekaarTextEncoding.firstGrapheme('💬'), '💬');
      expect(MekaarTextEncoding.firstGrapheme('🇮🇩 Indonesia'), '🇮🇩');
      expect(MekaarTextEncoding.firstGrapheme('salma'), 'S');
      expect(MekaarTextEncoding.firstGrapheme('\u200B  budi'), 'B');
      expect(MekaarTextEncoding.firstGrapheme('   '), '?');
      expect(MekaarTextEncoding.firstGrapheme(null, fallback: '💬'), '💬');
    });

    testWidgets('Avatar widget merender emoji dan bendera tanpa memotong surrogate pair', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Avatar(initial: '💬'),
                Avatar(initial: '🇮🇩 Indonesia'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('💬'), findsOneWidget);
      expect(find.text('🇮🇩'), findsOneWidget);
    });
  });

  group('P2 — Anti-Bidi Spoofing & Unpaired Surrogates', () {
    test('FileAttachmentMeta.fromContent menyanitasi karakter RLO Bidi pada file_name', () {
      const payload = '{"file_name":"bukti_\\u202Efdp.apk","file_size":2048}';
      final meta = FileAttachmentMeta.fromContent(payload);

      expect(meta.fileName, 'bukti_fdp.apk');
      expect(meta.fileName.contains('\u202E'), isFalse);
      expect(MessagePreviewResolver.isRecognizedDocument(meta.fileName), isFalse);
    });

    test('MessagePreviewResolver.isRecognizedDocument kebal terhadap karakter Bidi tersembunyi', () {
      expect(
        MessagePreviewResolver.isRecognizedDocument('laporan_\u202Efdp.exe'),
        isFalse,
      );
      expect(
        MessagePreviewResolver.isRecognizedDocument('laporan\u200B.pdf'),
        isTrue,
      );
    });

    test('sanitizeUnpairedSurrogates mengganti surrogate yatim dengan U+FFFD', () {
      final broken = String.fromCharCodes([0x0041, 0xD83D, 0x0042, 0xDC00]);
      final sanitized = MekaarTextEncoding.sanitizeUnpairedSurrogates(broken);

      expect(sanitized, 'A\uFFFDB\uFFFD');
      expect(() => utf8.encode(sanitized), returnsNormally);
    });
  });

  group('P3 — Multi-Encoding Byte Decoder (decodeBytes)', () {
    test('mendekode UTF-8 biasa dan UTF-8 dengan BOM', () {
      final utf8Bytes = utf8.encode('Halo MEKAAR 🔐');
      final utf8BomBytes = [0xEF, 0xBB, 0xBF, ...utf8Bytes];

      expect(MekaarTextEncoding.decodeBytes(utf8Bytes), 'Halo MEKAAR 🔐');
      expect(MekaarTextEncoding.decodeBytes(utf8BomBytes), 'Halo MEKAAR 🔐');
    });

    test('mendekode UTF-16 LE BOM dan UTF-16 BE BOM', () {
      // "Hi" -> UTF-16 LE: FF FE 48 00 69 00
      final utf16LeBom = [0xFF, 0xFE, 0x48, 0x00, 0x69, 0x00];
      // "Hi" -> UTF-16 BE: FE FF 00 48 00 69
      final utf16BeBom = [0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69];

      expect(MekaarTextEncoding.decodeBytes(utf16LeBom), 'Hi');
      expect(MekaarTextEncoding.decodeBytes(utf16BeBom), 'Hi');
    });

    test('mendekode UTF-16 LE/BE tanpa BOM melalui deteksi heuristik', () {
      // "ABCD" UTF-16 LE tanpa BOM
      final utf16LeNoBom = [0x41, 0x00, 0x42, 0x00, 0x43, 0x00, 0x44, 0x00];
      // "ABCD" UTF-16 BE tanpa BOM
      final utf16BeNoBom = [0x00, 0x41, 0x00, 0x42, 0x00, 0x43, 0x00, 0x44];

      expect(MekaarTextEncoding.decodeBytes(utf16LeNoBom), 'ABCD');
      expect(MekaarTextEncoding.decodeBytes(utf16BeNoBom), 'ABCD');
    });

    test('fallback Windows-1252 (CP1252) & Latin-1 saat bukan UTF-8 valid', () {
      // Bytes CP1252: 0x80 (€), 0x93 (“), 0x41 (A), 0x94 (”), 0xE9 (é)
      final cp1252Bytes = [0x80, 0x20, 0x93, 0x41, 0x94, 0x20, 0xE9];
      expect(MekaarTextEncoding.decodeBytes(cp1252Bytes), '€ “A” é');
    });
  });

  group('P4 — Unicode 15+ Jumbo Emoji & Adaptive RTL/LTR', () {
    testWidgets('ChatBubble merender emoji Unicode 15+ dan keycap dalam ukuran jumbo', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 23, 8, 0);

      for (final emoji in ['🫶', '🫡', '🩵', '1️⃣']) {
        final msg = Message(
          id: 'msg_$emoji',
          roomId: 'room_1',
          senderId: 'user_1',
          content: emoji,
          type: MessageType.text,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ChatBubble(
                  message: msg,
                  isMe: true,
                  animateEntrance: false,
                ),
              ),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text(emoji));
        expect(
          textWidget.style?.fontSize,
          52.0,
          reason: 'Emoji $emoji seharusnya tampil sebagai jumbo emoji (52.0)',
        );
      }
    });

    testWidgets('ChatBubble TIDAK membesarkan angka biasa seperti 123', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 23, 8, 0);
      final msg = Message(
        id: 'msg_num',
        roomId: 'room_1',
        senderId: 'user_1',
        content: '123',
        type: MessageType.text,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatBubble(
                message: msg,
                isMe: true,
                animateEntrance: false,
              ),
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('123'));
      expect(textWidget.style?.fontSize, isNot(52.0));
    });

    test('detectTextDirection mengenali RTL (Arab) dan LTR (Indonesia/Latin)', () {
      expect(
        MekaarTextEncoding.detectTextDirection('السلام عليكم'),
        TextDirection.rtl,
      );
      expect(
        MekaarTextEncoding.detectTextDirection('  123 السلام'),
        TextDirection.rtl,
      );
      expect(
        MekaarTextEncoding.detectTextDirection('Halo apa kabar'),
        TextDirection.ltr,
      );
    });

    testWidgets('MekaarLinkText menerapkan TextDirection.rtl untuk pesan Arab', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MekaarLinkText(
                  text: 'السلام عليكم',
                  baseStyle: TextStyle(fontSize: 16),
                ),
                MekaarLinkText(
                  text: 'Halo MEKAAR',
                  baseStyle: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );

      final arabicText = tester.widget<Text>(find.text('السلام عليكم'));
      final latinText = tester.widget<Text>(find.text('Halo MEKAAR'));

      expect(arabicText.textDirection, TextDirection.rtl);
      expect(latinText.textDirection, TextDirection.ltr);
    });
  });
}
