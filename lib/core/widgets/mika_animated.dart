import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/motion.dart';
import 'mika_illustration.dart';

/// Reaksi satu-kali yang dimainkan oleh [MikaAnimated].
/// Setelah reaksi selesai, animasi idle (breathing) dilanjutkan otomatis.
enum MikaReaction {
  happy,
  love,
  hi,
  ok,
  huft,
  shield,
  ask,
  sleep,
  phone,
  pin,
  hide,
  neutral;

  /// Durasi default untuk reaksi ini.
  Duration get duration => switch (this) {
        MikaReaction.happy => const Duration(milliseconds: 500),
        MikaReaction.love => const Duration(milliseconds: 500),
        MikaReaction.hi => const Duration(milliseconds: 600),
        MikaReaction.ok => const Duration(milliseconds: 400),
        MikaReaction.huft => const Duration(milliseconds: 400),
        MikaReaction.shield => const Duration(milliseconds: 600),
        MikaReaction.ask => const Duration(milliseconds: 800),
        MikaReaction.sleep => const Duration(milliseconds: 2000),
        MikaReaction.phone => const Duration(milliseconds: 500),
        MikaReaction.pin => const Duration(milliseconds: 300),
        MikaReaction.hide => const Duration(milliseconds: 400),
        MikaReaction.neutral => Duration.zero,
      };
}

/// Widget maskot Mika dengan animasi idle (breathing) dan reaksi satu-kali.
///
/// Gunakan [GlobalKey] untuk memicu reaksi dari parent:
/// ```dart
/// final _mikaKey = GlobalKey<MikaAnimatedState>();
/// _mikaKey.currentState?.react(MikaReaction.happy);
/// ```
class MikaAnimated extends StatefulWidget {
  const MikaAnimated({
    super.key,
    required this.pose,
    this.size = 120,
    this.idle = true,
    this.semanticLabel,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final MikaPose pose;
  final double size;
  final bool idle;
  final String? semanticLabel;
  final BoxFit fit;
  final Alignment alignment;

  @override
  State<MikaAnimated> createState() => MikaAnimatedState();
}

class MikaAnimatedState extends State<MikaAnimated>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  AnimationController? _reactionController;
  MikaReaction? _activeReaction;
  int _reactionId = 0;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: MekaarMotion.idle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idleController.stop();
    } else if (_reactionController == null) {
      _startIdle();
    }
  }

  @override
  void didUpdateWidget(covariant MikaAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.idle != oldWidget.idle) {
      if (widget.idle && _reactionController == null) {
        _startIdle();
      } else {
        _idleController.stop();
      }
    }
  }

  void _startIdle() {
    if (!widget.idle) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (!_idleController.isAnimating) {
      _idleController.repeat(reverse: true);
    }
  }

  /// Picu reaksi satu-kali. Idle dijeda selama reaksi bermain,
  /// lalu dilanjutkan otomatis setelah selesai.
  void react(MikaReaction reaction) {
    if (!mounted) return;
    if (reaction == MikaReaction.neutral) return;
    if (MediaQuery.disableAnimationsOf(context)) return;

    _idleController.stop();
    _reactionController?.dispose();

    final id = ++_reactionId;
    _activeReaction = reaction;
    _reactionController = AnimationController(
      vsync: this,
      duration: reaction.duration,
    );

    _reactionController!.forward().then((_) {
      if (!mounted || id != _reactionId) return;
      _activeReaction = null;
      _reactionController?.dispose();
      _reactionController = null;
      setState(() {});
      _startIdle();
    });
    setState(() {});
  }

  @override
  void dispose() {
    _idleController.dispose();
    _reactionController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        widget.pose.assetPath,
        fit: widget.fit,
        alignment: widget.alignment,
        excludeFromSemantics: widget.semanticLabel == null,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return image;

    // Reaksi aktif menimpa idle
    if (_reactionController != null && _activeReaction != null) {
      return AnimatedBuilder(
        animation: _reactionController!,
        builder: (context, child) => _buildReactionTransform(
          _activeReaction!,
          _reactionController!.value,
          child,
        ),
        child: image,
      );
    }

    // Idle breathing
    if (widget.idle) {
      return AnimatedBuilder(
        animation: _idleController,
        builder: (context, child) {
          final scale = 1.0 + 0.03 * math.sin(math.pi * _idleController.value);
          return Transform.scale(scale: scale, child: child);
        },
        child: image,
      );
    }

    return image;
  }

  /// Bangun transformasi untuk reaksi pada progress [t] (0.0–1.0).
  Widget _buildReactionTransform(
    MikaReaction reaction,
    double t,
    Widget? child,
  ) {
    switch (reaction) {
      case MikaReaction.happy:
        return Transform.scale(
          scale: 1.0 + 0.2 * math.sin(math.pi * t),
          child: child,
        );

      case MikaReaction.love:
        return Transform.translate(
          offset: Offset(0, -10 * math.sin(math.pi * t)),
          child: Transform.scale(
            scale: 1.0 + 0.15 * math.sin(math.pi * t),
            child: Transform.rotate(
              angle: 0.1 * math.sin(2 * math.pi * t),
              child: child,
            ),
          ),
        );

      case MikaReaction.hi:
        return Transform.translate(
          offset: Offset(0, -20 * math.sin(math.pi * t)),
          child: Transform.rotate(
            angle: 0.15 * math.sin(2 * math.pi * t),
            child: child,
          ),
        );

      case MikaReaction.ok:
        return Transform.scale(
          scale: 0.85 + 0.15 * Curves.easeOutBack.transform(t),
          child: child,
        );

      case MikaReaction.huft:
        final shake = 8 * math.sin(8 * math.pi * t) * (1 - t);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );

      case MikaReaction.shield:
        return Transform.scale(
          scale: 1.0 + 0.08 * math.sin(math.pi * t),
          child: child,
        );

      case MikaReaction.ask:
        return Transform.translate(
          offset: Offset(0, -8 * math.sin(math.pi * t)),
          child: child,
        );

      case MikaReaction.sleep:
        return Transform.scale(
          scale: 1.0 + 0.03 * math.sin(math.pi * t),
          child: child,
        );

      case MikaReaction.phone:
        return Transform.rotate(
          angle: -0.15 * math.sin(math.pi * t),
          child: child,
        );

      case MikaReaction.pin:
        return Transform.scale(
          scale: 1.0 + 0.08 * math.sin(math.pi * t),
          child: child,
        );

      case MikaReaction.hide:
        return Opacity(
          opacity: 1.0 - 0.5 * t,
          child: Transform.scale(
            scale: 1.0 - 0.3 * t,
            child: child,
          ),
        );

      case MikaReaction.neutral:
        return child ?? const SizedBox.shrink();
    }
  }
}
