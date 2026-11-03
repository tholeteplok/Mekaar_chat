import 'package:flutter/material.dart';
import '../../../core/constants/onboarding_tokens.dart';

/// Garis Pijakan Bersama (Shared Grounding Stage Line) untuk Onboarding MEKAAR.
/// Menjadi panggung horizontal tetap yang mengikat seluruh slide dan memberi
/// jangkar gravitasi fisik pada karakter Mika.
class MekaarStageGroundingLine extends StatelessWidget {
  const MekaarStageGroundingLine({
    super.key,
    required this.accentColor,
    this.width = MekaarOnboardingTokens.groundlineWidth,
    this.height = MekaarOnboardingTokens.groundlineHeight,
    this.showContactShadow = true,
  });

  final Color accentColor;
  final double width;
  final double height;
  final bool showContactShadow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // ── Contact Shadow Halus di Bawah Telapak Kaki ──
          if (showContactShadow)
            Positioned(
              bottom: -4,
              child: Container(
                width: 110,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),

          // ── Garis Pijakan Minimalis dengan Pendaran (Glow) Tipis ──
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  accentColor.withValues(alpha: 0.20),
                  accentColor.withValues(alpha: 0.70),
                  accentColor.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.20, 0.50, 0.80, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.20),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
