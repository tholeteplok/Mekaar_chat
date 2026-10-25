import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

/// MekaarTopBar â€” Header sub-screen terpusat Mekaar (Desain 2: Stacked Two-Row / Large Header).
///
/// Baris 1: Tombol kembali (<) dengan lingkaran squircle di kiri, dan action icon / trailing widget di kanan.
/// Baris 2: Judul besar (Large Title) selebar layar tanpa risiko pemotongan teks (*anti-truncation*) + subtitle opsional.
///
/// Dapat digunakan langsung sebagai:
/// 1. `appBar: MekaarTopBar(...)` di dalam [MekaarScaffold] atau [Scaffold] (sebagai [PreferredSizeWidget]), ATAU
/// 2. Widget biasa di dalam [Column] / [SafeArea].
class MekaarTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MekaarTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.actions,
    this.showBackButton = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final List<Widget>? actions;
  final bool showBackButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && (Navigator.canPop(context) || onBack != null);

    Widget? effectiveTrailing;
    if (trailing != null) {
      effectiveTrailing = trailing;
    } else if (actions != null && actions!.isNotEmpty) {
      effectiveTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: actions!,
      );
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (canPop)
                  IconButton(
                    tooltip: 'Kembali',
                    onPressed: () {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      if (onBack != null) {
                        onBack!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(
                      SolarIconsOutline.altArrowLeft,
                      color: MekaarColors.textPrimaryOf(context),
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          MekaarColors.surface2Of(context).withValues(alpha: 0.85),
                      side: BorderSide(
                        color: MekaarColors.cardBorderOf(context)
                            .withValues(alpha: 0.8),
                        width: 1.0,
                      ),
                      shape: const CircleBorder(),
                    ),
                  )
                else
                  const SizedBox(width: 40, height: 40),
                ?effectiveTrailing,
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: MekaarTypography.headingLG.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: MekaarColors.textPrimaryOf(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Size.fromHeight(hasSubtitle ? 136.0 : 112.0);
  }
}
