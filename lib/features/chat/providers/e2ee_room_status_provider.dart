import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/e2ee_service.dart';

enum E2eeRoomStatus {
  preparing,
  negotiating,
  ready,
  peerMissingKey,
  needsRestore,
}

class E2eeRoomStatusNotifier extends StateNotifier<E2eeRoomStatus> {
  final String _roomId;

  E2eeRoomStatusNotifier(this._roomId) : super(E2eeRoomStatus.preparing) {
    initializeRoomSecurity();
  }

  Future<void> initializeRoomSecurity() async {
    state = E2eeRoomStatus.preparing;

    // Jeda singkat tahap 1 agar banner animasi terlihat tenang oleh pengguna
    await Future.delayed(const Duration(milliseconds: 350));

    // 1. Pastikan identitas lokal E2EE sudah siap
    await E2eeService.instance.ensureIdentity();

    if (E2eeService.instance.needsRestore) {
      state = E2eeRoomStatus.needsRestore;
      return;
    }

    state = E2eeRoomStatus.negotiating;
    await Future.delayed(const Duration(milliseconds: 350));

    // 2. Tes derivasi enkripsi kamar
    final testResult = await E2eeService.instance.encryptForRoom(_roomId, 'test-handshake');
    if (testResult == null) {
      state = E2eeRoomStatus.peerMissingKey;
      return;
    }

    // Tahap 3: Selesai, percakapan aman sudah siap
    state = E2eeRoomStatus.ready;
  }

  void retry() {
    initializeRoomSecurity();
  }
}

final e2eeRoomStatusProvider = StateNotifierProvider.family<
    E2eeRoomStatusNotifier, E2eeRoomStatus, String>((ref, roomId) {
  return E2eeRoomStatusNotifier(roomId);
});
