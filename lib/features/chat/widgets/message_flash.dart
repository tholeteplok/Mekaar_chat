import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';

/// Widget pembungkus sorotan biru (flash highlight) terisolasi saat melompat
/// ke pesan tertentu dalam obrolan.
///
/// Menggunakan [ValueListenable] eksternal sehingga hanya widget gelembung yang
/// ditargetkan yang melakukan repaint/rebuild, menjaga performa scroll tetap 60/120fps.
class MessageFlash extends StatefulWidget {
  final String messageId;
  final ValueListenable<String?>? flashIdListenable;
  final Widget child;
  final BorderRadius? borderRadius;

  const MessageFlash({
    super.key,
    required this.messageId,
    required this.flashIdListenable,
    required this.child,
    this.borderRadius,
  });

  @override
  State<MessageFlash> createState() => _MessageFlashState();
}

class _MessageFlashState extends State<MessageFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  Timer? _reduceMotionTimer;
  bool _reduceMotionActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MekaarMotion.cinematic,
    );
    _opacityAnimation = Tween<double>(
      begin: 0.18,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));
    widget.flashIdListenable?.addListener(_handleFlashChanged);
  }

  @override
  void didUpdateWidget(covariant MessageFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flashIdListenable != widget.flashIdListenable) {
      oldWidget.flashIdListenable?.removeListener(_handleFlashChanged);
      widget.flashIdListenable?.addListener(_handleFlashChanged);
    }
  }

  void _handleFlashChanged() {
    if (!mounted) return;
    final targetId = widget.flashIdListenable?.value;
    if (targetId == widget.messageId) {
      if (context.reduceMotion) {
        _reduceMotionTimer?.cancel();
        setState(() => _reduceMotionActive = true);
        _reduceMotionTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() => _reduceMotionActive = false);
          }
        });
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _reduceMotionTimer?.cancel();
    widget.flashIdListenable?.removeListener(_handleFlashChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(MekaarRadius.md);

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double currentOpacity = _reduceMotionActive
                    ? 0.18
                    : (_controller.isAnimating ? _opacityAnimation.value : 0.0);

                if (currentOpacity <= 0.0) {
                  return const SizedBox.shrink();
                }

                return ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    color: MekaarColors.blue.withValues(alpha: currentOpacity),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
