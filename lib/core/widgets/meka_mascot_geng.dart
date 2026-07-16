import 'package:flutter/material.dart';
import '../constants/colors.dart';

class MekaMascotGeng extends StatelessWidget {
  final double size;
  final String? message; // Optional speech bubble message

  const MekaMascotGeng({
    super.key,
    this.size = 120,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null) ...[
          // Speech Bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  message!,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                // Speech bubble arrow pointing down
                Positioned(
                  bottom: -16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CustomPaint(
                      painter: _TrianglePainter(Colors.white),
                      size: const Size(12, 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // The Geng: 3 overlapping blobs
        SizedBox(
          width: size * 1.5,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Cyan Blob (Left, slightly back)
              Positioned(
                left: size * 0.1,
                bottom: size * 0.05,
                child: _buildBlob(
                  size: size * 0.7,
                  color: MekaarColors.cyan,
                  eyeDX: 7,
                  smileCurve: 0.4,
                ),
              ),
              // 2. Pink Blob (Right, slightly back)
              Positioned(
                right: size * 0.1,
                bottom: size * 0.05,
                child: _buildBlob(
                  size: size * 0.7,
                  color: MekaarColors.pink,
                  eyeDX: 7,
                  smileCurve: 0.4,
                ),
              ),
              // 3. Yellow Blob (Center, front)
              Positioned(
                bottom: size * 0.1,
                child: _buildBlob(
                  size: size * 0.85,
                  color: MekaarColors.yellow,
                  eyeDX: 9,
                  smileCurve: 0.6,
                  hasCheeks: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlob({
    required double size,
    required Color color,
    required double eyeDX,
    required double smileCurve,
    bool hasCheeks = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _BlobFacePainter(
          eyeDX: eyeDX,
          smileCurve: smileCurve,
          hasCheeks: hasCheeks,
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlobFacePainter extends CustomPainter {
  final double eyeDX;
  final double smileCurve;
  final bool hasCheeks;

  _BlobFacePainter({
    required this.eyeDX,
    required this.smileCurve,
    this.hasCheeks = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Eyes
    final eyeY = cy - r * 0.12;
    final eyeR = r * 0.12;
    final eyePaint = Paint()..color = const Color(0xFF2B2400);

    canvas.drawCircle(Offset(cx - eyeDX, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx + eyeDX, eyeY), eyeR, eyePaint);

    // Eye highlights
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - eyeDX - eyeR * 0.3, eyeY - eyeR * 0.3), eyeR * 0.35, highlightPaint);
    canvas.drawCircle(Offset(cx + eyeDX - eyeR * 0.3, eyeY - eyeR * 0.3), eyeR * 0.35, highlightPaint);

    // Cute Cheeks
    if (hasCheeks) {
      final cheekPaint = Paint()..color = const Color(0xFFFF8E72).withValues(alpha: 0.6);
      canvas.drawCircle(Offset(cx - eyeDX - eyeR * 1.5, eyeY + eyeR * 1.2), eyeR * 0.8, cheekPaint);
      canvas.drawCircle(Offset(cx + eyeDX + eyeR * 1.5, eyeY + eyeR * 1.2), eyeR * 0.8, cheekPaint);
    }

    // Smile
    final mouthPaint = Paint()
      ..color = const Color(0xFF2B2400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.12),
        width: r * 0.5,
        height: r * smileCurve * 0.5,
      ),
      0.1 * 3.14159,
      0.8 * 3.14159,
      false,
      mouthPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
