import 'package:flutter/material.dart';
import '../../theme/chat_preset_resolver.dart';

/// Generic Entrance Animation Wrapper for all 12 Presets.
class AnimatedPresetBubbleEntrance extends StatefulWidget {
  final Widget child;
  final BubbleEntranceSpec spec;

  const AnimatedPresetBubbleEntrance({
    super.key,
    required this.child,
    required this.spec,
  });

  @override
  State<AnimatedPresetBubbleEntrance> createState() =>
      _AnimatedPresetBubbleEntranceState();
}

class _AnimatedPresetBubbleEntranceState
    extends State<AnimatedPresetBubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.spec.duration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.spec.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.spec.type) {
      // 1. Neumorphism: Scale 0.97 -> 1.0 + fade
      case EntranceType.neumorphismSoft:
        return FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(_animation),
            child: widget.child,
          ),
        );

      // 2. Glassmorphism: Opacity fade-in 280ms
      case EntranceType.glassmorphismBlur:
        return FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(_animation),
            child: widget.child,
          ),
        );

      // 3. Pixel Garden 8-Bit: 3-frame discrete step scale 0.7 -> 0.9 -> 1.0 + scanline flicker
      case EntranceType.pixelGlitchStep:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final val = _animation.value;
            double scale = 0.7;
            double opacity = 0.6;
            if (val >= 0.66) {
              scale = 1.0;
              opacity = 1.0;
            } else if (val >= 0.33) {
              scale = 0.9;
              opacity = 0.85;
            }
            return Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: widget.child,
        );

      // 4. Isometric 3D: Rigid translateY 6px -> 0px 120ms (linear snap)
      case EntranceType.isometricSnap:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final dy = (1.0 - _animation.value) * 6.0;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: widget.child,
        );

      // 5. Retro Y2K: Header titlebar first / instant snap
      case EntranceType.retroY2KHeaderFirst:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Opacity(
              opacity: _animation.value >= 0.2 ? 1.0 : 0.0,
              child: child,
            );
          },
          child: widget.child,
        );

      // 6. Swiss Minimalist: Horizontal clip reveal dari kiri ke kanan 150ms
      case EntranceType.swissRevealHorizontal:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: _animation.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: widget.child,
        );

      // 7. Solarpunk: Scale 0.6 -> 1.0 elastic growth
      case EntranceType.solarpunkGrowth:
        return FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(_animation),
            child: widget.child,
          ),
        );

      // 8. Neon Cyberpunk: Flicker kedipan cepat 3-4x 200ms
      case EntranceType.neonFlickerGlow:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final val = _animation.value;
            double opacity = 1.0;
            if (val < 0.2) {
              opacity = val * 5.0;
            } else if (val < 0.4) {
              opacity = 0.3;
            } else if (val < 0.7) {
              opacity = 1.0;
            } else if (val < 0.85) {
              opacity = 0.6;
            } else {
              opacity = 1.0;
            }

            return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
          },
          child: widget.child,
        );

      // 9. Comic Pop Art: Elastic bounce scale 0.7 -> 1.15 -> 1.0 dengan rotasi ±3°
      case EntranceType.comicPopElastic:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final val = _animation.value;
            final rot = (1.0 - val) * 0.05; // ~ 3 degrees
            return Transform.rotate(
              angle: rot,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.0).animate(_animation),
                child: child,
              ),
            );
          },
          child: widget.child,
        );

      // 10. Firefly Night: Slow fade-in 450ms
      case EntranceType.fireflySlowGlow:
        return FadeTransition(opacity: _animation, child: widget.child);

      // 11. Buku Harian: Fade + slide 4px dari kiri (searah tulisan)
      case EntranceType.diaryWritingSlideLeft:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final dx = (1.0 - _animation.value) * -4.0;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Opacity(
                opacity: _animation.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: widget.child,
        );

      // 12. Mekaar Clean: Standard fade 0->1 + slide 8px dari bawah 200ms
      case EntranceType.mekaarFadeSlide:
      case EntranceType.dynamicTimeFadeSlide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(_animation),
          child: FadeTransition(opacity: _animation, child: widget.child),
        );
    }
  }
}
