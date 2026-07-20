import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// MekaarBottomSheet — Bottom sheet terpusat bergaya MEKAAR.
///
/// Semua bottom sheet dalam aplikasi WAJIB menggunakan helper ini atau
/// [MekaarBottomSheet.show] agar tampilan drag-handle, radius, padding, dan
/// warna permukaan selalu konsisten.
class MekaarBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? leading;
  final bool showDragHandle;
  final bool isScrollControlled;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const MekaarBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.showDragHandle = true,
    this.isScrollControlled = false,
    this.padding,
    this.backgroundColor,
  });

  /// Buka bottom sheet terpusat. Mengembalikan [T?] dari [Navigator.pop].
  ///
  /// [builder] menerima [BuildContext] dan mengembalikan konten sheet.
  /// [isScrollControlled] = true untuk sheet tinggi (pilih lokasi live, dll).
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    Widget? leading,
    bool showDragHandle = true,
    bool isScrollControlled = false,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MekaarBottomSheet(
        title: title,
        leading: leading,
        showDragHandle: showDragHandle,
        isScrollControlled: isScrollControlled,
        padding: padding,
        backgroundColor: backgroundColor,
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? MekaarColors.surfaceOf(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle) ...[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? MekaarColors.textMuted
                    : MekaarColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Header (opsional)
          if (title != null || leading != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MekaarSpacing.xl,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: MekaarSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MekaarSpacing.md),
          ],
          // Konten
          Flexible(
            child: Container(
              width: double.infinity,
              padding: padding ??
                  const EdgeInsets.fromLTRB(
                    MekaarSpacing.xl,
                    0,
                    MekaarSpacing.xl,
                    MekaarSpacing.xl,
                  ),
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(MekaarRadius.lg),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
