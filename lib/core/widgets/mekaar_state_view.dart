import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import 'mika_illustration.dart';

enum MekaarStateLayout { centered, edge }

class MekaarStateView extends StatelessWidget {
  const MekaarStateView({
    super.key,
    required this.pose,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.layout = MekaarStateLayout.centered,
    this.illustrationSize = 112,
    this.semanticLabel,
    this.icon = SolarIconsOutline.refresh,
  });

  final MikaPose pose;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final MekaarStateLayout layout;
  final double illustrationSize;
  final String? semanticLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: layout == MekaarStateLayout.edge
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: layout == MekaarStateLayout.edge
              ? TextAlign.left
              : TextAlign.center,
          style: MekaarTypography.headingMD,
        ),
        const SizedBox(height: MekaarSpacing.sm),
        Text(
          message,
          textAlign: layout == MekaarStateLayout.edge
              ? TextAlign.left
              : TextAlign.center,
          style: MekaarTypography.bodyMD,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: MekaarSpacing.lg),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: Icon(icon, size: 18),
            label: Text(actionLabel!),
          ),
        ],
      ],
    );

    if (layout == MekaarStateLayout.edge) {
      return LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: MekaarSpacing.lg,
                  right: constraints.maxWidth < 360 ? 104 : 132,
                  top: MekaarSpacing.xl,
                  bottom: MekaarSpacing.xl,
                ),
                child: text,
              ),
              Positioned(
                right: -illustrationSize * 0.2,
                bottom: -illustrationSize * 0.12,
                child: MikaIllustration(
                  pose: pose,
                  size: illustrationSize,
                  semanticLabel: semanticLabel,
                  animate: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MekaarSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MikaIllustration(
                pose: pose,
                size: illustrationSize,
                semanticLabel: semanticLabel,
                animate: true,
              ),
              const SizedBox(height: MekaarSpacing.lg),
              text,
            ],
          ),
        ),
      ),
    );
  }
}
