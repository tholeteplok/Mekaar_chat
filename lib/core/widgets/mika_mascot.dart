import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Mika — maskot playful MEKAAR.
/// Karakter perisai berwajah yang ekspresif, dibuat murni dengan shape
/// Flutter (tanpa aset gambar). Ekspresi: happy | panic | wave.
class MikaMascot extends StatelessWidget {
  final MikaExpression expression;
  final double size;

  const MikaMascot({
    super.key,
    this.expression = MikaExpression.happy,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MikaPainter(expression: expression),
      ),
    );
  }
}

enum MikaExpression { happy, panic, wave }

class _MikaPainter extends CustomPainter {
  final MikaExpression expression;

  _MikaPainter({required this.expression});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.40;

    // Soft shadow under shield
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.95),
        width: r * 1.1,
        height: r * 0.22,
      ),
      shadowPaint,
    );

    // Shield body — coral gradient
    final shieldPath = _shieldPath(cx, cy, r);
    final shieldFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MekaarColors.softCoral,
          const Color(0xFFFF8E72),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(shieldPath, shieldFill);

    // Glossy highlight
    final gloss = Paint()
      ..color = Colors.white.withValues(alpha: 0.22);
    canvas.drawPath(_shieldPath(cx, cy - r * 0.12, r * 0.78), gloss);

    // Shield rim
    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.06;
    canvas.drawPath(shieldPath, rim);

    // Face
    final eyeY = cy - r * 0.12;
    final eyeDX = r * 0.34;
    final eyeR = r * 0.10;

    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - eyeDX, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx + eyeDX, eyeY), eyeR, eyePaint);

    final pupilPaint = Paint()..color = const Color(0xFF1F2937);
    final pupilR = eyeR * 0.55;
    canvas.drawCircle(Offset(cx - eyeDX, eyeY + eyeR * 0.15), pupilR, pupilPaint);
    canvas.drawCircle(Offset(cx + eyeDX, eyeY + eyeR * 0.15), pupilR, pupilPaint);

    // Expression-specific
    final mouthPaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.055
      ..strokeCap = StrokeCap.round;

    final blushPaint = Paint()..color = Colors.white.withValues(alpha: 0.45);

    switch (expression) {
      case MikaExpression.happy:
        // Smile
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, cy + r * 0.18),
            width: r * 0.7,
            height: r * 0.5,
          ),
          0.15 * 3.14159,
          0.7 * 3.14159,
          false,
          mouthPaint,
        );
        _blush(canvas, cx - eyeDX - r * 0.2, eyeY + r * 0.28, r * 0.12, blushPaint);
        _blush(canvas, cx + eyeDX + r * 0.2, eyeY + r * 0.28, r * 0.12, blushPaint);
        break;
      case MikaExpression.wave:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, cy + r * 0.22),
            width: r * 0.6,
            height: r * 0.45,
          ),
          0.2 * 3.14159,
          0.6 * 3.14159,
          false,
          mouthPaint,
        );
        // Waving hand
        final handPaint = Paint()..color = const Color(0xFFFF8E72);
        canvas.drawCircle(Offset(cx + r * 0.95, cy - r * 0.55), r * 0.16, handPaint);
        canvas.drawLine(
          Offset(cx + r * 0.7, cy - r * 0.2),
          Offset(cx + r * 0.9, cy - r * 0.5),
          Paint()
            ..color = const Color(0xFFFF8E72)
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round,
        );
        break;
      case MikaExpression.panic:
        // Worried open mouth
        final mouthFill = Paint()..color = const Color(0xFF1F2937);
        canvas.drawCircle(Offset(cx, cy + r * 0.32), r * 0.12, mouthFill);
        // Sweat drop
        final sweat = Paint()..color = MekaarColors.info;
        canvas.drawCircle(Offset(cx + eyeDX + r * 0.3, eyeY), r * 0.08, sweat);
        break;
    }
  }

  void _blush(Canvas canvas, double x, double y, double r, Paint paint) {
    canvas.drawCircle(Offset(x, y), r, paint);
  }

  Path _shieldPath(double cx, double cy, double r) {
    final path = Path();
    path.moveTo(cx, cy - r);
    path.quadraticBezierTo(cx + r, cy - r, cx + r, cy - r * 0.1);
    path.quadraticBezierTo(cx + r, cy + r * 0.7, cx, cy + r);
    path.quadraticBezierTo(cx - r, cy + r * 0.7, cx - r, cy - r * 0.1);
    path.quadraticBezierTo(cx - r, cy - r, cx, cy - r);
    return path;
  }

  @override
  bool shouldRepaint(covariant _MikaPainter old) =>
      old.expression != expression;
}
