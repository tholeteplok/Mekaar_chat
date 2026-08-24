import 'package:flutter/material.dart';
import '../constants/dimensions.dart';

/// Banner informasi/peringatan standar MEKAAR — satu bahasa untuk
/// banner Aegis, status trip, peringatan PIN duplikat, dsb.
///
/// Visual: tint [color] @ 0.10, border @ 0.30, radius `MekaarRadius.md`.
/// Konten teks dipertanggungjawabkan pemanggil (pakai `MekaarTypography`
/// + helper warna `*Of(context)`), banner hanya mengurus bentuk & ritme.
class MekaarBanner extends StatelessWidget {
  /// Warna intent (aksen semantik): `safeTextOf`, `warnAmber`, `sosRed`,
  /// `accentTextOf`, dst.
  final Color color;

  /// Isi utama banner (teks / kolom teks), sudah ber-styling final.
  final Widget content;

  /// Ikon di kiri; ukuran disarankan 20.
  final IconData? icon;
  final Widget? action;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const MekaarBanner({
    super.key,
    required this.color,
    required this.content,
    this.icon,
    this.action,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: MekaarSpacing.md),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: MekaarSpacing.md),
          ],
          Expanded(child: content),
          if (action != null) ...[
            const SizedBox(width: MekaarSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
