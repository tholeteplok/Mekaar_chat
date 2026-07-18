import 'package:flutter/material.dart';
import '../constants/dimensions.dart';

class MekaarDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool isDestructive;

  const MekaarDialog({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.isDestructive = false,
  });

  static Future<T?> showConfirmation<T>({
    required BuildContext context,
    required String title,
    required String message,
    required List<Widget> actions,
    Widget? icon,
    bool barrierDismissible = true,
    bool isDestructive = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => MekaarDialog(
        icon: icon,
        title: title,
        message: message,
        actions: actions,
        isDestructive: isDestructive,
      ),
    );
  }

  static Future<bool> showNoActiveGuardianWarning({
    required BuildContext context,
  }) async {
    final shouldContinue = await showConfirmation<bool>(
      context: context,
      barrierDismissible: false,
      isDestructive: true,
      icon: Icon(
        Icons.shield_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: 'Belum Ada Guardian Aktif',
      message:
          'Tidak ada Guardian aktif yang akan menerima notifikasi SOS Anda. '
          'Anda tetap dapat mengaktifkan SOS untuk merekam sesi dan lokasi darurat.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Tetap Aktifkan SOS'),
        ),
      ],
    );
    return shouldContinue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = isDestructive ? colorScheme.error : colorScheme.primary;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
      ),
      titlePadding: MekaarSpacing.dialog,
      contentPadding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.xl),
      actionsPadding: const EdgeInsets.fromLTRB(
        MekaarSpacing.lg,
        MekaarSpacing.md,
        MekaarSpacing.lg,
        MekaarSpacing.lg,
      ),
      title: Row(
        children: [
          icon ??
              Icon(
                isDestructive
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: accentColor,
              ),
          const SizedBox(width: MekaarSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: actions,
    );
  }
}
