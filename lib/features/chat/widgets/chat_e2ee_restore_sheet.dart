import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/services/e2ee_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/e2ee_room_status_provider.dart';

/// Bottom sheet modal untuk pemulihan kunci E2EE sesi privat dengan PIN akun atau reset kunci darurat.
class ChatE2eeRestoreSheet {
  const ChatE2eeRestoreSheet._();

  /// Menampilkan bottom sheet pemulihan kunci E2EE.
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required bool isGroup,
  }) async {
    final pinController = TextEditingController();
    bool isLoading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(ctx),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MekaarRadius.xl),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.xl,
              vertical: MekaarSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MekaarColors.textSecondaryOf(ctx).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: MekaarSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MekaarColors.sosCoral.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        SolarIconsOutline.keyMinimalisticSquare,
                        color: MekaarColors.sosCoral,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: MekaarSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pulihkan Kunci E2EE',
                            style: MekaarTypography.headingMD.copyWith(
                              color: MekaarColors.textPrimaryOf(ctx),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Masukkan 6-digit PIN akun Anda untuk membuka sesi privat.',
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MekaarSpacing.lg),
                TextField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: MekaarTypography.monoLG.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.textPrimaryOf(ctx),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      letterSpacing: 12,
                      color: MekaarColors.textSecondaryOf(ctx).withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: MekaarColors.surface2Of(ctx),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: MekaarSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final confirmed =
                                    await MekaarDialog.showConfirmation<bool>(
                                  context: ctx,
                                  title: 'Reset Kunci E2EE?',
                                  message:
                                      'Kunci enkripsi lama akan dihapus dan dibuatkan kunci baru. Riwayat pesan terenkripsi lama mungkin tidak dapat didekripsi.',
                                  isDestructive: true,
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Batal'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: MekaarColors.sosCoral,
                                      ),
                                      child: const Text('Ya, Reset'),
                                    ),
                                  ],
                                );
                                if (confirmed == true && context.mounted) {
                                  setSheetState(() => isLoading = true);
                                  await E2eeService.instance.forceResetIdentity();
                                  ref
                                      .read(authProvider.notifier)
                                      .setE2eeNeedsRestore(false);
                                  ref
                                      .read(e2eeRoomStatusProvider(roomId).notifier)
                                      .retry(isGroup: isGroup);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    MekaarSnackbar.success(
                                      context,
                                      'Kunci enkripsi baru berhasil dibuat.',
                                    );
                                  }
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MekaarColors.sosCoral,
                          side: BorderSide(
                            color: MekaarColors.sosCoral.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MekaarRadius.md),
                          ),
                        ),
                        child: const Text('Reset Kunci'),
                      ),
                    ),
                    const SizedBox(width: MekaarSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final pin = pinController.text.trim();
                                if (pin.length != 6) return;
                                setSheetState(() => isLoading = true);
                                final success = await E2eeService.instance
                                    .tryRestoreWithPin(pin);
                                setSheetState(() => isLoading = false);
                                if (success) {
                                  ref
                                      .read(authProvider.notifier)
                                      .setE2eeNeedsRestore(false);
                                  ref
                                      .read(e2eeRoomStatusProvider(roomId).notifier)
                                      .retry(isGroup: isGroup);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    MekaarSnackbar.success(
                                      context,
                                      'Kunci E2EE berhasil dipulihkan!',
                                    );
                                  }
                                } else {
                                  if (ctx.mounted) {
                                    MekaarSnackbar.error(
                                      ctx,
                                      'PIN salah. Silakan coba lagi.',
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: MekaarColors.primaryOf(ctx),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MekaarRadius.md),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Buka Kunci'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MekaarSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
