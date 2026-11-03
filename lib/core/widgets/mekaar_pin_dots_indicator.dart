import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/motion.dart';

/// Komponen terpusat untuk menampilkan bulatan indikator PIN 6-digit.
///
/// Mendukung:
/// 1. Indikasi digit terisi & digit aktif (fokus).
/// 2. Mode privasi intip angka (`obscurePin = false`) dengan sensor otomatis saat validasi.
/// 3. Animasi gelombang sinus bertingkat (*staggered sine wave*) saat `isValidating = true`.
/// 4. Animasi getar horizontal (*shake error*) saat `hasError = true`.
/// 5. Kepatuhan aksesibilitas *reduce motion* (`MekaarMotionContext.reduceMotion`).
class MekaarPinDotsIndicator extends StatefulWidget {
  final int pinLength;
  final int enteredLength;
  final bool isValidating;
  final bool hasError;
  final bool obscurePin;
  final String pinText;
  final double dotSize;
  final double dotSpacing;
  final Color? activeColor;
  final Color? errorColor;
  final VoidCallback? onShakeCompleted;

  const MekaarPinDotsIndicator({
    super.key,
    this.pinLength = 6,
    required this.enteredLength,
    this.isValidating = false,
    this.hasError = false,
    this.obscurePin = true,
    this.pinText = '',
    this.dotSize = 20.0,
    this.dotSpacing = 10.0,
    this.activeColor,
    this.errorColor,
    this.onShakeCompleted,
  });

  @override
  State<MekaarPinDotsIndicator> createState() => _MekaarPinDotsIndicatorState();
}

class _MekaarPinDotsIndicatorState extends State<MekaarPinDotsIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Controller untuk gelombang sinus berulang (1 siklus = 600 ms)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 2. Controller untuk animasi getar saat PIN salah (shake horizontal)
    _shakeController = AnimationController(
      vsync: this,
      duration: MekaarMotion.slow,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -12.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -12.0, end: 12.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 12.0, end: -8.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -8.0, end: 8.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 8.0, end: -4.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -4.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_shakeController);

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onShakeCompleted?.call();
      }
    });

    if (widget.isValidating) {
      _startWaveAnimation();
    }

    if (widget.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (context.reduceMotion) {
          widget.onShakeCompleted?.call();
        } else {
          _shakeController.forward(from: 0.0);
        }
      });
    }
  }

  void _startWaveAnimation() {
    if (!mounted) return;
    _waveController.repeat();
  }

  void _stopWaveAnimation() {
    if (!mounted) return;
    _waveController.stop();
    _waveController.value = 0.0;
  }

  @override
  void didUpdateWidget(covariant MekaarPinDotsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Transisi status validasi
    if (widget.isValidating != oldWidget.isValidating) {
      if (widget.isValidating) {
        _startWaveAnimation();
      } else {
        _stopWaveAnimation();
      }
    }

    // Transisi status error (memicu shake)
    if (widget.hasError && !oldWidget.hasError) {
      if (context.reduceMotion) {
        widget.onShakeCompleted?.call();
      } else {
        _shakeController.forward(from: 0.0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _shakeController.stop();
      _shakeController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    final effectiveActiveColor = widget.activeColor ?? AppColors.blue;
    final effectiveErrorColor = widget.errorColor ?? MekaarColors.sosCoral;
    final textPrimary = MekaarColors.textPrimaryOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _waveController]),
      builder: (context, _) {
        final shakeOffset = reduceMotion ? 0.0 : _shakeAnimation.value;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: SizedBox(
            // Sediakan ruang vertikal bebas agar translasi tidak terpotong (clipping)
            height: widget.dotSize + 20.0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (index) {
                  return _buildSingleDot(
                    index: index,
                    reduceMotion: reduceMotion,
                    activeColor: effectiveActiveColor,
                    errorColor: effectiveErrorColor,
                    textPrimary: textPrimary,
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleDot({
    required int index,
    required bool reduceMotion,
    required Color activeColor,
    required Color errorColor,
    required Color textPrimary,
  }) {
    final isFilled = widget.enteredLength > index;
    final isCurrent = widget.enteredLength == index;

    double translateY = 0.0;
    double dotOpacity = 1.0;
    List<BoxShadow>? shadows;
    Color dotColor = Colors.transparent;
    Color borderColor = activeColor.withValues(alpha: 0.4);
    double borderWidth = 1.6;

    if (widget.isValidating) {
      // ── Status: Sedang Memvalidasi (Gelombang Sinus) ──
      borderWidth = 2.0;
      borderColor = activeColor;

      if (!reduceMotion) {
        // Formulasi gelombang sinus bertingkat per index
        final phase = (_waveController.value * 2 * math.pi) - (index * (math.pi / 3));
        final sinVal = math.sin(phase); // -1.0 .. 1.0

        // Koordinat Y: Puncak naik -5.0px, lembah turun +5.0px
        translateY = sinVal * 5.0;

        // Modulasi opasitas lembut dari 0.70 (lembah) ke 1.00 (puncak)
        final normalizedSine = (sinVal + 1.0) / 2.0; // 0.0 .. 1.0
        dotOpacity = 0.70 + (0.30 * normalizedSine);

        dotColor = activeColor.withValues(alpha: dotOpacity);

        // Efek pendaran (glow) dinamis saat mendekati puncak gelombang
        if (normalizedSine > 0.4) {
          shadows = [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.20 + (0.30 * normalizedSine)),
              blurRadius: 4.0 + (5.0 * normalizedSine),
              spreadRadius: 0.5 + (0.5 * normalizedSine),
            ),
          ];
        }
      } else {
        // Aksesibilitas Reduce Motion: Translasi Y tetap nol, modulasi napas halus (pulsing)
        final breath = (math.sin(_waveController.value * 2 * math.pi) + 1.0) / 2.0;
        dotOpacity = 0.65 + (0.35 * breath);
        dotColor = activeColor.withValues(alpha: dotOpacity);
        shadows = [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.25 * dotOpacity),
            blurRadius: 6.0,
            spreadRadius: 0.5,
          ),
        ];
      }
    } else {
      // ── Status: Pengetikan Normal / Hasil ──
      if (widget.hasError) {
        borderColor = errorColor;
        borderWidth = 2.0;
        dotColor = errorColor;
        shadows = [
          BoxShadow(
            color: errorColor.withValues(alpha: 0.45),
            blurRadius: 8.0,
            spreadRadius: 1.0,
          ),
        ];
      } else if (isFilled) {
        borderColor = activeColor;
        borderWidth = 2.2;
        dotColor = widget.obscurePin ? activeColor : Colors.transparent;
        if (widget.obscurePin) {
          shadows = [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.45),
              blurRadius: 8.0,
              spreadRadius: 1.0,
            ),
          ];
        }
      } else if (isCurrent) {
        borderColor = activeColor.withValues(alpha: 0.75);
        borderWidth = 2.0;
        dotColor = activeColor.withValues(alpha: 0.15);
      }
    }

    final hasText = isFilled &&
        !widget.obscurePin &&
        !widget.isValidating &&
        index < widget.pinText.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.dotSpacing / 2),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: dotOpacity,
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              boxShadow: shadows,
            ),
            child: hasText
                ? Center(
                    child: Text(
                      widget.pinText[index],
                      style: TextStyle(
                        fontSize: widget.dotSize * 0.55,
                        fontWeight: FontWeight.bold,
                        color: widget.hasError ? errorColor : textPrimary,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
