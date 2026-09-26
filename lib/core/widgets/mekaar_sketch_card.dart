import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

enum SketchCornerAccent { topLeft, topRight, bottomRight, bottomLeft, none }

/// MekaarSketchCard — Komponen kartu dengan border sketsa arang (Citrea Style).
/// Memiliki radius tetap seragam (16px) dengan 2 aksen goresan arang acak berjarak minimal
/// (1.25px - 0.5px) dan pencil tick arsitektur yang halus.
class MekaarSketchCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final SketchCornerAccent? accent;
  final List<SketchCornerAccent>? accents;
  final int? index;
  final int? seed;
  final bool showPencilTicks;

  const MekaarSketchCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius = MekaarRadius.card,
    this.accent,
    this.accents,
    this.index,
    this.seed,
    this.showPencilTicks = true,
  });

  @override
  State<MekaarSketchCard> createState() => _MekaarSketchCardState();
}

class _MekaarSketchCardState extends State<MekaarSketchCard> {
  late final int _stableSeed;

  @override
  void initState() {
    super.initState();
    _stableSeed = widget.seed ?? widget.index ?? Random().nextInt(1000);
  }

  List<SketchCornerAccent> _resolveAccents() {
    if (widget.accents != null) return widget.accents!;
    if (widget.accent != null) return [widget.accent!];
    final seed = widget.seed ?? widget.index ?? _stableSeed;
    return MekaarSketchBorderPainter.resolveDualAccents(seed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = widget.color ?? MekaarColors.surfaceOf(context);
    final activeAccents = _resolveAccents();

    Widget content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: content,
      );
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
      child: CustomPaint(
        foregroundPainter: MekaarSketchBorderPainter(
          borderRadius: widget.borderRadius,
          accents: activeAccents,
          isDark: isDark,
          showPencilTicks: widget.showPencilTicks,
        ),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}

/// CustomPainter terpusat untuk menggambar border sketsa arang Citrea.
/// Mendukung 2 goresan aksen per kartu dengan batasan jarak minimal.
class MekaarSketchBorderPainter extends CustomPainter {
  final double borderRadius;
  final List<SketchCornerAccent> accents;
  final bool isDark;
  final bool showPencilTicks;

  MekaarSketchBorderPainter({
    required this.borderRadius,
    List<SketchCornerAccent>? accents,
    SketchCornerAccent? accent,
    required this.isDark,
    this.showPencilTicks = true,
  }) : accents =
           accents ??
           (accent != null
               ? [accent]
               : const [
                   SketchCornerAccent.topLeft,
                   SketchCornerAccent.bottomRight,
                 ]);

  SketchCornerAccent get accent =>
      accents.isNotEmpty ? accents.first : SketchCornerAccent.none;

  /// Menghasilkan 2 aksen sudut acak deterministik berbasis seed
  /// dengan jaminan jarak minimal (diagonal berlawanan / pemisahan 2 sudut)
  /// agar tidak terjadi tabrakan atau penumpukan di satu sisi kartu.
  static List<SketchCornerAccent> resolveDualAccents(int seed) {
    final variant = seed.abs() % 4;
    switch (variant) {
      case 0:
        return const [
          SketchCornerAccent.topLeft,
          SketchCornerAccent.bottomRight,
        ];
      case 1:
        return const [
          SketchCornerAccent.topRight,
          SketchCornerAccent.bottomLeft,
        ];
      case 2:
        return const [
          SketchCornerAccent.bottomRight,
          SketchCornerAccent.topLeft,
        ];
      case 3:
      default:
        return const [
          SketchCornerAccent.bottomLeft,
          SketchCornerAccent.topRight,
        ];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = borderRadius;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // 1. Base Card Outline (0.75px abu muda)
    final basePaint = Paint()
      ..color = isDark
          ? MekaarColors.borderDark.withValues(alpha: 0.6)
          : MekaarColors.borderLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.drawRRect(rrect, basePaint);

    if (accents.isEmpty) return;

    final charcoalColor = isDark
        ? MekaarColors.sketchCharcoal.withValues(alpha: 0.85)
        : MekaarColors.sketchCharcoal.withValues(alpha: 0.6);

    // 2. Render masing-masing goresan sketsa (maksimal 2 goresan per kartu)
    for (int i = 0; i < accents.length; i++) {
      final accentItem = accents[i];
      if (accentItem == SketchCornerAccent.none) continue;

      // Variasi panjang goresan: aksen utama sedikit lebih panjang dari aksen sekunder
      final lengthFactor = i == 0 ? 0.45 : 0.35;
      final minLength = i == 0 ? 80.0 : 65.0;
      final maxLength = i == 0 ? 160.0 : 130.0;
      final fadeLength = (size.width * lengthFactor).clamp(
        minLength,
        maxLength,
      );

      final path = Path();
      Rect gradientBounds = rect;

      switch (accentItem) {
        case SketchCornerAccent.topLeft:
          path.moveTo(0, r + 24);
          path.lineTo(0, r);
          path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
          path.lineTo(r + fadeLength, 0);
          gradientBounds = Rect.fromLTWH(0, 0, r + fadeLength, r + 24);
          break;

        case SketchCornerAccent.topRight:
          path.moveTo(size.width - r - fadeLength, 0);
          path.lineTo(size.width - r, 0);
          path.arcToPoint(Offset(size.width, r), radius: Radius.circular(r));
          path.lineTo(size.width, r + 24);
          gradientBounds = Rect.fromLTWH(
            size.width - r - fadeLength,
            0,
            r + fadeLength,
            r + 24,
          );
          break;

        case SketchCornerAccent.bottomRight:
          path.moveTo(size.width, size.height - r - 24);
          path.lineTo(size.width, size.height - r);
          path.arcToPoint(
            Offset(size.width - r, size.height),
            radius: Radius.circular(r),
          );
          path.lineTo(size.width - r - fadeLength, size.height);
          gradientBounds = Rect.fromLTWH(
            size.width - r - fadeLength,
            size.height - r - 24,
            r + fadeLength,
            r + 24,
          );
          break;

        case SketchCornerAccent.bottomLeft:
          path.moveTo(r + fadeLength, size.height);
          path.lineTo(r, size.height);
          path.arcToPoint(
            Offset(0, size.height - r),
            radius: Radius.circular(r),
          );
          path.lineTo(0, size.height - r - 24);
          gradientBounds = Rect.fromLTWH(
            0,
            size.height - r - 24,
            r + fadeLength,
            r + 24,
          );
          break;

        case SketchCornerAccent.none:
          break;
      }

      final isReversed =
          accentItem == SketchCornerAccent.topRight ||
          accentItem == SketchCornerAccent.bottomRight;

      final accentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: isReversed ? Alignment.centerRight : Alignment.centerLeft,
          end: isReversed ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            charcoalColor,
            charcoalColor.withValues(alpha: 0.85),
            charcoalColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(gradientBounds);

      canvas.drawPath(path, accentPaint);

      // 3. Architectural Pencil Ticks untuk setiap aksen aktif
      if (showPencilTicks) {
        final tickPaint = Paint()
          ..color = charcoalColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round;

        switch (accentItem) {
          case SketchCornerAccent.topLeft:
            canvas.drawLine(const Offset(0, -6), const Offset(0, 0), tickPaint);
            canvas.drawLine(const Offset(-6, 0), const Offset(0, 0), tickPaint);
            break;
          case SketchCornerAccent.topRight:
            canvas.drawLine(
              Offset(size.width, -6),
              Offset(size.width, 0),
              tickPaint,
            );
            canvas.drawLine(
              Offset(size.width, 0),
              Offset(size.width + 6, 0),
              tickPaint,
            );
            break;
          case SketchCornerAccent.bottomRight:
            canvas.drawLine(
              Offset(size.width, size.height),
              Offset(size.width, size.height + 6),
              tickPaint,
            );
            canvas.drawLine(
              Offset(size.width, size.height),
              Offset(size.width + 6, size.height),
              tickPaint,
            );
            break;
          case SketchCornerAccent.bottomLeft:
            canvas.drawLine(
              Offset(0, size.height),
              Offset(0, size.height + 6),
              tickPaint,
            );
            canvas.drawLine(
              Offset(-6, size.height),
              Offset(0, size.height),
              tickPaint,
            );
            break;
          case SketchCornerAccent.none:
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MekaarSketchBorderPainter oldDelegate) {
    if (oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.showPencilTicks != showPencilTicks ||
        oldDelegate.accents.length != accents.length) {
      return true;
    }
    for (int i = 0; i < accents.length; i++) {
      if (oldDelegate.accents[i] != accents[i]) return true;
    }
    return false;
  }
}
