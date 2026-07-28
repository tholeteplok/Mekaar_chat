import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BounceInteractive adalah widget pembungkus yang memberikan efek
/// micro-interaksi:
/// 1. Skala visual mengecil lembut (springy bounce effect) saat ditekan.
/// 2. Konfirmasi taktil getaran fisik ringan (HapticFeedback.lightImpact)
///    saat sentuhan pertama.
///
/// Versi lokal Mekaar_chat (diadopsi dari Rhytmu). Self-contained, tanpa
/// dependency eksternal.
class BounceInteractive extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const BounceInteractive({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<BounceInteractive> createState() => _BounceInteractiveState();
}

class _BounceInteractiveState extends State<BounceInteractive>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse().then((_) {
        if (mounted) {
          widget.onTap!();
        }
      });
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jika onTap null, jangan tampilkan animasi agar visual konsisten
    // dengan status disabled.
    if (widget.onTap == null) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
