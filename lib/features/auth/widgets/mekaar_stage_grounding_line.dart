import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/onboarding_tokens.dart';

/// Garis Pijakan Bersama (Shared Grounding Stage Line) untuk Onboarding MEKAAR.
/// Menjadi pijakan horizontal meruncing (tebal di tengah, tipis di ujung) berwarna solid Biru MEKAAR (#136CFC).
class MekaarStageGroundingLine extends StatelessWidget {
  const MekaarStageGroundingLine({
    super.key,
    this.color = AppColors.blue,
    this.width = MekaarOnboardingTokens.groundlineWidth,
    this.centerThickness = MekaarOnboardingTokens.groundlineCenterThickness,
    this.endThickness = MekaarOnboardingTokens.groundlineEndThickness,
  });

  final Color color;
  final double width;
  final double centerThickness;
  final double endThickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: centerThickness,
      child: CustomPaint(
        size: Size(width, centerThickness),
        painter: _TaperedGroundingLinePainter(
          color: color,
          centerThickness: centerThickness,
          endThickness: endThickness,
        ),
      ),
    );
  }
}

class _TaperedGroundingLinePainter extends CustomPainter {
  const _TaperedGroundingLinePainter({
    required this.color,
    required this.centerThickness,
    required this.endThickness,
  });

  final Color color;
  final double centerThickness;
  final double endThickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final double midY = size.height / 2;
    final double halfCenter = centerThickness / 2;
    final double halfEnd = (endThickness / 2).clamp(0.1, halfCenter);

    final path = Path();
    path.moveTo(halfEnd, midY - halfEnd);
    path.quadraticBezierTo(
      size.width / 2,
      midY - halfCenter,
      size.width - halfEnd,
      midY - halfEnd,
    );
    path.arcToPoint(
      Offset(size.width - halfEnd, midY + halfEnd),
      radius: Radius.circular(halfEnd),
    );
    path.quadraticBezierTo(
      size.width / 2,
      midY + halfCenter,
      halfEnd,
      midY + halfEnd,
    );
    path.arcToPoint(
      Offset(halfEnd, midY - halfEnd),
      radius: Radius.circular(halfEnd),
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TaperedGroundingLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.centerThickness != centerThickness ||
        oldDelegate.endThickness != endThickness;
  }
}
