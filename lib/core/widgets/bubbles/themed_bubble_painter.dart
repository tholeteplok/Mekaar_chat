import 'package:flutter/material.dart';
import '../../theme/chat_preset_resolver.dart';

/// Painter tersentralisasi untuk merender bentuk (shape), ekor (tail),
/// border 3D bevel, dan efek bayangan 7 tema obrolan MEKAAR secara 1:1.
class ThemedBubblePainter extends CustomPainter {
  final ChatBubbleSpec spec;
  final bool isMe;
  final bool isSelected;
  final Color? selectionColor;

  const ThemedBubblePainter({
    required this.spec,
    required this.isMe,
    this.isSelected = false,
    this.selectionColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Dapatkan Path utama gelembung (termasuk ekor terintegrasi)
    final path = _buildUnifiedPath(size);

    // 2. Lukis Shadows
    _paintShadows(canvas, path, size);

    // 3. Lukis Background (Solid atau Gradient)
    _paintBackground(canvas, path, size);

    // 4. Lukis Inset Deboss (Jika aktif untuk Neumorphism)
    if (spec.hasInsetDeboss) {
      _paintInsetDeboss(canvas, path, size);
    }

    // 5. Lukis Border 3D Bevel (Pixel Minecraft) atau Aksen Vertikal (Mecha) atau Border Standar
    _paintBorders(canvas, path, size);

    // 6. Lukis Highlight Seleksi (Jika pesan sedang dipilih)
    if (isSelected) {
      final selectPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = selectionColor ?? const Color(0xFF0284C7);
      canvas.drawPath(path, selectPaint);
    }
  }

  /// Membangun Path terpadu antara badan gelembung dan ekornya
  Path _buildUnifiedPath(Size size) {
    switch (spec.shapeType) {
      case BubbleShapeType.mechaChamfered:
        return _buildMechaPath(size);
      case BubbleShapeType.pixelSteppedVoxel:
        return _buildPixelVoxelPath(size);
      case BubbleShapeType.comicBox:
        return _buildComicPath(size);
      case BubbleShapeType.neuroClay:
        return _buildNeuroPath(size);
      case BubbleShapeType.candyRounded:
        return _buildCandyPath(size);
      case BubbleShapeType.solarLeafBox:
        return _buildSolarPath(size);
      case BubbleShapeType.roundedPill:
        return _buildMekaarCorePath(size);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. MEKAAR CORE: Top-Corner Swoop (Top-Left / Top-Right)
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildMekaarCorePath(Size size) {
    const tailW = 8.0;
    const tailH = 8.0;
    final path = Path();

    if (!isMe) {
      // Receiver: Body dari x = tailW ke size.width
      final bodyRect = Rect.fromLTWH(tailW, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topRight: const Radius.circular(14),
        bottomRight: const Radius.circular(14),
        bottomLeft: const Radius.circular(14),
        topLeft: Radius.zero,
      );
      path.addRRect(rrect);

      // Ekor segitiga di top-left
      final tailPath = Path()
        ..moveTo(tailW, 0)
        ..lineTo(0, 0)
        ..lineTo(tailW, tailH)
        ..close();
      path.addPath(tailPath, Offset.zero);
    } else {
      // Sender: Body dari x = 0 ke size.width - tailW
      final bodyRect = Rect.fromLTWH(0, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(14),
        bottomLeft: const Radius.circular(14),
        bottomRight: const Radius.circular(14),
        topRight: Radius.zero,
      );
      path.addRRect(rrect);

      // Ekor segitiga di top-right
      final tailPath = Path()
        ..moveTo(size.width - tailW, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - tailW, tailH)
        ..close();
      path.addPath(tailPath, Offset.zero);
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. COMIC ART: Corner Beak (Bottom-Left / Bottom-Right)
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildComicPath(Size size) {
    const tailW = 10.0;
    const tailH = 10.0;
    final path = Path();

    if (!isMe) {
      // Receiver: Body x = tailW ke size.width
      final bodyRect = Rect.fromLTWH(tailW, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
        bottomRight: const Radius.circular(12),
        bottomLeft: Radius.zero,
      );
      path.addRRect(rrect);

      // Paruh komik di bottom-left
      final beakPath = Path()
        ..moveTo(tailW, size.height - tailH)
        ..lineTo(0, size.height)
        ..lineTo(tailW, size.height)
        ..close();
      path.addPath(beakPath, Offset.zero);
    } else {
      // Sender: Body x = 0 ke size.width - tailW
      final bodyRect = Rect.fromLTWH(0, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
        bottomLeft: const Radius.circular(12),
        bottomRight: Radius.zero,
      );
      path.addRRect(rrect);

      // Paruh komik di bottom-right
      final beakPath = Path()
        ..moveTo(size.width - tailW, size.height - tailH)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - tailW, size.height)
        ..close();
      path.addPath(beakPath, Offset.zero);
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. NEURO UI: Corner Notch (Bottom-Left / Bottom-Right)
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildNeuroPath(Size size) {
    const tailW = 10.0;
    const tailH = 10.0;
    final path = Path();

    if (!isMe) {
      final bodyRect = Rect.fromLTWH(tailW, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
        bottomLeft: Radius.zero,
      );
      path.addRRect(rrect);

      final notchPath = Path()
        ..moveTo(tailW, size.height - tailH)
        ..lineTo(0, size.height)
        ..lineTo(tailW, size.height)
        ..close();
      path.addPath(notchPath, Offset.zero);
    } else {
      final bodyRect = Rect.fromLTWH(0, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(16),
        bottomRight: Radius.zero,
      );
      path.addRRect(rrect);

      final notchPath = Path()
        ..moveTo(size.width - tailW, size.height - tailH)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - tailW, size.height)
        ..close();
      path.addPath(notchPath, Offset.zero);
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. MECHA STYLE: Chamfer Apex Clip-Path (Cut corners 12px)
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildMechaPath(Size size) {
    const c = 12.0; // Chamfer cut depth
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (!isMe) {
      // Receiver: polygon(12px 0%, 100% 0%, 100% calc(100% - 12px), calc(100% - 12px) 100%, 0% 100%, 12px calc(100% - 12px))
      path.moveTo(c, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h - c);
      path.lineTo(w - c, h);
      path.lineTo(0, h);
      path.lineTo(c, h - c);
      path.close();
    } else {
      // Sender: polygon(0% 0%, calc(100% - 12px) 0%, 100% 100%, calc(100% - 12px) calc(100% - 12px), 12px 100%, 0% calc(100% - 12px))
      path.moveTo(0, 0);
      path.lineTo(w - c, 0);
      path.lineTo(w, h);
      path.lineTo(w - c, h - c);
      path.lineTo(c, h);
      path.lineTo(0, h - c);
      path.close();
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. PIXEL CRAFT: Minecraft Stepped Voxel + 5x5px Voxel Ear
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildPixelVoxelPath(Size size) {
    const tailW = 6.0;
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (!isMe) {
      // Receiver: Body x = tailW ke w. Top-right has 2-step cut: (w - 8, 0) -> (w - 8, 4) -> (w - 4, 4) -> (w - 4, 8) -> (w, 8)
      path.moveTo(tailW, 0);
      path.lineTo(w - 8, 0);
      path.lineTo(w - 8, 4);
      path.lineTo(w - 4, 4);
      path.lineTo(w - 4, 8);
      path.lineTo(w, 8);
      path.lineTo(w, h);
      path.lineTo(tailW, h);
      path.close();

      // Kubus voxel 5x5px menonjol di bottom-left
      final block = Path()
        ..addRect(Rect.fromLTWH(0, h - 5, tailW, 5));
      path.addPath(block, Offset.zero);
    } else {
      // Sender: Body x = 0 ke w - tailW. Top-left has 2-step cut: (0, 8) -> (4, 8) -> (4, 4) -> (8, 4) -> (8, 0)
      path.moveTo(0, 8);
      path.lineTo(4, 8);
      path.lineTo(4, 4);
      path.lineTo(8, 4);
      path.lineTo(8, 0);
      path.lineTo(w - tailW, 0);
      path.lineTo(w - tailW, h);
      path.lineTo(0, h);
      path.close();

      // Kubus voxel 5x5px menonjol di bottom-right
      final block = Path()
        ..addRect(Rect.fromLTWH(w - tailW, h - 5, tailW, 5));
      path.addPath(block, Offset.zero);
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 6. CANDY POP: Playful & Top Teardrop (Half-Circle 10x10px)
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildCandyPath(Size size) {
    const tailW = 8.0;
    final path = Path();

    if (!isMe) {
      // Body x = tailW ke size.width
      final bodyRect = Rect.fromLTWH(tailW, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topRight: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
        bottomLeft: const Radius.circular(18),
        topLeft: Radius.zero,
      );
      path.addRRect(rrect);

      // Teardrop setengah lingkaran di top-left
      final teardrop = Path()
        ..moveTo(tailW, 0)
        ..arcToPoint(
          const Offset(tailW, 10),
          radius: const Radius.circular(5),
          clockwise: false,
        )
        ..close();
      path.addPath(teardrop, Offset.zero);
    } else {
      // Body x = 0 ke size.width - tailW
      final bodyRect = Rect.fromLTWH(0, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(18),
        bottomLeft: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
        topRight: Radius.zero,
      );
      path.addRRect(rrect);

      // Teardrop setengah lingkaran di top-right
      final teardrop = Path()
        ..moveTo(size.width - tailW, 0)
        ..arcToPoint(
          Offset(size.width - tailW, 10),
          radius: const Radius.circular(5),
          clockwise: true,
        )
        ..close();
      path.addPath(teardrop, Offset.zero);
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 7. SOLAR PUNK: Calm Leaf Stem (Diagonal Triangle Stem with 1px border)
  // ──────────────────────────────────────────────────────────────────────────
  Path _buildSolarPath(Size size) {
    const tailW = 8.0;
    const stemH = 9.0;
    final path = Path();

    if (!isMe) {
      final bodyRect = Rect.fromLTWH(tailW, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
        bottomLeft: Radius.zero,
      );
      path.addRRect(rrect);

      // Tangkai daun di bottom-left
      final stemPath = Path()
        ..moveTo(tailW, size.height - stemH)
        ..lineTo(0, size.height)
        ..lineTo(tailW, size.height)
        ..close();
      path.addPath(stemPath, Offset.zero);
    } else {
      final bodyRect = Rect.fromLTWH(0, 0, size.width - tailW, size.height);
      final rrect = RRect.fromRectAndCorners(
        bodyRect,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: const Radius.circular(16),
        bottomRight: Radius.zero,
      );
      path.addRRect(rrect);

      // Tangkai daun di bottom-right
      final stemPath = Path()
        ..moveTo(size.width - tailW, size.height - stemH)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - tailW, size.height)
        ..close();
      path.addPath(stemPath, Offset.zero);
    }
    return path;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LUKIS SHADOWS & GLOW
  // ──────────────────────────────────────────────────────────────────────────
  void _paintShadows(Canvas canvas, Path path, Size size) {
    if (spec.boxShadow == null || spec.boxShadow!.isEmpty) return;

    for (final shadow in spec.boxShadow!) {
      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = shadow.blurRadius > 0
            ? MaskFilter.blur(BlurStyle.normal, shadow.blurRadius * 0.57735 + 0.5)
            : null;

      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LUKIS BACKGROUND (SOLID / GRADIENT)
  // ──────────────────────────────────────────────────────────────────────────
  void _paintBackground(Canvas canvas, Path path, Size size) {
    final bgPaint = Paint()..style = PaintingStyle.fill;

    if (spec.gradient != null) {
      bgPaint.shader = spec.gradient!.createShader(Offset.zero & size);
    } else {
      bgPaint.color = spec.backgroundColor;
    }

    canvas.drawPath(path, bgPaint);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LUKIS INSET DEBOSS (NEUROMORPHISM INSET)
  // ──────────────────────────────────────────────────────────────────────────
  void _paintInsetDeboss(Canvas canvas, Path path, Size size) {
    final darkColor = spec.debossDarkColor ?? const Color(0x33000000);
    final lightColor = spec.debossLightColor ?? const Color(0x22FFFFFF);

    canvas.save();
    canvas.clipPath(path);

    // Inset Dark Shadow di top-left
    final darkPaint = Paint()
      ..color = darkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.save();
    canvas.translate(1.5, 1.5);
    canvas.drawPath(path, darkPaint);
    canvas.restore();

    // Inset Light Highlight di bottom-right
    final lightPaint = Paint()
      ..color = lightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.save();
    canvas.translate(-1.5, -1.5);
    canvas.drawPath(path, lightPaint);
    canvas.restore();

    canvas.restore();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LUKIS BORDERS (BEVEL 3D, MECHA ACCENT, ATAU SOLID BORDER)
  // ──────────────────────────────────────────────────────────────────────────
  void _paintBorders(Canvas canvas, Path path, Size size) {
    // 1. Pixel Craft: 3D Beveled Voxel Border (Top/Left highlight, Bottom/Right shadow)
    if (spec.voxelBevel != null) {
      final bevel = spec.voxelBevel!;
      const tailW = 6.0;
      final w = size.width;
      final h = size.height;

      final highlightPaint = Paint()
        ..color = bevel.highlightColor
        ..strokeWidth = bevel.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      final shadowPaint = Paint()
        ..color = bevel.shadowColor
        ..strokeWidth = bevel.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      if (!isMe) {
        // Top & Left edges = highlight
        final highlightPath = Path()
          ..moveTo(tailW, h - 5)
          ..lineTo(0, h - 5)
          ..lineTo(0, h)
          ..moveTo(tailW, h)
          ..lineTo(tailW, 0)
          ..lineTo(w - 8, 0);
        canvas.drawPath(highlightPath, highlightPaint);

        // Bottom & Right edges = shadow
        final shadowPath = Path()
          ..moveTo(w - 8, 0)
          ..lineTo(w - 8, 4)
          ..lineTo(w - 4, 4)
          ..lineTo(w - 4, 8)
          ..lineTo(w, 8)
          ..lineTo(w, h)
          ..lineTo(tailW, h);
        canvas.drawPath(shadowPath, shadowPaint);
      } else {
        // Sender: Top & Left = highlight
        final highlightPath = Path()
          ..moveTo(0, h)
          ..lineTo(0, 8)
          ..lineTo(4, 8)
          ..lineTo(4, 4)
          ..lineTo(8, 4)
          ..lineTo(8, 0)
          ..lineTo(w - tailW, 0);
        canvas.drawPath(highlightPath, highlightPaint);

        // Bottom & Right = shadow
        final shadowPath = Path()
          ..moveTo(w - tailW, 0)
          ..lineTo(w - tailW, h - 5)
          ..lineTo(w, h - 5)
          ..lineTo(w, h)
          ..lineTo(0, h);
        canvas.drawPath(shadowPath, shadowPaint);
      }
      return;
    }

    // 2. Mecha Style: Accent Vertical Line (3px pada sisi luar)
    if (spec.accentVerticalBorderColor != null) {
      final accentPaint = Paint()
        ..color = spec.accentVerticalBorderColor!
        ..strokeWidth = spec.accentVerticalBorderWidth ?? 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (!isMe) {
        // Border di sisi kiri
        canvas.drawLine(
          const Offset(1.5, 6),
          Offset(1.5, size.height - 6),
          accentPaint,
        );
      } else {
        // Border di sisi kanan
        canvas.drawLine(
          Offset(size.width - 1.5, 6),
          Offset(size.width - 1.5, size.height - 6),
          accentPaint,
        );
      }
      return;
    }

    // 3. Border Standar (Comic Art 2px hitam, Solar Punk 1px mist)
    if (spec.border != null && spec.border!.isUniform) {
      final side = spec.border!.top;
      final borderPaint = Paint()
        ..color = side.color
        ..strokeWidth = side.width
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ThemedBubblePainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.isMe != isMe ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.selectionColor != selectionColor;
  }
}
