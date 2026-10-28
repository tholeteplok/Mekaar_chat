import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';

/// AppBar khusus mode seleksi multi-pesan pada ChatScreen
class ChatSelectionAppBar extends StatelessWidget {
  final int selectedCount;
  final bool canReply;
  final bool canEdit;
  final bool hasCopyableText;
  final bool canForward;
  final bool canDownload;
  final bool canSaveToVault;
  final VoidCallback onClose;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onForward;
  final VoidCallback? onDownload;
  final VoidCallback? onSaveToVault;
  final VoidCallback onDelete;
  final Color? surfaceColor;
  final Color textColor;
  final Color iconColor;

  const ChatSelectionAppBar({
    super.key,
    required this.selectedCount,
    this.canReply = false,
    this.canEdit = false,
    this.hasCopyableText = false,
    this.canForward = false,
    this.canDownload = false,
    this.canSaveToVault = false,
    required this.onClose,
    this.onReply,
    this.onEdit,
    this.onCopy,
    this.onForward,
    this.onDownload,
    this.onSaveToVault,
    required this.onDelete,
    this.surfaceColor,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSurfaceColor =
        surfaceColor ?? MekaarColors.surfaceOf(context);

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: effectiveSurfaceColor,
        border: Border(
          bottom: BorderSide(
            color: MekaarColors.borderOf(
              context,
            ).withValues(alpha: isDark ? 0.3 : 0.1),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                SolarIconsOutline.closeCircle,
                size: 22,
                color: iconColor,
              ),
              tooltip: 'Batal',
              onPressed: onClose,
            ),
            const SizedBox(width: 4),
            Text(
              '$selectedCount dipilih',
              style: MekaarTypography.headingSM.copyWith(
                color: textColor,
                fontSize: 17,
              ),
            ),
            const Spacer(),
            if (canReply && onReply != null)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.reply,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Balas',
                onPressed: onReply,
              ),
            if (canEdit && onEdit != null)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.pen,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
            if (hasCopyableText && onCopy != null)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.copy,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Salin',
                onPressed: onCopy,
              ),
            if (canForward && onForward != null)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.forward,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Teruskan',
                onPressed: onForward,
              ),
            if (canDownload && onDownload != null)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.download,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Unduh ke Download/Mekaar',
                onPressed: onDownload,
              ),
            if (canSaveToVault && onSaveToVault != null)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.safeSquare,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Simpan ke Brankas',
                onPressed: onSaveToVault,
              ),
            IconButton(
              icon: Icon(
                SolarIconsOutline.trashBinTrash,
                size: 22,
                color: MekaarColors.sosRed,
              ),
              tooltip: 'Hapus',
              onPressed: onDelete,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
