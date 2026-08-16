import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
