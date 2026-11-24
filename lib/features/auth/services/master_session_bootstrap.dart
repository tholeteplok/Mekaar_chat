import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/guest_session_guard.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../../data/services/local_message_database.dart';
import '../../chat/providers/chat_draft_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/private_vault_provider.dart';

/// Helper terpusat untuk memulihkan sesi Master (database pesan, cache kontak Vault,
/// slot vault terbuka, serta pembersihan pesan kedaluwarsa/terjadwal) saat pengguna
/// masuk baik melalui Master PIN di `PinScreen` maupun via bypass `SplashScreen`
/// ketika Kunci Otomatis dinonaktifkan (`AutoLockTimeout.off`).
class MasterSessionBootstrap {
  const MasterSessionBootstrap._();

  /// Menyiapkan state lokal sesi Master secara penuh dan membuka seluruh slot Vault ({1, 2, 3}).
  static Future<void> prepareSession(
    WidgetRef ref, {
    required bool isDecoy,
    required bool isDuress,
    bool reloadLocalRooms = true,
    bool triggerPurge = false,
  }) async {
    try {
      await LocalMessageDatabase.instance.switchMode(isDecoy: isDuress);
    } catch (_) {}

    try {
      ref.invalidate(chatDraftsProvider);
    } catch (_) {}

    // Terapkan status keterbukaan slot Vault secara instan (0ms) sesuai jalur sesi
    try {
      if (!isDecoy) {
        ref.read(unlockedVaultSlotsProvider.notifier).state = {1, 2, 3};
        ref.read(privateVaultUnlockedProvider.notifier).state = true;
      } else {
        ref.read(unlockedVaultSlotsProvider.notifier).state = {};
        ref.read(privateVaultUnlockedProvider.notifier).state = false;
      }
    } catch (_) {}

    final tasks = <Future<void>>[
      () async {
        try {
          await ref
              .read(chatDraftsProvider.notifier)
              .reloadDrafts()
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }(),
      if (reloadLocalRooms)
        () async {
          try {
            await ref
                .read(chatRoomsProvider.notifier)
                .reloadFromLocalCache(syncRemoteInBackground: !isDuress)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
        }(),
      () async {
        try {
          final vaultRepo = ref.read(privateContactRepositoryProvider);
          await Future.wait([
            vaultRepo.preloadCache(),
            ref.read(hiddenContactUserIdsProvider.notifier).loadHiddenContacts(),
            ref.read(hiddenRoomIdsProvider.notifier).loadHiddenRooms(),
          ]).timeout(const Duration(seconds: 2));
          unawaited(vaultRepo.syncToNativeVault(isVaultUnlocked: !isDecoy));
          if (!isDecoy) {
            unawaited(GuestSessionGuard.restoreMasterPreferences(ref));
          }
        } catch (_) {}
      }(),
      if (triggerPurge && !isDuress)
        () async {
          try {
            final purged = await ref
                .read(chatRepositoryProvider)
                .purgeExpiredMessages()
                .timeout(const Duration(seconds: 3));
            if (purged > 0) {
              await ref
                  .read(chatRoomsProvider.notifier)
                  .reloadFromLocalCache(syncRemoteInBackground: true);
            }
          } catch (_) {}
        }(),
    ];

    await Future.wait(tasks);
  }
}
