import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/message_preview_resolver.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';

void main() {
  group('MessagePreviewResolver', () {
    test('isRecognizedDocument detects standard doc extensions', () {
      expect(MessagePreviewResolver.isRecognizedDocument('laporan.pdf'), isTrue);
      expect(MessagePreviewResolver.isRecognizedDocument('document.docx'), isTrue);
      expect(MessagePreviewResolver.isRecognizedDocument('data.xlsx'), isTrue);
      expect(MessagePreviewResolver.isRecognizedDocument('archive.zip'), isTrue);
      expect(MessagePreviewResolver.isRecognizedDocument('notes.txt'), isTrue);

      // Unrecognized file types (e.g., .md, .bin, .apk, no extension)
      expect(MessagePreviewResolver.isRecognizedDocument('README_github.md'), isFalse);
      expect(MessagePreviewResolver.isRecognizedDocument('firmware.bin'), isFalse);
      expect(MessagePreviewResolver.isRecognizedDocument('app.apk'), isFalse);
      expect(MessagePreviewResolver.isRecognizedDocument('unknown'), isFalse);
      expect(MessagePreviewResolver.isRecognizedDocument(null), isFalse);
      expect(MessagePreviewResolver.isRecognizedDocument(''), isFalse);
    });

    test('formatChatListPreview displays Dokumen for recognized extensions', () {
      final jsonPdf = '{"key":"abc","file_name":"laporan.pdf","file_size":1024}';
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.file,
          content: jsonPdf,
          isUnreadFromOther: false,
        ),
        '📄 Dokumen',
      );
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.file,
          content: jsonPdf,
          isUnreadFromOther: true,
        ),
        '📄 Dokumen baru',
      );
    });

    test('formatChatListPreview displays Berkas for unrecognized file types (.md, etc.)', () {
      // Skenario screenshot user: file README_github.md
      final jsonMd = '{"key":"int5wR06DpxksJ7qMhb...","file_name":"README_github.md","file_size":9900}';
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.file,
          content: jsonMd,
          isUnreadFromOther: false,
        ),
        '📎 Berkas',
      );
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.file,
          content: jsonMd,
          isUnreadFromOther: true,
        ),
        '📎 Berkas baru',
      );

      // String raw JSON dengan rawMsgType
      expect(
        MessagePreviewResolver.formatChatListPreview(
          rawMsgType: 'file',
          content: jsonMd,
          isUnreadFromOther: false,
        ),
        '📎 Berkas',
      );
    });

    test('formatChatListPreview displays caption if present for media payload', () {
      final jsonWithCaption = '{"key":"xyz","caption":"Ini catatan penting"}';
      expect(
        MessagePreviewResolver.formatChatListPreview(
          type: MessageType.image,
          content: jsonWithCaption,
        ),
        'Ini catatan penting',
      );
    });

    test('formatChatListPreview prevents raw JSON leak when payload is raw key', () {
      final rawKeyJson = '{"key":"int5wR06DpxksJ7qMhb..."}';
      final result = MessagePreviewResolver.formatChatListPreview(
        content: rawKeyJson,
      );
      expect(result.contains('{"key":'), isFalse);
      expect(result, '📎 Berkas');
    });

    test('sanitizeLastMessage guards against corrupted or raw JSON strings', () {
      final rawJson = '{"key":"int5wR06DpxksJ7qMhb...","file_name":"README_github.md"}';
      expect(MessagePreviewResolver.sanitizeLastMessage(rawJson), '📎 Berkas');

      final rawPdf = '{"key":"xyz","file_name":"proposal.pdf"}';
      expect(MessagePreviewResolver.sanitizeLastMessage(rawPdf), '📄 Dokumen');

      expect(MessagePreviewResolver.sanitizeLastMessage(rawJson, isStealth: true), '••••••••');
      expect(MessagePreviewResolver.sanitizeLastMessage('Halo dunia'), 'Halo dunia');
    });

    test('MessageNotificationListener formatNotificationBody formats file properly', () {
      final recognizedPayload = '{"file_name":"laporan.docx"}';
      final unrecognizedPayload = '{"file_name":"README.md"}';

      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'file',
          content: recognizedPayload,
        ),
        '📎 Dokumen',
      );

      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'file',
          content: unrecognizedPayload,
        ),
        '📎 Berkas',
      );
    });
  });
}
