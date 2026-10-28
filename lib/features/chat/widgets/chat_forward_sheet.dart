import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/message_model.dart';
import '../providers/chat_provider.dart';
import '../providers/forwarding_protection_provider.dart';

/// Bottom sheet tersentralisasi untuk meneruskan satu atau beberapa pesan ke ruang obrolan lain.
class ChatForwardSheet {
  const ChatForwardSheet._();

  /// Menampilkan bottom sheet pemilihan obrolan tujuan untuk meneruskan pesan.
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required String currentRoomId,
    required List<Message> messages,
    VoidCallback? onForwardCompleted,
  }) async {
    final actions = ref.read(chatActionsProvider);
    final forwardableMsgs = messages
        .where((m) => actions.canForward(m, forwardingProtectionActive: false))
        .toList();

    if (forwardableMsgs.isEmpty) {
      if (context.mounted) {
        MekaarSnackbar.warning(
          context,
          'Pesan yang dipilih tidak dapat diteruskan.',
        );
      }
      return;
    }

    final rooms = ref.read(chatRoomsProvider).value ?? [];
    final targets = rooms.where((r) => r['id'] != currentRoomId).toList();
    final hasTargets = targets.isNotEmpty;

    await MekaarBottomSheet.show(
      context: context,
      title: 'Teruskan ke',
      builder: (ctx) => hasTargets
          ? ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: targets.map((room) {
                final name = room['name'] as String? ?? 'User';
                final avatar = room['avatar'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      ctx,
                    ).colorScheme.surfaceContainerHighest,
                    child: Text(
                      avatar.isNotEmpty ? avatar : (name.isNotEmpty ? name[0] : 'U'),
                      style: TextStyle(
                        color: MekaarColors.textPrimaryOf(ctx),
                      ),
                    ),
                  ),
                  title: Text(name),
                  onTap: () async {
                    Navigator.pop(ctx);

                    // Verifikasi ulang filter proteksi penerusan secara segar
                    final currentForwarding = ref
                        .read(roomForwardingProtectionProvider(currentRoomId))
                        .valueOrNull;

                    if (currentForwarding?.effective ?? false) {
                      if (context.mounted) {
                        MekaarSnackbar.warning(
                          context,
                          'Penerusan pesan dibatasi di obrolan ini.',
                        );
                      }
                      return;
                    }

                    int successCount = 0;
                    for (final msg in forwardableMsgs) {
                      if (!actions.canForward(
                        msg,
                        forwardingProtectionActive:
                            currentForwarding?.effective ?? false,
                      )) {
                        continue;
                      }
                      try {
                        await actions.forwardMessage(
                          msg,
                          room['id'] as String,
                        );
                        successCount++;
                      } catch (_) {}
                    }

                    if (context.mounted) {
                      if (successCount > 0) {
                        MekaarSnackbar.success(
                          context,
                          forwardableMsgs.length == 1
                              ? 'Pesan diteruskan ke $name'
                              : '$successCount pesan berhasil diteruskan ke $name',
                        );
                      } else {
                        MekaarSnackbar.error(
                          context,
                          'Gagal meneruskan pesan.',
                        );
                      }
                    }
                    onForwardCompleted?.call();
                  },
                );
              }).toList(),
            )
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada chat lain untuk meneruskan pesan.',
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}
