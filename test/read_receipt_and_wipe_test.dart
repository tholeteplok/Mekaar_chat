import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/bubbles/read_receipt_icon.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:mekaar_chat/features/chat/providers/chat_provider.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_list_tile.dart';

class _StubChatRepository extends ChatRepository {
  final List<Map<String, dynamic>> _rooms;

  _StubChatRepository(this._rooms) : super(SupabaseService());

  @override
  String? get currentUserId => 'user_me';

  @override
  Future<List<Map<String, dynamic>>> getCachedRooms() async => _rooms;

  @override
  Future<List<Map<String, dynamic>>> getRooms() async => _rooms;
}

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
      // Gunakan ISO-8601 dengan offset eksplisit agar kebal zona waktu OS runner CI (UTC)
      final localCreatedAt = DateTime.parse('2026-11-01T17:00:00+07:00');
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

  group('Chat List & Bubble Read Receipt Synchronization Tests', () {
    test('resolveChatListReceiptStatus paritas 1:1 dan grup', () {
      final msgTime = DateTime.utc(2026, 11, 26, 10, 0, 0);
      final readAfter = DateTime.utc(2026, 11, 26, 10, 1, 0);
      final readBefore = DateTime.utc(2026, 11, 26, 9, 59, 0);

      // 1. Pesan masih mengirim -> pending
      expect(
        resolveChatListReceiptStatus(
          isMe: true,
          isGroup: false,
          isSending: true,
          showReadReceipts: true,
          messageTime: msgTime,
          otherLastReadAt: readAfter,
        ),
        ReadReceiptStatus.pending,
      );

      // 2. Chat 1:1 dibaca -> read
      expect(
        resolveChatListReceiptStatus(
          isMe: true,
          isGroup: false,
          isSending: false,
          showReadReceipts: true,
          messageTime: msgTime,
          otherLastReadAt: readAfter,
        ),
        ReadReceiptStatus.read,
      );

      // 3. Chat 1:1 belum dibaca -> delivered
      expect(
        resolveChatListReceiptStatus(
          isMe: true,
          isGroup: false,
          isSending: false,
          showReadReceipts: true,
          messageTime: msgTime,
          otherLastReadAt: readBefore,
        ),
        ReadReceiptStatus.delivered,
      );

      // 4. Bukti baca nonaktif -> delivered
      expect(
        resolveChatListReceiptStatus(
          isMe: true,
          isGroup: false,
          isSending: false,
          showReadReceipts: false,
          messageTime: msgTime,
          otherLastReadAt: readAfter,
        ),
        ReadReceiptStatus.delivered,
      );

      // 5. Obrolan grup selalu delivered meskipun otherLastReadAt lebih baru
      expect(
        resolveChatListReceiptStatus(
          isMe: true,
          isGroup: true,
          isSending: false,
          showReadReceipts: true,
          messageTime: msgTime,
          otherLastReadAt: readAfter,
        ),
        ReadReceiptStatus.delivered,
      );
    });

    test('ChatRoomsNotifier.updateOtherLastReadLocally bersifat monotonik dan mengabaikan grup', () async {
      final t1 = DateTime.utc(2026, 11, 26, 10, 0, 0);
      final t2 = DateTime.utc(2026, 11, 26, 10, 5, 0);
      final tOlder = DateTime.utc(2026, 11, 26, 9, 50, 0);

      final repo = _StubChatRepository([
        {
          'id': 'room_direct',
          'isGroup': false,
          'otherLastReadAt': t1,
          'unreadCount': 0,
        },
        {
          'id': 'room_group',
          'isGroup': true,
          'otherLastReadAt': null,
          'unreadCount': 0,
        },
      ]);

      final notifier = ChatRoomsNotifier(repo);
      await Future<void>.delayed(Duration.zero);

      // Update ke waktu lebih baru -> diterima
      notifier.updateOtherLastReadLocally('room_direct', t2);
      expect(
        notifier.state.value!.firstWhere((r) => r['id'] == 'room_direct')['otherLastReadAt'],
        t2,
      );

      // Update ke waktu lebih lama -> diabaikan (monotonik)
      notifier.updateOtherLastReadLocally('room_direct', tOlder);
      expect(
        notifier.state.value!.firstWhere((r) => r['id'] == 'room_direct')['otherLastReadAt'],
        t2,
      );

      // Update ke grup -> diabaikan (tetap null)
      notifier.updateOtherLastReadLocally('room_group', t2);
      expect(
        notifier.state.value!.firstWhere((r) => r['id'] == 'room_group')['otherLastReadAt'],
        isNull,
      );

      notifier.dispose();
    });

    test('ChatRoomsNotifier.updateLastMessageLocally menyinkronkan transisi isSending dan timestamp server', () async {
      final localTime = DateTime.utc(2026, 11, 26, 10, 0, 0);
      final serverTime = DateTime.utc(2026, 11, 26, 10, 0, 2);

      final repo = _StubChatRepository([
        {
          'id': 'room_1',
          'isGroup': false,
          'lastMessage': 'Lama',
          'timestamp': DateTime.utc(2026, 11, 26, 9, 0, 0),
          'unreadCount': 0,
          'lastMessageSenderId': 'other',
          'lastMessageIsSending': false,
        },
      ]);

      final notifier = ChatRoomsNotifier(repo);
      await Future<void>.delayed(Duration.zero);

      notifier.updateLastMessageLocally(
        roomId: 'room_1',
        previewText: 'Pesan baru',
        timestamp: localTime,
        isFromOtherUser: false,
        isCurrentlyInRoom: true,
        isSending: true,
      );
      expect(notifier.state.value!.first['lastMessageIsSending'], isTrue);
      expect(notifier.state.value!.first['lastMessageSenderId'], 'user_me');

      notifier.updateLastMessageLocally(
        roomId: 'room_1',
        previewText: 'Pesan baru',
        timestamp: serverTime,
        isFromOtherUser: false,
        isCurrentlyInRoom: true,
        isSending: false,
      );
      expect(notifier.state.value!.first['lastMessageIsSending'], isFalse);
      expect(notifier.state.value!.first['timestamp'], serverTime);

      notifier.dispose();
    });

    test('LocalMessageDatabase serializeRoomForCache & deserializeRoomFromCache menjaga DateTime tanpa error JSON', () {
      final ts = DateTime.utc(2026, 11, 26, 10, 0, 0);
      final readAt = DateTime.utc(2026, 11, 26, 10, 5, 0);
      final room = <String, dynamic>{
        'id': 'room_cache_1',
        'name': 'Budi',
        'timestamp': ts,
        'otherLastReadAt': readAt,
        'lastReadAt': ts,
        'lastMessage': 'Halo',
        'lastMessageSenderId': 'user_me',
        'lastMessageIsSending': false,
      };

      final serialized = LocalMessageDatabase.serializeRoomForCache(room);
      final encoded = jsonEncode(serialized);
      final decodedJson = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = LocalMessageDatabase.deserializeRoomFromCache(decodedJson);

      expect(restored['id'], 'room_cache_1');
      expect(restored['otherLastReadAt'], isA<DateTime>());
      expect((restored['otherLastReadAt'] as DateTime).toUtc(), readAt);
      expect(restored['timestamp'], isA<DateTime>());
      expect((restored['timestamp'] as DateTime).toUtc(), ts);
      expect(restored['lastReadAt'], isA<DateTime>());
      expect((restored['lastReadAt'] as DateTime).toUtc(), ts);
    });
  });
}
