import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../services/haptic_service.dart';

/// Tombol konfirmasi berbasis tahan (Hold-to-Confirm) untuk aksi destruktif atau krusial.
/// Membutuhkan penahanan terus-menerus selama durasi yang ditentukan sebelum memicu [onTrigger].
class HoldToConfirmButton extends StatefulWidget {
  final VoidCallback onTrigger;
  final String label;
  final Duration duration;
  final Color color;
  final IconData icon;
  final IconData holdingIcon;
  final double height;
  final Duration hapticInterval;

  const HoldToConfirmButton({
    super.key,
    required this.onTrigger,
    required this.label,
    this.duration = const Duration(seconds: 3),
    this.color = MekaarColors.sosRed,
    this.icon = SolarIconsOutline.closeSquare,
    this.holdingIcon = SolarIconsBold.dangerSquare,
    this.height = 54.0,
    this.hapticInterval = const Duration(milliseconds: 500),
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hapticTimer?.cancel();
        HapticService.trigger(MekaarHapticIntent.success);
        widget.onTrigger();
        _controller.reset();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HoldToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    HapticService.trigger(MekaarHapticIntent.selection);
    _controller.forward(from: 0.0);
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(widget.hapticInterval, (_) {
      HapticService.trigger(MekaarHapticIntent.selection);
    });
  }

  void _onTapUp(TapUpDetails details) {
    _hapticTimer?.cancel();
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    _hapticTimer?.cancel();
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final durationSeconds = widget.duration.inSeconds > 0
        ? widget.duration.inSeconds.toDouble()
        : (widget.duration.inMilliseconds / 1000.0);

    return Semantics(
      button: true,
      hint: 'Tahan ${widget.duration.inSeconds} detik untuk ${widget.label}',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final isHolding = progress > 0.02;
            final remainingSeconds = (durationSeconds - (progress * durationSeconds))
                .clamp(0.1, durationSeconds);

            return Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isHolding
                    ? widget.color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHolding
                      ? widget.color
                      : widget.color.withValues(alpha: 0.6),
                  width: isHolding ? 2 : 1.2,
                ),
              ),
              child: Stack(
                children: [
                  // Progress fill layer (Linear Fill)
                  if (!animationsDisabled)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          color: widget.color.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  // Text & Icon
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isHolding ? widget.holdingIcon : widget.icon,
                          color: widget.color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isHolding
                              ? 'Tahan... ${remainingSeconds.toStringAsFixed(1)}d'
                              : 'Tahan ${widget.duration.inSeconds} Detik: ${widget.label}',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
