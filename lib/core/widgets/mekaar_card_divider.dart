import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Widget terpusat untuk garis pemisah (divider) di dalam kartu / list tile MEKAAR 3.0.
///
/// Secara default menggunakan Inset Divider (indent: 56, endIndent: 16) dengan warna
/// lembut ([MekaarColors.dividerOf] opasitas 0.5) agar garis pemisah TIDAK MENYENTUH
/// border luar kartu dan tampil sangat rapi & konsisten.
class MekaarCardDivider extends StatelessWidget {
  /// Jika [fullWidth] true, garis membentang penuh dari tepi ke tepi.
  /// Jika false (default), garis terpotong halus (indent: 56, endIndent: 16) sejajar dengan teks title tile.
  final bool fullWidth;

  /// Margin kustom opsional di sisi kiri.
  final double? indent;

  /// Margin kustom opsional di sisi kanan.
  final double? endIndent;

  /// Ketebalan garis (default: 1.0).
  final double thickness;

  const MekaarCardDivider({
    super.key,
    this.fullWidth = false,
    this.indent,
    this.endIndent,
    this.thickness = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final double defaultIndent = fullWidth ? 0.0 : 56.0;
    final double defaultEndIndent = fullWidth ? 0.0 : 16.0;

    return Divider(
      height: 1.0,
      thickness: thickness,
      indent: indent ?? defaultIndent,
      endIndent: endIndent ?? defaultEndIndent,
      color: MekaarColors.dividerOf(context).withValues(alpha: 0.5),
    );
  }
}
