import 'package:flutter/material.dart';

import '../constants/motion.dart';
import '../constants/typography.dart';

/// Widget yang menganimasikan angka dari nilai lama ke nilai baru
/// dengan efek roll (IntTween + eased curve).
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = MekaarMotion.counter,
    this.style,
    this.semanticLabel,
  });

  final int value;
  final Duration duration;
  final TextStyle? style;
  final String? semanticLabel;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<int> _animation;
  int _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = IntTween(begin: _oldValue, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: MekaarMotion.bounce));
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(begin: _oldValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: MekaarMotion.bounce),
      );
      _oldValue = widget.value;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        '${widget.value}',
        style: widget.style ?? MekaarTypography.badge,
        semanticsLabel: widget.semanticLabel,
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value}',
          style: widget.style ?? MekaarTypography.badge,
          semanticsLabel: widget.semanticLabel,
        );
      },
    );
  }
}
