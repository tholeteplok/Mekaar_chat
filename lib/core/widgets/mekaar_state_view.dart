import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import 'mika_animated.dart';
import 'mika_illustration.dart';

enum MekaarStateLayout { centered, edge }

class MekaarStateView extends StatefulWidget {
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
  State<MekaarStateView> createState() => _MekaarStateViewState();
}

class _MekaarStateViewState extends State<MekaarStateView> {
  final _mikaKey = GlobalKey<MikaAnimatedState>();

  @override
  void initState() {
    super.initState();
    if (widget.reaction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mikaKey.currentState?.react(widget.reaction!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MekaarStateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reaction != oldWidget.reaction && widget.reaction != null) {
      _mikaKey.currentState?.react(widget.reaction!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdge = widget.layout == MekaarStateLayout.edge;

    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isEdge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          widget.title,
          textAlign: isEdge ? TextAlign.left : TextAlign.center,
          style: MekaarTypography.headingMD,
        ),
        const SizedBox(height: MekaarSpacing.sm),
        Text(
          widget.message,
          textAlign: isEdge ? TextAlign.left : TextAlign.center,
          style: MekaarTypography.bodyMD,
        ),
        if (widget.actionLabel != null && widget.onAction != null) ...[
          const SizedBox(height: MekaarSpacing.lg),
          ElevatedButton.icon(
            onPressed: widget.onAction,
            icon: Icon(widget.icon, size: 18),
            label: Text(widget.actionLabel!),
          ),
        ],
      ],
    );

    final mika = MikaAnimated(
      key: _mikaKey,
      pose: widget.pose,
      size: widget.illustrationSize,
      semanticLabel: widget.semanticLabel,
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
                right: -widget.illustrationSize * 0.2,
                bottom: -widget.illustrationSize * 0.12,
                child: mika,
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
              mika,
              const SizedBox(height: MekaarSpacing.lg),
              text,
            ],
          ),
        ),
      ),
    );
  }
}
