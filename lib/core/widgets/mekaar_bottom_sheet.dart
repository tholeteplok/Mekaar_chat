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
    this.isScrollControlled = true,
    this.padding,
    this.backgroundColor,
  });

  /// Buka bottom sheet terpusat. Mengembalikan [T?] dari [Navigator.pop].
  ///
  /// [builder] menerima [BuildContext] dan mengembalikan konten sheet.
  /// [isScrollControlled] = true agar bottom sheet terdorong mulus saat keyboard aktif.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    Widget? leading,
    bool showDragHandle = true,
    bool isScrollControlled = true,
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
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MekaarRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding ??
                const EdgeInsets.fromLTRB(
                  MekaarSpacing.xl,
                  MekaarSpacing.md,
                  MekaarSpacing.xl,
                  MekaarSpacing.xl,
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle terpusat di dalam container
                if (showDragHandle) ...[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white24
                            : MekaarColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Header (opsional)
                if (title != null || leading != null) ...[
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: MekaarSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          title ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MekaarSpacing.md),
                ],
                // Konten sheet
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
