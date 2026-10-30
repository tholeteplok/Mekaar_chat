import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';

/// Dialog konfirmasi penghapusan pesan, penarikan pesan, dan pembersihan ruang obrolan tersentralisasi.
class ChatDeletionDialogs {
  const ChatDeletionDialogs._();

  /// Konfirmasi penghapusan satu pesan untuk pengguna lokal saja (Hapus untuk Saya).
  static void confirmDeleteSingleMessage(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required Message message,
  }) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus untuk Saya?',
      message:
          'Pesan akan disembunyikan untuk Anda saja. Lawan bicara tetap dapat melihat pesan ini.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref
                  .read(chatActionsProvider)
                  .hideMessageForMe(message.id, roomId: roomId);
            } catch (e) {
              if (context.mounted) {
                MekaarSnackbar.error(
                  context,
                  'Gagal menghapus pesan: ${ErrorResolver.resolve(e)}',
                );
              }
            }
          },
          style: FilledButton.styleFrom(backgroundColor: MekaarColors.sosCoral),
          child: const Text('Hapus untuk Saya'),
        ),
      ],
    );
  }

  /// Konfirmasi penarikan pesan untuk seluruh anggota (Tarik Pesan).
  static void confirmUnsingleMessage(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required Message message,
    required bool isGuardian,
  }) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Tarik Pesan?',
      message: isGuardian
          ? 'Konten pesan akan hilang dari layar. Log sistem tetap mencatat snapshot penghapusan demi integritas bukti.'
          : 'Pesan akan dihapus untuk semua orang. Jika belum dibaca, pesan ini akan ditarik tanpa jejak.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref
                  .read(chatActionsProvider)
                  .deleteMessageForEveryone(message.id, roomId: roomId);
            } catch (e) {
              if (context.mounted) {
                MekaarSnackbar.error(
                  context,
                  'Gagal menarik pesan: ${ErrorResolver.resolve(e)}',
                );
              }
            }
          },
          style: FilledButton.styleFrom(backgroundColor: MekaarColors.sosCoral),
          child: const Text('Tarik untuk Semua'),
        ),
      ],
    );
  }

  /// Dialog konfirmasi penghapusan batch item terpilih (pesan dan panggilan).
  static void confirmDeleteSelectedItems(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required String otherParticipantName,
    required bool isGroup,
    required List<Message> selectedMessages,
    required Set<String> selectedCallIds,
    required Future<void> Function(Set<String>) onHideCalls,
    required VoidCallback onSelectionCleared,
    void Function(List<String> messageIds, {required String label})?
    onHideMessagesWithUndo,
  }) {
    final currentUserId = ref.read(authProvider).user?.id;
    final selectedMsgs = List<Message>.from(selectedMessages);
    final selectedCallIdsCopy = Set<String>.from(selectedCallIds);

    if (selectedMsgs.isEmpty && selectedCallIdsCopy.isEmpty) return;

    final canDeleteForEveryone = selectedMsgs.any(
      (m) => m.senderId == currentUserId,
    );
    final totalCount = selectedMsgs.length + selectedCallIdsCopy.length;
    final isSingle = totalCount == 1;
    final title = isSingle ? 'Hapus item obrolan?' : 'Hapus $totalCount item?';

    bool deleteForEveryone = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final textPrimary = MekaarColors.textPrimaryOf(ctx);
            final textSecondary = MekaarColors.textSecondaryOf(ctx);

            return AlertDialog(
              backgroundColor: MekaarColors.surfaceOf(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.lg),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item yang dipilih akan dihapus dari obrolan ini.',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  if (canDeleteForEveryone) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                      onTap: () {
                        setDialogState(() {
                          deleteForEveryone = !deleteForEveryone;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: deleteForEveryone,
                                activeColor: MekaarColors.sosRed,
                                onChanged: (val) {
                                  setDialogState(() {
                                    deleteForEveryone = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Hapus juga untuk ${isGroup ? 'semua anggota' : otherParticipantName}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Batal', style: TextStyle(color: textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final actions = ref.read(chatActionsProvider);
                    final toProcessMsgs = List<Message>.from(selectedMsgs);
                    final toProcessCalls = Set<String>.from(
                      selectedCallIdsCopy,
                    );
                    onSelectionCleared();

                    // 1. Proses penghapusan pesan
                    if (!deleteForEveryone && onHideMessagesWithUndo != null) {
                      final label = toProcessMsgs.length == 1
                          ? 'Pesan disembunyikan untuk Anda'
                          : '${toProcessMsgs.length} pesan disembunyikan untuk Anda';
                      onHideMessagesWithUndo(
                        toProcessMsgs.map((m) => m.id).toList(),
                        label: label,
                      );
                    } else {
                      for (final msg in toProcessMsgs) {
                        if (deleteForEveryone &&
                            msg.senderId == currentUserId) {
                          await actions.deleteMessageForEveryone(
                            msg.id,
                            roomId: roomId,
                          );
                        } else {
                          await actions.hideMessageForMe(
                            msg.id,
                            roomId: roomId,
                          );
                        }
                      }
                    }

                    // 2. Proses penyembunyian/penghapusan riwayat panggilan
                    if (toProcessCalls.isNotEmpty) {
                      await onHideCalls(toProcessCalls);
                    }

                    if (context.mounted) {
                      if (deleteForEveryone) {
                        MekaarSnackbar.success(
                          context,
                          'Item obrolan dihapus untuk semua orang',
                        );
                      } else if (onHideMessagesWithUndo == null) {
                        MekaarSnackbar.success(
                          context,
                          'Item obrolan dihapus untuk Anda',
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Hapus',
                    style: TextStyle(
                      color: MekaarColors.sosRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      onSelectionCleared();
    });
  }

  /// Konfirmasi pembersihan riwayat obrolan di perangkat lokal saja.
  static void confirmClearHistory(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required bool isGuardian,
    required VoidCallback onCleared,
  }) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Bersihkan Riwayat di Perangkat Ini?',
      message: isGuardian
          ? 'Seluruh riwayat chat akan dibersihkan dari tampilan Anda saja, namun log percakapan tetap diarsipkan demi kepatuhan Room Guardian.'
          : 'Semua pesan di ruangan ini hanya akan dibersihkan dari tampilan Anda. Rekan obrolan tetap dapat melihat riwayat percakapan di perangkat mereka.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(chatActionsProvider).clearChatHistory(roomId);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('hidden_call_ids_$roomId');
            } catch (_) {}
            onCleared();
            if (context.mounted) {
              MekaarSnackbar.success(
                context,
                'Riwayat obrolan & panggilan dibersihkan untuk perangkat ini.',
              );
            }
          },
          child: const Text(
            'Bersihkan (Hanya Saya)',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  /// Konfirmasi penghapusan seluruh percakapan dari daftar obrolan lokal.
  static void confirmDeleteChat(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required VoidCallback onDeleted,
  }) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Percakapan dari Daftar Anda?',
      message:
          'Obrolan ini hanya akan dihapus dari daftar pesan Anda. Percakapan di sisi rekan obrolan tidak akan terhapus.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(chatActionsProvider).deleteChat(roomId);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('hidden_call_ids_$roomId');
            } catch (_) {}
            onDeleted();
          },
          child: const Text(
            'Hapus (Hanya Saya)',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }
}
