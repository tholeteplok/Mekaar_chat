import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class Avatar extends StatelessWidget {
  final String? initial;
  final String? imageUrl;
  final double size;
  final bool isGuardian;
  final Color? backgroundColor;
  final bool useCrayonStyle;

  const Avatar({
    super.key,
    this.initial,
    this.imageUrl,
    this.size = 48,
    this.isGuardian = false,
    this.backgroundColor,
    this.useCrayonStyle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final innerSize = isGuardian ? size - 4 : size;
    final letter = initial?.isNotEmpty == true
        ? initial![0].toUpperCase()
        : '?';

    Widget avatarChild;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final cacheDim = (innerSize * MediaQuery.devicePixelRatioOf(context))
          .round();
      avatarChild = ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: innerSize,
          height: innerSize,
          cacheWidth: cacheDim > 0 ? cacheDim : null,
          cacheHeight: cacheDim > 0 ? cacheDim : null,
          errorBuilder: (context, error, stackTrace) =>
              _buildInitialWidget(context, letter, innerSize, isDark),
        ),
      );
    } else {
      avatarChild = _buildInitialWidget(context, letter, innerSize, isDark);
    }

    final BoxDecoration boxDecoration;
    if (useCrayonStyle && (imageUrl == null || imageUrl!.isEmpty)) {
      final circleBg = isDark
          ? const Color(0xFF152641)
          : const Color(0xFFFFFDF8);
      final circleBorder = isDark
          ? const Color(0xFFCBD5E1)
          : const Color(0xFF1E293B);

      boxDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? circleBg,
        border: Border.all(color: circleBorder, width: 1.5),
      );
    } else {
      final avatarColor = backgroundColor ?? _getAvatarColor(initial);
      boxDecoration = BoxDecoration(shape: BoxShape.circle, color: avatarColor);
    }

    final coreWidget = Container(
      width: innerSize,
      height: innerSize,
      decoration: boxDecoration,
      clipBehavior: Clip.antiAlias,
      child: ClipOval(child: avatarChild),
    );

    if (isGuardian) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MekaarColors.guardianTeal,
        ),
        child: coreWidget,
      );
    }

    return coreWidget;
  }

  Widget _buildInitialWidget(
    BuildContext context,
    String letter,
    double innerSize,
    bool isDark,
  ) {
    if (!useCrayonStyle) {
      final avatarColor = backgroundColor ?? _getAvatarColor(initial);
      final inkColor = _inkFor(avatarColor);
      return Center(
        child: Text(
          letter,
          style: TextStyle(
            color: inkColor,
            fontSize: innerSize * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // Inisial Krayon Biru MEKAAR: Miring Kiri 25°, Font Besar Terpotong Kontainer
    final strokeColor = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E293B);
    final fontSize = innerSize * 1.05;

    return Center(
      child: Transform.rotate(
        angle: -25 * (math.pi / 180), // Miring kiri 25 derajad
        child: CustomPaint(
          size: Size(innerSize * 1.2, innerSize * 1.2),
          painter: _CrayonInitialPainter(
            letter: letter,
            fontSize: fontSize,
            crayonColor: AppColors.blue,
            strokeColor: strokeColor,
            textStyle: GoogleFonts.dynaPuff(
              fontWeight: FontWeight.w700,
              textStyle: const TextStyle(
                fontFamilyFallback: ['Sniglet', 'Comic Neue', 'sans-serif'],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tinta inisial dipilih dari luminansi latar agar kontras selalu memadai
  /// (putih di atas warning/success hanya ≈2:1).
  Color _inkFor(Color bg) {
    return bg.computeLuminance() > 0.5 ? AppColors.darkBlue : Colors.white;
  }

  Color _getAvatarColor(String? text) {
    if (text == null || text.isEmpty) return AppColors.blue;
    final colors = [
      AppColors.blue,
      MekaarColors.guardianTeal,
      MekaarColors.info,
      MekaarColors.success,
      MekaarColors.warning,
      MekaarColors.purple,
      MekaarColors.pink,
    ];
    final index = text.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[index.abs() % colors.length];
  }
}

/// CustomPainter untuk menggambar inisial dengan arsiran krayon bergaris
/// dan kontur tinta tebal seperti pada sketsa tangan.
class _CrayonInitialPainter extends CustomPainter {
  final String letter;
  final double fontSize;
  final Color crayonColor;
  final Color strokeColor;
  final TextStyle textStyle;

  const _CrayonInitialPainter({
    required this.letter,
    required this.fontSize,
    required this.crayonColor,
    required this.strokeColor,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. TextPainter untuk masker bentuk huruf
    final fillSpan = TextSpan(
      text: letter,
      style: textStyle.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
    final fillPainter = TextPainter(
      text: fillSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final textOffset = Offset(
      center.dx - (fillPainter.width / 2),
      center.dy - (fillPainter.height / 2),
    );

    final textRect = textOffset & fillPainter.size;

    // 2. Render arsiran krayon yang di-mask ke bentuk huruf menggunakan saveLayer
    canvas.saveLayer(textRect.inflate(16), Paint());

    // Gambar siluet huruf sebagai tujuan (destination mask)
    fillPainter.paint(canvas, textOffset);

    // Gambar goresan krayon berulang dengan BlendMode.srcIn
    final strokeW = (fontSize * 0.065).clamp(1.8, 3.6);
    final scribblePaint = Paint()
      ..color = crayonColor
      ..blendMode = BlendMode.srcIn
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final step = strokeW * 1.25;
    final startY = textRect.top - 6;
    final endY = textRect.bottom + 6;

    final scribblePath = Path();
    bool leftToRight = true;
    int index = 0;
    for (double y = startY; y <= endY; y += step) {
      final x1 = textRect.left - 12;
      final x2 = textRect.right + 12;
      final wave = (index % 2 == 0 ? 1 : -1) * (strokeW * 0.22);
      if (leftToRight) {
        scribblePath.moveTo(x1, y);
        scribblePath.quadraticBezierTo(
          (x1 + x2) / 2,
          y + wave,
          x2,
          y + (strokeW * 0.15),
        );
      } else {
        scribblePath.moveTo(x2, y);
        scribblePath.quadraticBezierTo(
          (x1 + x2) / 2,
          y + wave,
          x1,
          y + (strokeW * 0.15),
        );
      }
      leftToRight = !leftToRight;
      index++;
    }
    canvas.drawPath(scribblePath, scribblePaint);

    // Aksen goresan arsir kedua untuk memberi kedalaman tekstur lilin krayon
    final secondaryPaint = Paint()
      ..color = crayonColor.withValues(alpha: 0.85)
      ..blendMode = BlendMode.srcIn
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.65
      ..strokeCap = StrokeCap.round;

    final secondaryPath = Path();
    for (double y = startY + (step * 0.5); y <= endY; y += step * 1.6) {
      secondaryPath.moveTo(textRect.left - 8, y + 0.8);
      secondaryPath.lineTo(textRect.right + 8, y - 0.8);
    }
    canvas.drawPath(secondaryPath, secondaryPaint);

    canvas.restore();

    // 3. Garis Luar (Outlined Ink Contour) di sekeliling huruf dengan skala optik presisi
    final outlineStrokeWidth = (fontSize * 0.026).clamp(1.0, 1.8);
    final outlineSpan = TextSpan(
      text: letter,
      style: textStyle.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineStrokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = strokeColor,
      ),
    );
    final outlinePainter = TextPainter(
      text: outlineSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    outlinePainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _CrayonInitialPainter oldDelegate) {
    return oldDelegate.letter != letter ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.crayonColor != crayonColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}
