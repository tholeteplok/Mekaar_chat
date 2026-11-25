import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StubSupabaseClient extends Fake implements SupabaseClient {}

class _StubSupabaseService implements SupabaseService {
  @override
  String? get currentUserId => 'user_me';

  @override
  SupabaseClient get client => _StubSupabaseClient();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatRepository 0ms Bridge & Instant Sync Tests', () {
    test('ingestIncomingMessage menyuntikkan pesan baru ke pool aktif & controller secara instan (0ms)', () async {
      final repo = ChatRepository(_StubSupabaseService());
      final controller = StreamController<List<Message>>.broadcast();
      final pool = <String, Message>{};
      const roomId = 'room_sync_1';

      repo.activeRoomControllers[roomId] = controller;
      repo.activeRoomMessagePools[roomId] = pool;

      final emittedBatches = <List<Message>>[];
      final sub = controller.stream.listen(emittedBatches.add);

      final t1 = DateTime.utc(2026, 11, 25, 10, 0, 0);
      final t2 = DateTime.utc(2026, 11, 25, 10, 0, 5);

      repo.ingestIncomingMessage(
        Message(
          id: 'msg_2',
          roomId: roomId,
          senderId: 'peer_1',
          type: MessageType.text,
          content: 'Pesan kedua',
          createdAt: t2,
          updatedAt: t2,
          isEncrypted: true,
        ),
      );
      repo.ingestIncomingMessage(
        Message(
          id: 'msg_1',
          roomId: roomId,
          senderId: 'peer_1',
          type: MessageType.text,
          content: 'Pesan pertama',
          createdAt: t1,
          updatedAt: t1,
          isEncrypted: true,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(emittedBatches.length, 2);
      expect(emittedBatches.last.map((m) => m.id).toList(), ['msg_1', 'msg_2']);
      expect(repo.decryptedContentCache['msg_1'], 'Pesan pertama');
      expect(repo.decryptedContentCache['msg_2'], 'Pesan kedua');

      await sub.cancel();
      await controller.close();
      repo.clearSessionCaches();
    });

    test('ingestIncomingMessage menjaga urutan updatedAt yang lebih baru dan menangani isSilentDeleted', () async {
      final repo = ChatRepository(_StubSupabaseService());
      final controller = StreamController<List<Message>>.broadcast();
      final pool = <String, Message>{};
      const roomId = 'room_sync_2';

      repo.activeRoomControllers[roomId] = controller;
      repo.activeRoomMessagePools[roomId] = pool;

      final emittedBatches = <List<Message>>[];
      final sub = controller.stream.listen(emittedBatches.add);

      final created = DateTime.utc(2026, 11, 25, 10, 0, 0);
      final newerEdit = DateTime.utc(2026, 11, 25, 10, 1, 0);
      final staleUpdate = DateTime.utc(2026, 11, 25, 10, 0, 30);

      repo.ingestIncomingMessage(
        Message(
          id: 'msg_edit',
          roomId: roomId,
          senderId: 'peer_1',
          type: MessageType.text,
          content: 'Versi terbaru',
          createdAt: created,
          updatedAt: newerEdit,
        ),
      );
      // Update basi tidak boleh menimpa versi terbaru
      repo.ingestIncomingMessage(
        Message(
          id: 'msg_edit',
          roomId: roomId,
          senderId: 'peer_1',
          type: MessageType.text,
          content: 'Versi lama',
          createdAt: created,
          updatedAt: staleUpdate,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(pool['msg_edit']?.content, 'Versi terbaru');

      // Silent delete langsung mengeviksi pesan
      repo.ingestIncomingMessage(
        Message(
          id: 'msg_edit',
          roomId: roomId,
          senderId: 'peer_1',
          type: MessageType.text,
          content: '',
          createdAt: created,
          updatedAt: DateTime.utc(2026, 11, 25, 10, 2, 0),
          isSilentDeleted: true,
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(pool.containsKey('msg_edit'), isFalse);
      expect(emittedBatches.last, isEmpty);

      await sub.cancel();
      await controller.close();
      repo.clearSessionCaches();
    });

    test('syncRoomMessagesNow menduplikasi-cegah eksekusi serentak & reconnectActiveRoomStreams memicu forceResubscribe', () async {
      final repo = ChatRepository(_StubSupabaseService());
      int callCount = 0;
      bool? lastForceFlag;
      final completer = Completer<void>();

      repo.activeRoomSyncCallbacks['room_a'] = ({bool forceResubscribe = false}) {
        callCount++;
        lastForceFlag = forceResubscribe;
        if (!completer.isCompleted) {
          return completer.future;
        }
        return Future<void>.value();
      };

      final f1 = repo.syncRoomMessagesNow('room_a');
      final f2 = repo.syncRoomMessagesNow('room_a');

      expect(callCount, 1);
      completer.complete();
      await Future.wait([f1, f2]);

      await repo.reconnectActiveRoomStreams();
      expect(callCount, 2);
      expect(lastForceFlag, isTrue);

      repo.clearSessionCaches();
      expect(repo.activeRoomSyncCallbacks, isEmpty);
    });
  });
}
