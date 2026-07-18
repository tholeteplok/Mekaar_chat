import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';

void main() {
  group('SOSState', () {
    test('hanya sesi terkonfirmasi berstatus active', () {
      final session = SOSSession(
        id: 'sos-1',
        userId: 'user-1',
        startedAt: DateTime(2026),
        status: 'active',
        createdAt: DateTime(2026),
      );

      expect(SOSState(activeSession: session).isSOSActive, isFalse);
      expect(
        SOSState(status: SOSStatus.active, activeSession: session).isSOSActive,
        isTrue,
      );
    });

    test('queued offline tidak dianggap sebagai sesi aktif', () {
      final state = SOSState(
        status: SOSStatus.queuedOffline,
        message: 'Menunggu koneksi',
      );

      expect(state.isSOSActive, isFalse);
      expect(state.message, 'Menunggu koneksi');
    });

    test('copyWith dapat membersihkan sesi dan pesan', () {
      final session = SOSSession(
        id: 'sos-1',
        userId: 'user-1',
        startedAt: DateTime(2026),
        status: 'active',
        createdAt: DateTime(2026),
      );
      final state = SOSState(
        status: SOSStatus.active,
        activeSession: session,
        message: 'Pesan lama',
      );

      final cleared = state.copyWith(
        status: SOSStatus.idle,
        clearActiveSession: true,
        clearMessage: true,
      );

      expect(cleared.status, SOSStatus.idle);
      expect(cleared.activeSession, isNull);
      expect(cleared.message, isNull);
    });
  });
}
