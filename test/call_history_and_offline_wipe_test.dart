import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/call_model.dart';
import 'package:mekaar_chat/data/repositories/call_repository.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeCallSupabaseClient extends SupabaseClient {
  FakeCallSupabaseClient() : super('http://localhost:8000', 'dummy_anon_key');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallModel & Local Calls Offline-First Tests', () {
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
              'columns': [
                'id',
                'room_id',
                'caller_id',
                'receiver_id',
                'call_type',
                'status',
                'started_at',
                'ended_at',
                'duration_seconds',
                'created_at',
                'updated_at',
                'scheduled_wipe_mode',
                'scheduled_wipe_time',
                'scheduled_wipe_target_at',
              ],
              'rows': []
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
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('CallModel serialization and deserialization retains all fields', () {
      final now = DateTime.now().toUtc();
      final call = CallModel(
        id: 'call_test_001',
        roomId: 'room_call_001',
        callerId: 'user_caller',
        receiverId: 'user_receiver',
        callType: 'voice',
        status: 'ended',
        startedAt: now.subtract(const Duration(minutes: 5)),
        endedAt: now,
        durationSeconds: 300,
        createdAt: now.subtract(const Duration(minutes: 6)),
        updatedAt: now,
      );

      final jsonMap = call.toJson();
      expect(jsonMap['id'], 'call_test_001');
      expect(jsonMap['room_id'], 'room_call_001');
      expect(jsonMap['duration_seconds'], 300);

      final restored = CallModel.fromJson(jsonMap);
      expect(restored.id, call.id);
      expect(restored.roomId, call.roomId);
      expect(restored.durationSeconds, 300);
      expect(restored.isConnected, isTrue);
      expect(restored.formattedDuration, '05:00');
    });

    test('CallRepository.streamCalls returns a stream without throwing', () {
      final client = FakeCallSupabaseClient();
      final repo = CallRepository(client);
      final stream = repo.streamCalls('room_call_test');
      expect(stream, isA<Stream<List<CallModel>>>());
    });

    test('MessageNotificationListener formatPreviewText returns generic preview for encrypted message', () {
      final previewEncrypted = MessageNotificationListener.formatPreviewText(
        msgType: 'text',
        content: '{"ct":"encrypted_payload"}',
        isEncrypted: true,
        isFromOtherUser: true,
      );
      expect(previewEncrypted, 'Pesan baru');

      final previewEncryptedSelf = MessageNotificationListener.formatPreviewText(
        msgType: 'text',
        content: '{"ct":"encrypted_payload"}',
        isEncrypted: true,
        isFromOtherUser: false,
      );
      expect(previewEncryptedSelf, '••••••••');

      final previewPlaintext = MessageNotificationListener.formatPreviewText(
        msgType: 'text',
        content: 'Halo teman!',
        isEncrypted: false,
        isFromOtherUser: true,
      );
      expect(previewPlaintext, 'Halo teman!');
    });

    test('LocalMessageDatabase call and wipe helper methods execute safely', () async {
      final now = DateTime.now().toUtc();
      final call = CallModel(
        id: 'call_test_offline',
        roomId: 'room_offline_001',
        callerId: 'user_a',
        receiverId: 'user_b',
        callType: 'video',
        status: 'ended',
        createdAt: now,
        updatedAt: now,
      );

      // Verify no exceptions on database operations
      await expectLater(LocalMessageDatabase.instance.saveCall(call), completes);
      await expectLater(LocalMessageDatabase.instance.saveCalls([call]), completes);
      await expectLater(LocalMessageDatabase.instance.getCallsForRoom('room_offline_001'), completes);
      await expectLater(LocalMessageDatabase.instance.deleteCall('call_test_offline'), completes);
      await expectLater(LocalMessageDatabase.instance.deleteRoomCalls('room_offline_001'), completes);

      // Verify scheduled wipe cache methods
      await expectLater(
        LocalMessageDatabase.instance.saveRoomScheduledWipe(
          roomId: 'room_offline_001',
          mode: 'daily',
          timeString: '14:00:00',
          targetAtUtc: now.add(const Duration(hours: 4)),
        ),
        completes,
      );
      await expectLater(
        LocalMessageDatabase.instance.getRoomScheduledWipe('room_offline_001'),
        completes,
      );
      await expectLater(
        LocalMessageDatabase.instance.executeRoomScheduledWipeLocal('room_offline_001', now),
        completes,
      );
      await expectLater(
        LocalMessageDatabase.instance.updateRoomCacheLastMessage(
          roomId: 'room_offline_001',
          previewText: 'Halo',
          timestamp: now,
          unreadCount: 1,
        ),
        completes,
      );
    });
  });
}
