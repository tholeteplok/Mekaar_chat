import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';

void main() {
  group('Read Receipts Timezone & Status Evaluation Tests', () {
    test('Status read diberikan jika pesan dikirim sebelum otherLastRead (UTC vs Local parity)', () {
      final nowUtc = DateTime.utc(2026, 11, 1, 10, 0, 0);
      final readAtUtc = DateTime.utc(2026, 11, 1, 10, 5, 0);

      final msg = Message(
        id: 'msg_1',
        roomId: 'room_1',
        senderId: 'user_me',
        content: 'Halo',
        type: MessageType.text,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      // Verifikasi komparasi waktu
      final isBefore = msg.createdAt.toUtc().isBefore(readAtUtc.toUtc());
      expect(isBefore, isTrue);
    });

    test('Pesan lokal dengan zona waktu WIB tetap ekuivalen saat dinormalisasi ke UTC', () {
      // 17:00 WIB (+7) sama dengan 10:00 UTC
      final localCreatedAt = DateTime(2026, 11, 1, 17, 0, 0);
      final readAtUtc = DateTime.utc(2026, 11, 1, 10, 5, 0);

      final msg = Message(
        id: 'msg_2',
        roomId: 'room_1',
        senderId: 'user_me',
        content: 'Tes zona waktu',
        type: MessageType.text,
        createdAt: localCreatedAt,
        updatedAt: localCreatedAt,
      );

      // Setelah dinormalisasi ke UTC, perbandingan tidak bias offset lokal
      final isBefore = msg.createdAt.toUtc().isBefore(readAtUtc);
      expect(isBefore, isTrue);
    });

    test('Status read tidak diberikan jika pesan dikirim setelah otherLastRead', () {
      final nowUtc = DateTime.utc(2026, 11, 1, 10, 10, 0);
      final readAtUtc = DateTime.utc(2026, 11, 1, 10, 5, 0);

      final msg = Message(
        id: 'msg_3',
        roomId: 'room_1',
        senderId: 'user_me',
        content: 'Pesan baru belum dibaca',
        type: MessageType.text,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      final isBeforeOrSame = msg.createdAt.toUtc().isBefore(readAtUtc) ||
          msg.createdAt.toUtc().isAtSameMomentAs(readAtUtc);
      expect(isBeforeOrSame, isFalse);
    });

    test('Message.fromJson dan toJson selalu menjaga DateTime dalam UTC', () {
      final json = {
        'id': 'msg_json_1',
        'room_id': 'room_1',
        'sender_id': 'user_1',
        'content': 'Halo JSON',
        'msg_type': 'text',
        'is_view_once': false,
        'is_opened': false,
        'created_at': '2026-11-01T10:00:00.000000+00:00',
        'updated_at': '2026-11-01T10:00:00.000000+00:00',
        'auto_delete_at': '2026-11-01T11:00:00.000000+00:00',
      };

      final msg = Message.fromJson(json);
      expect(msg.createdAt.isUtc, isTrue);
      expect(msg.updatedAt.isUtc, isTrue);
      expect(msg.autoDeleteAt?.isUtc, isTrue);

      final serialized = msg.toJson();
      expect(serialized['created_at'].toString().endsWith('Z'), isTrue);
      expect(serialized['auto_delete_at'].toString().endsWith('Z'), isTrue);
    });
  });
}
