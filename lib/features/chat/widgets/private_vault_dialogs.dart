import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../providers/private_vault_provider.dart';

class PrivateVaultDialogs {
  /// Membantu menyembunyikan / menampilkan kontak dan obrolan terkait dengan validasi passcode
  static Future<bool?> toggleContactHiddenWithAuth(
    BuildContext context,
    WidgetRef ref, {
    required String contactUserId,
    required String contactName,
    String? roomId,
  }) async {
    final repo = ref.read(privateContactRepositoryProvider);
    final hasPasscode = await repo.hasPasscode();

    if (!context.mounted) return null;

    if (!hasPasscode) {
      final success = await showSetPasscodeDialog(
        context,
        ref,
        autoUnlock: false,
      );
      if (!success) return null;
      ref.read(unlockedVaultSlotsProvider.notifier).state = {};
      ref.read(privateVaultUnlockedProvider.notifier).state = false;
    }

    if (!context.mounted) return null;

    final isHiddenNow =
        await ref.read(hiddenContactUserIdsProvider.notifier).toggleHide(contactUserId);

    // Dapatkan nomor vaultSlot yang saat ini dimiliki kontak (jika ada) agar tidak ter-reset ke Slot 1
    final existingContact = ref.read(userContactsProvider).value?.firstWhere(
          (c) => c.contactUserId == contactUserId,
          orElse: () => null as dynamic,
        );
    final targetSlot = existingContact?.vaultSlot ?? 1;

    // Sinkronkan ke cloud Supabase agar status vault tetap terlindungi saat uninstall / clear data
    try {
      await ref.read(userContactsProvider.notifier).updateVaultStatus(contactUserId, isHiddenNow, vaultSlot: targetSlot);
    } catch (_) {
      try {
        await ref.read(contactRepositoryProvider).updateContactVaultStatus(contactUserId, isHiddenNow, vaultSlot: targetSlot);
      } catch (_) {}
    }

    // Sinkronkan juga roomId jika tersedia agar kompatibilitas legacy/room listeners terjaga
    if (roomId != null && roomId.isNotEmpty) {
      final isRoomHidden = ref.read(hiddenRoomIdsProvider).contains(roomId);
      if (isHiddenNow && !isRoomHidden) {
        await ref.read(hiddenRoomIdsProvider.notifier).toggleHide(roomId);
      } else if (!isHiddenNow && isRoomHidden) {
        await ref.read(hiddenRoomIdsProvider.notifier).toggleHide(roomId);
      }
    }

    // Jika kontak baru saja ditampilkan kembali (!isHiddenNow), periksa apakah masih
    // ada kontak rahasia atau obrolan tersembunyi yang tersisa pada slot yang sedang terbuka.
    // Jika tidak ada lagi (0 kontak tersisa), relock sesi vault seketika agar banner otomatis hilang.
    if (!isHiddenNow) {
      final contacts =
          ref.read(userContactsProvider).value ?? const <ContactItem>[];
      final unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      final hiddenUsers = ref.read(hiddenContactUserIdsProvider);
      final hiddenRooms = ref.read(hiddenRoomIdsProvider);

      final hasOtherVaultedContacts = contacts.any((c) =>
          c.contactUserId != contactUserId &&
          c.isVaulted &&
          (unlockedSlots.isEmpty || unlockedSlots.contains(c.vaultSlot)));

      final hasOtherHiddenUsers = hiddenUsers.any((id) => id != contactUserId);
      final hasOtherHiddenRooms = (roomId != null && roomId.isNotEmpty)
          ? hiddenRooms.any((id) => id != roomId)
          : hiddenRooms.isNotEmpty;

      final hasAnyRemaining =
          hasOtherVaultedContacts || hasOtherHiddenUsers || hasOtherHiddenRooms;

      if (!hasAnyRemaining) {
        ref.read(unlockedVaultSlotsProvider.notifier).state = {};
        ref.read(privateVaultUnlockedProvider.notifier).state = false;
      }
    }

    HapticService.trigger(MekaarHapticIntent.selection);

    if (context.mounted) {
      if (isHiddenNow) {
        MekaarSnackbar.success(
          context,
          'Kontak & obrolan "$contactName" telah disembunyikan dalam Private Vault',
        );
      } else {
        MekaarSnackbar.info(
          context,
          'Kontak & obrolan "$contactName" ditampilkan kembali ke daftar utama',
        );
      }
    }
    return isHiddenNow;
  }

  /// Membantu menyembunyikan / menampilkan obrolan dengan validasi passcode terlebih dahulu.
  /// Jika otherUserId disertakan (1-on-1 direct chat), otomatis menyembunyikan kontak terkait.
  static Future<void> toggleRoomHiddenWithAuth(
    BuildContext context,
    WidgetRef ref, {
    required String roomId,
    required String chatName,
    String? otherUserId,
  }) async {
    if (otherUserId != null && otherUserId.isNotEmpty) {
      await toggleContactHiddenWithAuth(
        context,
        ref,
        contactUserId: otherUserId,
        contactName: chatName,
        roomId: roomId,
      );
      return;
    }

    final repo = ref.read(privateContactRepositoryProvider);
    final hasPasscode = await repo.hasPasscode();

    if (!context.mounted) return;

    if (!hasPasscode) {
      final success = await showSetPasscodeDialog(
        context,
        ref,
        autoUnlock: false,
      );
      if (!success) return;
      ref.read(unlockedVaultSlotsProvider.notifier).state = {};
      ref.read(privateVaultUnlockedProvider.notifier).state = false;
    }

    if (!context.mounted) return;

    final isHiddenNow =
        await ref.read(hiddenRoomIdsProvider.notifier).toggleHide(roomId);

    // Jika obrolan baru saja ditampilkan kembali (!isHiddenNow), periksa apakah masih
    // ada kontak rahasia atau obrolan tersembunyi yang tersisa pada slot yang sedang terbuka.
    // Jika tidak ada lagi (0 obrolan/kontak tersisa), relock sesi vault seketika agar banner otomatis hilang.
    if (!isHiddenNow) {
      final contacts =
          ref.read(userContactsProvider).value ?? const <ContactItem>[];
      final unlockedSlots = ref.read(unlockedVaultSlotsProvider);
      final hiddenUsers = ref.read(hiddenContactUserIdsProvider);
      final hiddenRooms = ref.read(hiddenRoomIdsProvider);

      final hasVaultedContacts = contacts.any((c) =>
          c.isVaulted &&
          (unlockedSlots.isEmpty || unlockedSlots.contains(c.vaultSlot)));

      final hasOtherHiddenUsers = hiddenUsers.isNotEmpty;
      final hasOtherHiddenRooms = hiddenRooms.any((id) => id != roomId);

      final hasAnyRemaining =
          hasVaultedContacts || hasOtherHiddenUsers || hasOtherHiddenRooms;

      if (!hasAnyRemaining) {
        ref.read(unlockedVaultSlotsProvider.notifier).state = {};
        ref.read(privateVaultUnlockedProvider.notifier).state = false;
      }
    }

    HapticService.trigger(MekaarHapticIntent.selection);

    if (context.mounted) {
      if (isHiddenNow) {
        MekaarSnackbar.success(
          context,
          'Obrolan "$chatName" telah disembunyikan dalam Private Vault',
        );
      } else {
        MekaarSnackbar.info(
          context,
          'Obrolan "$chatName" ditampilkan kembali ke daftar utama',
        );
      }
    }
  }

  /// Dialog pembuatan / reset kode rahasia vault (mendukung slot 1..3)
  static Future<bool> showSetPasscodeDialog(
    BuildContext context,
    WidgetRef ref, {
    int slot = 1,
    String? slotName,
    bool isResetFlow = false,
    bool autoUnlock = false,
  }) async {
    final codeController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    bool obscureCode = true;
    bool obscureConfirm = true;
    final displayName = slotName ?? 'Profil $slot';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            InputDecoration vaultInputDecoration(String hint) {
              return InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: MekaarColors.surface2Of(dialogCtx),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.md),
                  borderSide: BorderSide(
                    color: MekaarColors.borderOf(dialogCtx),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.md),
                  borderSide: BorderSide(
                    color: MekaarColors.borderOf(dialogCtx),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.md),
                  borderSide: const BorderSide(
                    color: AppColors.blue,
                    width: 2,
                  ),
                ),
              );
            }

            return MekaarDialog(
              icon: const Icon(
                SolarIconsBold.shieldKeyhole,
                color: MekaarColors.guardianTeal,
                size: 28,
              ),
              title: isResetFlow ? 'Reset Kode Akses $displayName' : 'Atur Kode Akses $displayName',
              message:
                  'Tentukan kode akses rahasia (bebas: angka, huruf, atau simbol, min. 6 karakter) untuk membuka $displayName.\nKode ini dapat Anda masukkan pada kolom pencarian (Search Bar) untuk membuka kontak di profil ini secara terisolasi.',
              customContent: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    obscureText: obscureCode,
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration:
                        vaultInputDecoration('Masukkan kode akses rahasia (min. 6 karakter)')
                            .copyWith(
                      errorText: errorMessage,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCode
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureCode = !obscureCode),
                        tooltip: obscureCode
                            ? 'Tampilkan kode akses'
                            : 'Sembunyikan kode akses',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration:
                        vaultInputDecoration('Konfirmasi kode akses rahasia')
                            .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                        tooltip: obscureConfirm
                            ? 'Tampilkan kode akses'
                            : 'Sembunyikan kode akses',
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.guardianTeal,
                    foregroundColor: MekaarColors.textOnTeal,
                  ),
                  onPressed: () async {
                    final code = codeController.text.trim();
                    final confirm = confirmController.text.trim();

                    if (code.length < 6) {
                      setDialogState(() {
                        errorMessage = 'Kode akses minimal 6 karakter';
                      });
                      return;
                    }

                    if (code != confirm) {
                      setDialogState(() {
                        errorMessage = 'Konfirmasi kode akses tidak cocok';
                      });
                      return;
                    }

                    final repo = ref.read(privateContactRepositoryProvider);
                    await repo.setSlotPasscode(slot, code);
                    ref.invalidate(privateVaultPasscodeSetProvider);

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx, true);
                    }
                  },
                  child: const Text('Simpan Kode Akses'),
                ),
              ],
            );
          },
        );
      },
    );

    final isSuccess = result ?? false;
    if (isSuccess && autoUnlock) {
      ref.read(unlockedVaultSlotsProvider.notifier).update((s) => {...s, slot});
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
    }
    return isSuccess;
  }

  /// Dialog mengubah PIN akses vault yang sudah ada
  static Future<bool> showChangePasscodeDialog(
    BuildContext context,
    WidgetRef ref, {
    int slot = 1,
    String? slotName,
  }) async {
    final unlocked = await showUnlockPasscodeDialog(
      context,
      ref,
      slot,
      slotName,
    );
    if (!unlocked || !context.mounted) return false;
    return await showSetPasscodeDialog(
      context,
      ref,
      slot: slot,
      slotName: slotName,
      autoUnlock: true,
    );
  }

  /// Dialog verifikasi kode rahasia vault untuk membuka kontak/obrolan tersembunyi
  static Future<bool> showUnlockPasscodeDialog(
    BuildContext context, [
    WidgetRef? ref,
    int slot = 1,
    String? slotName,
  ]) async {
    final codeController = TextEditingController();
    String? errorMessage;
    bool obscureCode = true;
    final displayName = slotName ?? 'Profil $slot';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return MekaarDialog(
              icon: const Icon(
                SolarIconsBold.shieldKeyhole,
                color: MekaarColors.guardianTeal,
                size: 28,
              ),
              title: 'Buka $displayName',
              message:
                  'Masukkan kode akses rahasia untuk membuka $displayName.',
              customContent: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    obscureText: obscureCode,
                    keyboardType: TextInputType.visiblePassword,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Kode akses $displayName',
                      errorText: errorMessage,
                      filled: true,
                      fillColor: MekaarColors.surface2Of(dialogCtx),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.borderOf(dialogCtx),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: BorderSide(
                          color: MekaarColors.borderOf(dialogCtx),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        borderSide: const BorderSide(
                          color: AppColors.blue,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCode
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureCode = !obscureCode),
                        tooltip: obscureCode
                            ? 'Tampilkan kode akses'
                            : 'Sembunyikan kode akses',
                      ),
                    ),
                    onSubmitted: (val) async {
                      final repo = ref != null
                          ? ref.read(privateContactRepositoryProvider)
                          : PrivateContactRepository();
                      if (await repo.isVaultLockedOut()) {
                        final remaining =
                            await repo.getVaultLockoutRemainingSeconds();
                        HapticService.trigger(MekaarHapticIntent.warning);
                        setDialogState(() {
                          errorMessage =
                              'Terlalu banyak percobaan. Tunggu $remaining detik.';
                        });
                        return;
                      }
                      final isMatch = await repo.verifySlotPasscode(slot, val.trim());
                      if (isMatch) {
                        HapticService.trigger(MekaarHapticIntent.success);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                      } else {
                        HapticService.trigger(MekaarHapticIntent.warning);
                        final isNowLocked = await repo.isVaultLockedOut();
                        final remaining =
                            await repo.getVaultLockoutRemainingSeconds();
                        setDialogState(() {
                          if (isNowLocked) {
                            errorMessage =
                                'Terlalu banyak percobaan. Tunggu $remaining detik.';
                          } else {
                            errorMessage = 'Kode akses rahasia tidak cocok';
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.guardianTeal,
                    foregroundColor: MekaarColors.textOnTeal,
                  ),
                  onPressed: () async {
                    final code = codeController.text.trim();
                    if (code.isEmpty) {
                      setDialogState(() {
                        errorMessage = 'Masukkan kode akses rahasia Anda';
                      });
                      return;
                    }

                    final repo = ref != null
                        ? ref.read(privateContactRepositoryProvider)
                        : PrivateContactRepository();
                    if (await repo.isVaultLockedOut()) {
                      final remaining =
                          await repo.getVaultLockoutRemainingSeconds();
                      HapticService.trigger(MekaarHapticIntent.warning);
                      setDialogState(() {
                        errorMessage =
                            'Terlalu banyak percobaan. Tunggu $remaining detik.';
                      });
                      return;
                    }
                    final isMatch = await repo.verifySlotPasscode(slot, code);
                    if (isMatch) {
                      HapticService.trigger(MekaarHapticIntent.success);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx, true);
                      }
                    } else {
                      HapticService.trigger(MekaarHapticIntent.warning);
                      final isNowLocked = await repo.isVaultLockedOut();
                      final remaining =
                          await repo.getVaultLockoutRemainingSeconds();
                      setDialogState(() {
                        if (isNowLocked) {
                          errorMessage =
                              'Terlalu banyak percobaan. Tunggu $remaining detik.';
                        } else {
                          errorMessage = 'Kode akses rahasia tidak cocok';
                        }
                      });
                    }
                  },
                  child: const Text('Buka'),
                ),
              ],
            );
          },
        );
      },
    );

    final isSuccess = result ?? false;
    if (isSuccess && ref != null) {
      ref.read(unlockedVaultSlotsProvider.notifier).update((s) => {...s, slot});
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
    }
    return isSuccess;
  }
}
