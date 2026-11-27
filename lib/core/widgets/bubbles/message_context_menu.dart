import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/file_export_service.dart';
import '../../constants/colors.dart';
import '../../constants/icons.dart';
import '../../constants/shadows.dart';
import '../../constants/typography.dart';
import '../../services/haptic_service.dart';
import '../mekaar_snackbar.dart';

/// Long-Press Context Menu untuk aksi pesan (balas, edit, unduh, hapus, vault, dll.)
class MessageContextMenu extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool canDelete;
  final bool canEdit;
  final bool canForward;
  final Function(Message)? onReply;
  final Function(Message, String)? onEdit;
  final Function(Message)? onForward;
  final VoidCallback? onDelete;
  final VoidCallback? onUnsend;
  final Function(Message, String)? onReact;
  final Function(Message)? onSaveToVault;
  final bool canUnsend;

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.isMe,
    required this.canDelete,
    required this.canEdit,
    required this.canForward,
    this.canUnsend = false,
    this.onReply,
    this.onEdit,
    this.onForward,
    this.onDelete,
    this.onUnsend,
    this.onReact,
    this.onSaveToVault,
  });

  @override
  Widget build(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MekaarColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: MekaarShadows.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji Reactions Row
          if (onReact != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReact!(message, emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            Divider(
              color: MekaarColors.textMutedOf(context).withValues(alpha: 0.15),
              height: 1,
            ),
          ],
          // Action buttons
          if (message.type == MessageType.text &&
              !message.isDeleted &&
              message.content.isNotEmpty)
            _menuItem(
              context,
              icon: MekaarIcons.copy,
              label: 'Salin Teks',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                HapticService.trigger(MekaarHapticIntent.selection);
                MekaarSnackbar.success(context, 'Pesan disalin');
              },
            ),
          if (!message.isDeleted &&
              (message.type == MessageType.file ||
                  (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)))
            _menuItem(
              context,
              icon: SolarIconsOutline.inboxIn,
              label: 'Unduh ke Download/Mekaar',
              onTap: () async {
                Navigator.pop(context);
                MekaarSnackbar.info(
                    context, 'Mengunduh dan mengekspor berkas...');
                final localFile =
                    await FileExportService.resolveOrDownloadFile(message);
                if (!context.mounted) return;
                if (localFile != null) {
                  final meta = message.fileMeta;
                  final fileName = meta?.fileName ??
                      localFile.path.split(Platform.pathSeparator).last;
                  final exported =
                      await FileExportService.exportToMekaarDownloads(
                    file: localFile,
                    fileName: fileName,
                    mimeType: meta?.mimeType,
                  );
                  if (!context.mounted) return;
                  if (exported != null) {
                    HapticService.trigger(MekaarHapticIntent.success);
                    MekaarSnackbar.success(
                      context,
                      'Berkas berhasil disimpan di $exported',
                    );
                    return;
                  }
                }
                HapticService.trigger(MekaarHapticIntent.warning);
                MekaarSnackbar.error(context, 'Gagal mengunduh berkas');
              },
            ),
          if (onSaveToVault != null &&
              !message.isDeleted &&
              (message.type == MessageType.image ||
                  message.type == MessageType.video ||
                  message.type == MessageType.voice ||
                  message.type == MessageType.file ||
                  (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)))
            _menuItem(
              context,
              icon: SolarIconsOutline.safeSquare,
              label: 'Simpan ke Brankas',
              onTap: () {
                Navigator.pop(context);
                onSaveToVault!(message);
              },
            ),
          if (onReply != null)
            _menuItem(
              context,
              icon: MekaarIcons.reply,
              label: 'Balas',
              onTap: () {
                Navigator.pop(context);
                onReply!(message);
              },
            ),
          if (canEdit && onEdit != null)
            _menuItem(
              context,
              icon: MekaarIcons.edit,
              label: 'Edit Pesan',
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context);
              },
            ),
          if (canForward && onForward != null)
            _menuItem(
              context,
              icon: MekaarIcons.forward,
              label: 'Teruskan',
              onTap: () {
                Navigator.pop(context);
                onForward!(message);
              },
            ),
          if (canDelete && onDelete != null)
            _menuItem(
              context,
              icon: MekaarIcons.delete,
              label: 'Hapus untuk Saya',
              color: MekaarColors.textMutedOf(context),
              onTap: () {
                Navigator.pop(context);
                onDelete!();
              },
            ),
          if (canUnsend && onUnsend != null)
            _menuItem(
              context,
              icon: MekaarIcons.deleteForever,
              label: 'Tarik Pesan',
              color: MekaarColors.sosRed,
              onTap: () {
                Navigator.pop(context);
                onUnsend!();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditMessageDialog(
        initialContent: message.content,
        onSave: (newContent) => onEdit!(message, newContent),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? MekaarColors.textPrimaryOf(context);
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onSave;

  const _EditMessageDialog({
    required this.initialContent,
    required this.onSave,
  });

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Pesan', style: MekaarTypography.headingMD),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: MekaarTypography.labelLG.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final newContent = _controller.text.trim();
            if (newContent.isNotEmpty && newContent != widget.initialContent) {
              widget.onSave(newContent);
            }
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.accentOf(context),
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Simpan',
            style: MekaarTypography.labelLG.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
