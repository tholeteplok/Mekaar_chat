import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Disappearing Messages & Scheduled Wipe Real-Time Sync Tests', () {
    late ChatRepository repo;
    const testRoomId = 'test_room_sync_001';
    const channel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getDatabasesPath':
            return '.';
          case 'openDatabase':
            return 1;
          case 'query':
          case 'rawQuery':
            return {
              'columns': ['version'],
              'rows': [
                [1]
              ]
            };
          case 'delete':
          case 'execute':
          case 'insert':
          case 'update':
          case 'closeDatabase':
            return 0;
          default:
            return null;
        }
      });
      repo = ChatRepository(SupabaseService());
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('purgeExpiredMessages evicts expired messages from active room pool in real-time', () async {
      // Setup mock stream
      final controller = StreamController<List<Message>>();
      final messagePool = <String, Message>{};

      // Inisialisasi pool dan controller untuk ruangan aktif
      repo.activeRoomControllers[testRoomId] = controller;
      repo.activeRoomMessagePools[testRoomId] = messagePool;

      final now = DateTime.now().toUtc();

      // Pesan 1: Sudah kedaluwarsa 5 menit lalu (misal autoDeleteAt = now - 5m)
      final expiredMsg = Message(
        id: 'msg_expired_1',
        roomId: testRoomId,
        senderId: 'user_a',
        content: 'Pesan rahasia 1 jam yang sudah lewat waktu',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 5)),
        updatedAt: now.subtract(const Duration(hours: 1, minutes: 5)),
        autoDeleteAt: now.subtract(const Duration(minutes: 5)),
      );

      // Pesan 2: Belum kedaluwarsa (misal autoDeleteAt = now + 30m)
      final activeMsg = Message(
        id: 'msg_active_2',
        roomId: testRoomId,
        senderId: 'user_b',
        content: 'Pesan yang masih berlaku',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        autoDeleteAt: now.add(const Duration(minutes: 30)),
      );

      messagePool[expiredMsg.id] = expiredMsg;
      messagePool[activeMsg.id] = activeMsg;

      final emittedBatches = <List<Message>>[];
      controller.stream.listen(emittedBatches.add);

      // Jalankan purge proaktif pada ruangan yang sedang aktif
      await repo.purgeExpiredMessages(targetRoomId: testRoomId);

      // Verifikasi:
      // 1. Pesan kedaluwarsa langsung hilang dari memori RAM
      expect(messagePool.containsKey('msg_expired_1'), isFalse);
      expect(messagePool.containsKey('msg_active_2'), isTrue);
      expect(messagePool.length, equals(1));

      // 2. Stream controller memancarkan daftar pesan terbaru tanpa pesan kedaluwarsa
      await pumpEventQueue();
      expect(emittedBatches.isNotEmpty, isTrue);
      final latestBatch = emittedBatches.last;
      expect(latestBatch.length, equals(1));
      expect(latestBatch.first.id, equals('msg_active_2'));

      await controller.close();
      repo.activeRoomControllers.remove(testRoomId);
      repo.activeRoomMessagePools.remove(testRoomId);
    });

    test('executeRoomScheduledWipe flushes in-memory pool and emits empty list immediately', () async {
      final controller = StreamController<List<Message>>();
      final messagePool = <String, Message>{};

      repo.activeRoomControllers[testRoomId] = controller;
      repo.activeRoomMessagePools[testRoomId] = messagePool;

      final now = DateTime.now().toUtc();
      messagePool['msg_1'] = Message(
        id: 'msg_1',
        roomId: testRoomId,
        senderId: 'user_a',
        content: 'Pesan sebelum pembersihan jam 10',
        type: MessageType.text,
        createdAt: now.subtract(const Duration(minutes: 10)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
      );

      final emittedBatches = <List<Message>>[];
      controller.stream.listen(emittedBatches.add);

      // Panggil eksekusi pembersihan terjadwal
      await repo.executeRoomScheduledWipe(testRoomId);

      // Verifikasi pool RAM seketika kosong dan stream memancarkan []
      expect(messagePool.isEmpty, isTrue);
      await pumpEventQueue();
      expect(emittedBatches.isNotEmpty, isTrue);
      expect(emittedBatches.last, isEmpty);

      await controller.close();
      repo.activeRoomControllers.remove(testRoomId);
      repo.activeRoomMessagePools.remove(testRoomId);
    });
  });
}
