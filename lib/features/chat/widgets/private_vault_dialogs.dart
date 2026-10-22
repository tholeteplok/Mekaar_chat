import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
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
      final success = await showSetPasscodeDialog(context, ref);
      if (!success) return null;
    }

    if (!context.mounted) return null;

    final isHiddenNow =
        await ref.read(hiddenContactUserIdsProvider.notifier).toggleHide(contactUserId);

    // Sinkronkan juga roomId jika tersedia agar kompatibilitas legacy/room listeners terjaga
    if (roomId != null && roomId.isNotEmpty) {
      final isRoomHidden = ref.read(hiddenRoomIdsProvider).contains(roomId);
      if (isHiddenNow && !isRoomHidden) {
        await ref.read(hiddenRoomIdsProvider.notifier).toggleHide(roomId);
      } else if (!isHiddenNow && isRoomHidden) {
        await ref.read(hiddenRoomIdsProvider.notifier).toggleHide(roomId);
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
      final success = await showSetPasscodeDialog(context, ref);
      if (!success) return;
    }

    if (!context.mounted) return;

    final isHiddenNow =
        await ref.read(hiddenRoomIdsProvider.notifier).toggleHide(roomId);

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

  /// Dialog pembuatan kode rahasia vault pertama kali
  static Future<bool> showSetPasscodeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final codeController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    bool obscureCode = true;
    bool obscureConfirm = true;

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
              title: 'Buat Kode Vault Rahasia',
              message:
                  'Tentukan kode rahasia untuk membuka obrolan tersembunyi.\nKode ini nantinya cukup diketik pada kolom pencarian (Search Bar).',
              customContent: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    obscureText: obscureCode,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration:
                        vaultInputDecoration('Masukkan kode rahasia (min. 4 karakter)')
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
                            ? 'Tampilkan kode'
                            : 'Sembunyikan kode',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration:
                        vaultInputDecoration('Konfirmasi kode rahasia')
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
                            ? 'Tampilkan kode'
                            : 'Sembunyikan kode',
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

                    if (code.length < 4) {
                      setDialogState(() {
                        errorMessage = 'Kode minimal 4 karakter / angka';
                      });
                      return;
                    }

                    if (code != confirm) {
                      setDialogState(() {
                        errorMessage = 'Konfirmasi kode tidak cocok';
                      });
                      return;
                    }

                    final repo = ref.read(privateContactRepositoryProvider);
                    await repo.setPasscode(code);
                    ref.invalidate(privateVaultPasscodeSetProvider);

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx, true);
                    }
                  },
                  child: const Text('Simpan Kode'),
                ),
              ],
            );
          },
        );
      },
    );

    final isSuccess = result ?? false;
    if (isSuccess) {
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
    }
    return isSuccess;
  }

  /// Dialog verifikasi kode rahasia vault untuk membuka obrolan tersembunyi
  static Future<bool> showUnlockPasscodeDialog(
    BuildContext context, [
    WidgetRef? ref,
  ]) async {
    final codeController = TextEditingController();
    String? errorMessage;
    bool obscureCode = true;

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
              title: 'Buka Private Vault',
              message:
                  'Masukkan kode rahasia untuk membuka percakapan tersembunyi.',
              customContent: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    obscureText: obscureCode,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Kode rahasia vault',
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
                            ? 'Tampilkan kode'
                            : 'Sembunyikan kode',
                      ),
                    ),
                    onSubmitted: (val) async {
                      final repo = PrivateContactRepository();
                      final isMatch = await repo.verifyPasscode(val.trim());
                      if (isMatch) {
                        HapticService.trigger(MekaarHapticIntent.success);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                      } else {
                        HapticService.trigger(MekaarHapticIntent.warning);
                        setDialogState(() {
                          errorMessage = 'Kode rahasia tidak cocok';
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
                        errorMessage = 'Masukkan kode rahasia Anda';
                      });
                      return;
                    }

                    final repo = PrivateContactRepository();
                    final isMatch = await repo.verifyPasscode(code);
                    if (isMatch) {
                      HapticService.trigger(MekaarHapticIntent.success);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx, true);
                      }
                    } else {
                      HapticService.trigger(MekaarHapticIntent.warning);
                      setDialogState(() {
                        errorMessage = 'Kode rahasia tidak cocok';
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
      ref.read(privateVaultUnlockedProvider.notifier).state = true;
    }
    return isSuccess;
  }
}
