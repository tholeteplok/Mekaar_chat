import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';

/// Header visual yang konsisten untuk halaman utama pada bottom navigation.
class MekaarTabHeader extends StatefulWidget {
  const MekaarTabHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  State<MekaarTabHeader> createState() => _MekaarTabHeaderState();
}

class _MekaarTabHeaderState extends State<MekaarTabHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final titleText = Text(
      widget.title,
      style: MekaarTypography.displayLG.copyWith(
        color: MekaarColors.textPrimaryOf(context),
      ),
    );
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: disableAnimations
                  ? titleText
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final t = _controller.value;
                        return ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (bounds) {
                            final sweepX = (t * 2.0 - 0.5) * bounds.width;
                            return LinearGradient(
                              colors: [
                                Colors.transparent,
                                MekaarColors.textPrimaryOf(context).withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment(
                                (sweepX - bounds.width * 0.3) /
                                    bounds.width,
                                0,
                              ),
                              end: Alignment(
                                (sweepX + bounds.width * 0.3) /
                                    bounds.width,
                                0,
                              ),
                            ).createShader(bounds);
                          },
                          child: titleText,
                        );
                      },
                    ),
            ),
            if (widget.action != null) ...[
              const SizedBox(width: 12),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }
}
