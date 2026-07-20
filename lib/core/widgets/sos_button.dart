import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/haptic_service.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isActive;
  final double size;

  const SOSButton({
    super.key,
    this.onPressed,
    this.isActive = false,
    this.size = 76,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) return;
    _animationsDisabled = animationsDisabled;

    if (animationsDisabled) {
      _pulseController.stop();
      _pulseController.value = 0;
    } else {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (widget.onPressed == null) return;
    HapticService.trigger(MekaarHapticIntent.emergency);
    widget.onPressed!();
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
      label: 'Tombol SOS',
      hint: 'Aktifkan bantuan darurat',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: widget.onPressed == null ? null : _handlePress,
            radius: targetSize / 2,
            customBorder: const CircleBorder(),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = _pulseAnimation.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsating glow ring
                    Container(
                      width: widget.size * scale,
                      height: widget.size * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseColor.withValues(
                          alpha: widget.isActive ? 0.35 : 0.15,
                        ),
                      ),
                    ),
                    // Inner main button
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: baseColor,
                        boxShadow: [
                          BoxShadow(
                            color: baseColor.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: widget.isActive ? 6 : 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ExcludeSemantics(
                          child: Text(
                            'SOS',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
