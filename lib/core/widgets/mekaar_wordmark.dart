import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';

/// Wordmark resmi MEKAAR satu warna brand.blue sesuai spesifikasi desain baru.
class MekaarWordmark extends StatelessWidget {
  const MekaarWordmark({
    super.key,
    this.fontSize = 38,
    this.semanticLabel = 'Mekaar',
    this.color,
  });

  final double fontSize;
  final String semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.blue;

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Text(
          'Mekaar',
          style: MekaarTypography.wordmark.copyWith(
            fontSize: fontSize,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}

