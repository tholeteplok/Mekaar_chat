import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/motion.dart';
import '../services/haptic_service.dart';

/// Tombol Darurat SOS dengan dukungan Hold-to-Confirm (2 detik) untuk aktivasi
/// dan 1-tap info saat sesi darurat sudah aktif.
class SOSButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isActive;
  final double size;
  final Duration holdDuration;

  const SOSButton({
    super.key,
    this.onPressed,
    this.isActive = false,
    this.size = 76,
    this.holdDuration = const Duration(seconds: 2),
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _holdController;
  Timer? _hapticTimer;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    // 1. Controller untuk animasi pulsasi idle saat status aktif
    _pulseController = AnimationController(
      duration: MekaarMotion.idle,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Controller untuk animasi hold-to-confirm progress ring (2 detik)
    _holdController = AnimationController(
      duration: widget.holdDuration,
      vsync: this,
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hapticTimer?.cancel();
        setState(() => _isHolding = false);
        HapticService.trigger(MekaarHapticIntent.emergency);
        widget.onPressed?.call();
        _holdController.reset();
      }
    });
  }

  void _syncPulseState() {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (widget.isActive && !animationsDisabled) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating || _pulseController.value != 0) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseState();
  }

  @override
  void didUpdateWidget(covariant SOSButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _syncPulseState();
      if (widget.isActive && _isHolding) {
        _hapticTimer?.cancel();
        _isHolding = false;
        _holdController.reset();
      }
    }
    if (widget.holdDuration != oldWidget.holdDuration) {
      _holdController.duration = widget.holdDuration;
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null || widget.isActive) return;
    setState(() => _isHolding = true);
    HapticService.trigger(MekaarHapticIntent.selection);
    _holdController.forward(from: 0.0);

    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      HapticService.trigger(MekaarHapticIntent.selection);
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isActive) {
      // Saat aktif, 1-tap langsung membuka layar info SOS
      HapticService.trigger(MekaarHapticIntent.selection);
      widget.onPressed?.call();
      return;
    }
    _cancelHold();
  }

  void _onTapCancel() {
    if (widget.isActive) return;
    _cancelHold();
  }

  void _cancelHold() {
    _hapticTimer?.cancel();
    if (_isHolding) {
      setState(() => _isHolding = false);
    }
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  Widget _buildButtonContent(BuildContext context, Color baseColor, double pulseScale, double holdProgress) {
    final ringPadding = 6.0;
    final totalSize = widget.size + (ringPadding * 2);
    final buttonSize = widget.size;

    return SizedBox(
      width: totalSize * (widget.isActive ? pulseScale : 1.0),
      height: totalSize * (widget.isActive ? pulseScale : 1.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring saat aktif
          if (widget.isActive)
            Container(
              width: buttonSize * pulseScale,
              height: buttonSize * pulseScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor.withValues(alpha: 0.35),
              ),
            ),

          // Circular Progress Ring saat ditahan (Hold-to-Confirm)
          if (!widget.isActive && holdProgress > 0.01)
            CustomPaint(
              size: Size(totalSize, totalSize),
              painter: _SOSCircularProgressPainter(
                progress: holdProgress,
                color: MekaarColors.sosRed,
                strokeWidth: 4.0,
              ),
            ),

          // Inner main button
          Transform.scale(
            scale: _isHolding ? 0.94 : 1.0,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: widget.isActive ? 0.5 : 0.35),
                    blurRadius: widget.isActive ? 22 : (_isHolding ? 8 : 14),
                    spreadRadius: widget.isActive ? 4 : (_isHolding ? 0 : 1),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: ExcludeSemantics(
                  child: Text(
                    'SOS',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: (buttonSize * 0.25).clamp(13.0, 20.0),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isActive
        ? MekaarColors.sosDeep
        : MekaarColors.sosRed;
    final targetSize = widget.size < 48 ? 48.0 : widget.size;

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      liveRegion: true,
      label: widget.isActive
          ? 'Sesi Darurat SOS Sedang Aktif'
          : 'Tombol Darurat SOS',
      hint: widget.isActive
          ? 'Ketuk untuk melihat status darurat'
          : 'Tahan ${widget.holdDuration.inSeconds} detik untuk mengirim sinyal darurat ke Guardian dan kontak terdekat',
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: targetSize, minHeight: targetSize),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnimation, _holdController]),
            builder: (context, _) => _buildButtonContent(
              context,
              baseColor,
              widget.isActive ? _pulseAnimation.value : 1.0,
              _holdController.value,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter untuk menggambar Circular Progress Ring di sekeliling tombol SOS.
class _SOSCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _SOSCircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Background Track halus
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    // Mulai dari atas (-pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SOSCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
