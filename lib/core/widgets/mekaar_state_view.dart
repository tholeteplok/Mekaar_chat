import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import 'mika_animated.dart';
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
    this.reaction,
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
  final MikaReaction? reaction;

  @override
  Widget build(BuildContext context) {
    final isEdge = layout == MekaarStateLayout.edge;

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isEdge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: isEdge ? TextAlign.left : TextAlign.center,
          style: MekaarTypography.headingMD,
        ),
        const SizedBox(height: MekaarSpacing.sm),
        Text(
          message,
          textAlign: isEdge ? TextAlign.left : TextAlign.center,
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

    final mika = MikaAnimated(
      pose: pose,
      size: illustrationSize,
      semanticLabel: semanticLabel,
      reaction: reaction,
    );

    if (isEdge) {
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
                child: mika,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final minH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 0.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MekaarSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minH > (MekaarSpacing.xl * 2)
                    ? minH - (MekaarSpacing.xl * 2)
                    : 0.0,
                maxWidth: 420,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mika,
                  const SizedBox(height: MekaarSpacing.lg),
                  text,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
