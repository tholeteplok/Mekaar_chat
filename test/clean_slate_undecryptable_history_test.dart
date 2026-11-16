import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/strings.dart';
import 'package:mekaar_chat/core/utils/message_preview_resolver.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/services/e2ee_service.dart';

void main() {
  group('Clean Slate & Undecryptable History Sentinel Tests', () {
    test('1. undecryptableSentinel terpisah dari hiddenPreviewFallback ("Pesan baru")', () {
      expect(E2eeService.undecryptableSentinel, isNot('Pesan baru'));
      expect(E2eeService.undecryptableSentinel, '[mekaar_undecryptable_payload]');
      expect(MekaarCopy.hiddenPreviewFallback, 'Pesan baru');
    });

    test('2. isUndecryptable mengenali sentinel baru maupun legacy fallback', () {
      expect(E2eeService.isUndecryptable(E2eeService.undecryptableSentinel), isTrue);
      expect(E2eeService.isUndecryptable('[mekaar_undecryptable_payload]'), isTrue);
      expect(E2eeService.isUndecryptable('Pesan baru'), isTrue); // Legacy fallback safety
      expect(E2eeService.isUndecryptable('Halo apa kabar?'), isFalse);
      expect(E2eeService.isUndecryptable(null), isFalse);
      expect(E2eeService.isUndecryptable(''), isFalse);
    });

    test('3. Pesan tak terdekripsi tidak menampilkan "Pesan baru" pada preview obrolan', () {
      final undecryptableMsg = Message(
        id: 'msg-old-1',
        roomId: 'room-1',
        senderId: 'user-other',
        content: E2eeService.undecryptableSentinel,
        type: MessageType.text,
        createdAt: DateTime.utc(2026, 11, 15, 10, 0),
        updatedAt: DateTime.utc(2026, 11, 15, 10, 0),
        isEncrypted: true,
      );

      // Pastikan helper pengecekan mendeteksi pesan tak terdekripsi
      expect(E2eeService.isUndecryptable(undecryptableMsg.content), isTrue);

      // Verifikasi bahwa preview bersih jatuh ke 'Mulai percakapan...' jika tak ada teks valid
      final preview = undecryptableMsg.content.isNotEmpty &&
              !E2eeService.isUndecryptable(undecryptableMsg.content)
          ? MessagePreviewResolver.formatChatListPreview(
              type: undecryptableMsg.type,
              content: undecryptableMsg.content,
              isUnreadFromOther: true,
            )
          : 'Mulai percakapan...';

      expect(preview, equals('Mulai percakapan...'));
      expect(preview, isNot(contains('Pesan baru')));
    });

    test('4. Penyaringan pesan tak terdekripsi menghasilkan kanvas bersih (empty list)', () {
      final messages = [
        Message(
          id: 'msg-1',
          roomId: 'room-1',
          senderId: 'user-1',
          content: E2eeService.undecryptableSentinel,
          type: MessageType.text,
          createdAt: DateTime.utc(2026, 11, 15, 10, 0),
          updatedAt: DateTime.utc(2026, 11, 15, 10, 0),
          isEncrypted: true,
        ),
        Message(
          id: 'msg-2',
          roomId: 'room-1',
          senderId: 'user-2',
          content: '[mekaar_undecryptable_payload]',
          type: MessageType.text,
          createdAt: DateTime.utc(2026, 11, 15, 10, 1),
          updatedAt: DateTime.utc(2026, 11, 15, 10, 1),
          isEncrypted: true,
        ),
      ];

      final filteredMessages = messages
          .where((m) => !E2eeService.isUndecryptable(m.content))
          .toList();

      expect(filteredMessages, isEmpty);
    });

    test('5. Pesan baru yang berhasil didekripsi tetap tampil normal setelah clean slate', () {
      final messages = [
        Message(
          id: 'msg-old',
          roomId: 'room-1',
          senderId: 'user-1',
          content: E2eeService.undecryptableSentinel,
          type: MessageType.text,
          createdAt: DateTime.utc(2026, 11, 15, 10, 0),
          updatedAt: DateTime.utc(2026, 11, 15, 10, 0),
          isEncrypted: true,
        ),
        Message(
          id: 'msg-new',
          roomId: 'room-1',
          senderId: 'user-1',
          content: 'Halo, saya baru pasang ulang aplikasi!',
          type: MessageType.text,
          createdAt: DateTime.utc(2026, 11, 16, 12, 0),
          updatedAt: DateTime.utc(2026, 11, 16, 12, 0),
          isEncrypted: true,
        ),
      ];

      final filteredMessages = messages
          .where((m) => !E2eeService.isUndecryptable(m.content))
          .toList();

      expect(filteredMessages.length, equals(1));
      expect(filteredMessages.first.id, equals('msg-new'));
      expect(filteredMessages.first.content, equals('Halo, saya baru pasang ulang aplikasi!'));
    });
  });
}
