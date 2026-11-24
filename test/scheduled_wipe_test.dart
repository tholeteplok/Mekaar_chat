import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';
import 'package:mekaar_chat/features/chat/widgets/scheduled_wipe_bottom_sheet.dart';

void main() {
  group('ScheduledWipeResult Unit Tests', () {
    test('Inisialisasi mode off', () {
      const result = ScheduledWipeResult(mode: 'off');
      expect(result.mode, 'off');
      expect(result.time, isNull);
      expect(result.targetAtUtc, isNull);
    });

    test('Inisialisasi mode one_shot dengan time dan target UTC', () {
      final now = DateTime.now().toUtc();
      const time = TimeOfDay(hour: 14, minute: 0);
      final result = ScheduledWipeResult(
        mode: 'one_shot',
        time: time,
        targetAtUtc: now,
      );

      expect(result.mode, 'one_shot');
      expect(result.time?.hour, 14);
      expect(result.time?.minute, 0);
      expect(result.targetAtUtc, now);
    });

    test('Inisialisasi mode daily dengan time dan target UTC', () {
      final now = DateTime.now().toUtc();
      const time = TimeOfDay(hour: 20, minute: 30);
      final result = ScheduledWipeResult(
        mode: 'daily',
        time: time,
        targetAtUtc: now,
      );

      expect(result.mode, 'daily');
      expect(result.time?.hour, 20);
      expect(result.time?.minute, 30);
      expect(result.targetAtUtc, now);
    });
  });

  group('LocalMessageDatabase Scheduled Wipe Persistence & Purge Tests', () {
    const channel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
    final capturedCalls = <(String method, dynamic args)>[];

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({});
      capturedCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        capturedCalls.add((call.method, call.arguments));
        switch (call.method) {
          case 'getDatabasesPath':
            return '.';
          case 'openDatabase':
            return 1;
          case 'query':
          case 'rawQuery':
            final sql = (call.arguments as Map?)?['sql']?.toString() ?? '';
            if (sql.contains('scheduled_wipe_mode') &&
                sql.contains("scheduled_wipe_mode != 'off'")) {
              final pastIso = DateTime.now()
                  .toUtc()
                  .subtract(const Duration(minutes: 5))
                  .toIso8601String();
              return {
                'columns': [
                  'room_id',
                  'scheduled_wipe_mode',
                  'scheduled_wipe_time',
                  'scheduled_wipe_target_at',
                ],
                'rows': [
                  ['room_daily_1', 'daily', '12:00:00', pastIso],
                  ['room_oneshot_2', 'one_shot', '12:00:00', pastIso],
                ],
              };
            }
            if (sql.contains('FROM local_rooms_cache') &&
                sql.contains('scheduled_wipe_mode')) {
              final futureIso = DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 2))
                  .toIso8601String();
              return {
                'columns': [
                  'room_id',
                  'scheduled_wipe_mode',
                  'scheduled_wipe_time',
                  'scheduled_wipe_target_at',
                ],
                'rows': [
                  ['room_keep_wipe', 'daily', '22:00:00', futureIso],
                ],
              };
            }
            return {'columns': <String>[], 'rows': <List<dynamic>>[]};
          case 'batch':
            final ops = (call.arguments as Map?)?['operations'] as List?;
            return List.filled(ops?.length ?? 0, 1);
          case 'delete':
          case 'execute':
          case 'insert':
          case 'update':
          case 'closeDatabase':
            return 1;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('saveRoomsCache mempertahankan metadata scheduled_wipe jika tidak ada di payload', () async {
      await LocalMessageDatabase.instance.saveRoomsCache([
        {
          'id': 'room_keep_wipe',
          'name': 'Salma',
          'lastMessage': 'Halo',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      ]);

      final batchCall = capturedCalls.firstWhere((c) => c.$1 == 'batch');
      final ops = (batchCall.$2 as Map)['operations'] as List;
      final insertOp = ops.first as Map;
      final args = insertOp['arguments'] as List;
      expect(args, contains('daily'));
      expect(args, contains('22:00:00'));
    });

    test('purgeExpiredMessages mengeksekusi wipe untuk dueRooms dan memperbarui jadwal one_shot/daily', () async {
      final wipedRooms =
          await LocalMessageDatabase.instance.purgeExpiredMessages();

      expect(wipedRooms, containsAll(['room_daily_1', 'room_oneshot_2']));
      final updateCalls =
          capturedCalls.where((c) => c.$1 == 'update').toList();
      expect(
        updateCalls.any((c) {
          final args = c.$2 as Map;
          return args['sql'].toString().contains('local_rooms_cache') &&
              args['arguments'].toString().contains('off');
        }),
        isTrue,
      );
      expect(
        updateCalls.any((c) {
          final args = c.$2 as Map;
          return args['sql'].toString().contains('local_rooms_cache') &&
              args['arguments'].toString().contains('daily');
        }),
        isTrue,
      );
    });
  });
}
