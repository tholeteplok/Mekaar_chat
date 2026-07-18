import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';

/// Wordmark resmi MEKAAR yang konsisten di seluruh pengalaman autentikasi.
class MekaarWordmark extends StatelessWidget {
  const MekaarWordmark({
    super.key,
    this.fontSize = 38,
    this.semanticLabel = 'Mekaar',
  });

  final double fontSize;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: RichText(
          text: TextSpan(
            style: MekaarTypography.wordmark.copyWith(fontSize: fontSize),
            children: const [
              TextSpan(
                text: 'Mek',
                style: TextStyle(color: MekaarColors.yellow),
              ),
              TextSpan(
                text: 'aar',
                style: TextStyle(color: MekaarColors.cyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
