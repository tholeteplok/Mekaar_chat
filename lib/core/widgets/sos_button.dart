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

  Widget _buildButtonContent(BuildContext context, Color baseColor, double scale) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        if (widget.isActive)
          Container(
            width: widget.size * scale,
            height: widget.size * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor.withValues(alpha: 0.35),
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
                color: baseColor.withValues(alpha: widget.isActive ? 0.5 : 0.35),
                blurRadius: widget.isActive ? 22 : 14,
                spreadRadius: widget.isActive ? 4 : 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                'SOS',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: (widget.size * 0.25).clamp(13.0, 20.0),
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
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isActive
        ? MekaarColors.sosDeep
        : MekaarColors.sosRed;
    final targetSize = widget.size < 48 ? 48.0 : widget.size;

    final buttonContent = widget.isActive
        ? AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => _buildButtonContent(
              context,
              baseColor,
              _pulseAnimation.value,
            ),
          )
        : _buildButtonContent(context, baseColor, 1.0);

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      liveRegion: true,
      label: widget.isActive
          ? 'Sesi Darurat SOS Sedang Aktif'
          : 'Tombol Darurat SOS',
      hint: widget.isActive
          ? 'Ketuk untuk melihat status darurat'
          : 'Ketuk untuk mengirim sinyal darurat ke Guardian dan kontak terdekat',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: widget.onPressed == null ? null : _handlePress,
            radius: targetSize / 2,
            customBorder: const CircleBorder(),
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
