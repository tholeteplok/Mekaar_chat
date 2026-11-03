import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/onboarding_tokens.dart';

/// Garis Pijakan Bersama (Shared Grounding Stage Line) untuk Onboarding MEKAAR.
/// Menjadi pijakan horizontal flat minimalis berwarna solid Biru MEKAAR (#136CFC).
class MekaarStageGroundingLine extends StatelessWidget {
  const MekaarStageGroundingLine({
    super.key,
    this.color = AppColors.blue,
    this.width = MekaarOnboardingTokens.groundlineWidth,
    this.height = MekaarOnboardingTokens.groundlineHeight,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
