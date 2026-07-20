import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/screen_protection_repository.dart';
import '../../auth/providers/auth_provider.dart';

final screenProtectionRepositoryProvider = Provider<ScreenProtectionRepository>(
  (ref) {
    return ScreenProtectionRepository(ref.watch(supabaseServiceProvider));
  },
);

final nativeScreenProtectionProvider = Provider<NativeScreenProtection>((ref) {
  return NativeScreenProtection();
});

final screenProtectionControllerProvider = Provider<ScreenProtectionController>(
  (ref) {
    final controller = ScreenProtectionController(
      repository: ref.watch(screenProtectionRepositoryProvider),
      native: ref.watch(nativeScreenProtectionProvider),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
);

final roomScreenProtectionProvider =
    StreamProvider.autoDispose.family<RoomScreenProtection, String>((ref, roomId) {
      final controller = ref.watch(screenProtectionControllerProvider);
      controller.enterRoom(roomId);
      ref.onDispose(() => controller.leaveRoom(roomId));
      return controller.states
          .map(
            (states) =>
                states[roomId] ?? const RoomScreenProtection.failClosed(),
          )
          .startWith(controller.stateFor(roomId));
    });

extension on Stream<RoomScreenProtection> {
  Stream<RoomScreenProtection> startWith(RoomScreenProtection value) async* {
    yield value;
    yield* this;
  }
}
