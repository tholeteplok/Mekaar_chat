import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/shadows.dart';

/// Indikator "sedang mengetik" bergaya tiga titik memantul, tampil
/// sebagai bubble kecil di sisi kiri (seperti pesan masuk).
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: MekaarSpacing.xs,
          horizontal: MekaarSpacing.lg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MekaarColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: MekaarShadows.bubble,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _dot(i)),
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value - index * 0.2) % 1.0;
        final bounce = t < 0.5 ? (t * 2) : (2 - t * 2);
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          transform: Matrix4.translationValues(0, -3 * bounce, 0),
          decoration: BoxDecoration(
            color: MekaarColors.textMuted.withValues(alpha: 0.5 + 0.5 * bounce),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
