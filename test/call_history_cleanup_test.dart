import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/call_model.dart';

void main() {
  group('Call History Cleanup & Filter Tests', () {
    final now = DateTime.now().toUtc();
    final call1Past = CallModel(
      id: 'call_past_001',
      roomId: 'room_123',
      callerId: 'user_a',
      receiverId: 'user_b',
      callType: 'voice',
      status: 'ended',
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    );

    final call2JustBefore = CallModel(
      id: 'call_just_before_002',
      roomId: 'room_123',
      callerId: 'user_b',
      receiverId: 'user_a',
      callType: 'video',
      status: 'ended',
      createdAt: now.subtract(const Duration(minutes: 30)),
      updatedAt: now.subtract(const Duration(minutes: 30)),
    );

    final call3AfterClear = CallModel(
      id: 'call_new_after_clear_003',
      roomId: 'room_123',
      callerId: 'user_a',
      receiverId: 'user_b',
      callType: 'voice',
      status: 'ended',
      createdAt: now.add(const Duration(minutes: 5)),
      updatedAt: now.add(const Duration(minutes: 5)),
    );

    final List<CallModel> allCalls = [call1Past, call2JustBefore, call3AfterClear];

    List<CallModel> applyCallFilters(
      List<CallModel> calls, {
      DateTime? historyClearedAt,
      Set<String> hiddenCallIds = const {},
    }) {
      return calls.where((c) {
        if (hiddenCallIds.contains(c.id)) return false;
        if (historyClearedAt != null && !c.createdAt.isAfter(historyClearedAt)) {
          return false;
        }
        return true;
      }).toList();
    }

    test('Tanpa pembersihan riwayat, seluruh panggilan tampil', () {
      final result = applyCallFilters(allCalls);
      expect(result.length, 3);
    });

    test('Panggilan sebelum historyClearedAt terpotong dan tidak tampil', () {
      final historyClearedAt = now.subtract(const Duration(minutes: 10));

      final result = applyCallFilters(
        allCalls,
        historyClearedAt: historyClearedAt,
      );

      // Hanya call3AfterClear yang dibuat setelah historyClearedAt yang tampil
      expect(result.length, 1);
      expect(result.first.id, 'call_new_after_clear_003');
    });

    test('Panggilan di dalam hidden_calls tersembunyi', () {
      final hiddenSet = {'call_just_before_002'};

      final result = applyCallFilters(
        allCalls,
        hiddenCallIds: hiddenSet,
      );

      expect(result.length, 2);
      expect(result.any((c) => c.id == 'call_just_before_002'), isFalse);
      expect(result.any((c) => c.id == 'call_past_001'), isTrue);
      expect(result.any((c) => c.id == 'call_new_after_clear_003'), isTrue);
    });

    test('Kombinasi historyClearedAt dan hiddenCallIds menyaring dengan benar', () {
      final historyClearedAt = now.subtract(const Duration(hours: 1));
      final hiddenSet = {'call_new_after_clear_003'};

      final result = applyCallFilters(
        allCalls,
        historyClearedAt: historyClearedAt,
        hiddenCallIds: hiddenSet,
      );

      // call1Past dipotong oleh historyClearedAt
      // call3AfterClear dipotong oleh hiddenSet
      // Tersisa call2JustBefore
      expect(result.length, 1);
      expect(result.first.id, 'call_just_before_002');
    });
  });
}
