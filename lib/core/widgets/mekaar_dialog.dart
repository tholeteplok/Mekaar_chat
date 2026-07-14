import 'package:flutter/material.dart';
import '../constants/colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final accentColor = isDestructive
        ? MekaarColors.sosRed
        : MekaarColors.softCoral;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: MekaarColors.textSecondary,
        ),
      ),
      actions: actions,
    );
  }
}
