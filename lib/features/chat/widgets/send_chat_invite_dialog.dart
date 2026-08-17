import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/repositories/chat_request_repository.dart';

class SendChatInviteDialog extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverUsername;

  const SendChatInviteDialog({
    super.key,
    required this.receiverId,
    required this.receiverUsername,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String receiverId,
    required String receiverUsername,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SendChatInviteDialog(
        receiverId: receiverId,
        receiverUsername: receiverUsername,
      ),
    );
  }

  @override
  ConsumerState<SendChatInviteDialog> createState() =>
      _SendChatInviteDialogState();
}

class _SendChatInviteDialogState extends ConsumerState<SendChatInviteDialog> {
  final _noteController = TextEditingController();
  bool _isSending = false;
  String? _errorText;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MekaarDialog(
      icon: Icon(SolarIconsOutline.shieldUser, color: MekaarColors.accentOf(context), size: 28),
      title: 'Kirim Permintaan Chat',
      message:
          'Pengguna @${widget.receiverUsername} mengaktifkan proteksi undangan. Harap isi keterangan perkenalan agar pengundang mengenali Anda.',
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'Contoh: Halo, saya Budi kawan sekelas SMA...',
                errorText: _errorText,
              ),
              onChanged: (val) {
                if (val.trim().length >= 10 && _errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending ? null : _handleSend,
                  style: ElevatedButton.styleFrom(backgroundColor: MekaarColors.accentOf(context)),
                  child: Text(_isSending ? 'Kirim...' : 'Kirim Undangan'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSend() async {
    final note = _noteController.text.trim();
    if (note.length < 10) {
      setState(() {
        _errorText = 'Keterangan undangan wajib minimal 10 karakter';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    try {
      await ref.read(chatRequestRepositoryProvider).sendChatRequest(
            receiverId: widget.receiverId,
            invitationNote: note,
          );

      if (!mounted) return;
      Navigator.pop(context, true);
      MekaarSnackbar.success(
        context,
        'Permintaan chat terkirim ke @${widget.receiverUsername}. Menunggu persetujuan.',
      );
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal mengirim undangan: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
