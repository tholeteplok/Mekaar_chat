import 'package:flutter/material.dart';
import '../../theme/chat_preset_resolver.dart';
import 'themed_bubble_painter.dart';

/// Container gelembung pesan tersentralisasi yang menggabungkan
/// bentuk kustom (shape), ekor (tail), efek border 3D, dan bayangan
/// untuk seluruh 7 preset obrolan MEKAAR secara konsisten.
class ThemedBubbleContainer extends StatelessWidget {
  final ChatBubbleSpec spec;
  final bool isMe;
  final Widget child;
  final bool isSelected;
  final Color? selectionColor;
  final EdgeInsetsGeometry? customPadding;
  final BoxConstraints? constraints;

  const ThemedBubbleContainer({
    super.key,
    required this.spec,
    required this.isMe,
    required this.child,
    this.isSelected = false,
    this.selectionColor,
    this.customPadding,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    // Hitung padding efektif agar teks tidak menabrak ekor gelembung
    final effectivePadding = customPadding ?? _calculateEffectivePadding();

    return CustomPaint(
      painter: ThemedBubblePainter(
        spec: spec,
        isMe: isMe,
        isSelected: isSelected,
        selectionColor: selectionColor,
      ),
      child: Container(
        constraints: constraints,
        padding: effectivePadding,
        child: child,
      ),
    );
  }

  /// Menghitung penyesuaian padding berdasarkan posisi ekor & aksen tema
  EdgeInsetsGeometry _calculateEffectivePadding() {
    double left = spec.contentPadding.left;
    double right = spec.contentPadding.right;
    final top = spec.contentPadding.top;
    final bottom = spec.contentPadding.bottom;

    if (!isMe) {
      // Receiver: Ekor ada di sebelah kiri
      switch (spec.tailType) {
        case BubbleTailType.swoopTop:
        case BubbleTailType.candyTeardropTop:
        case BubbleTailType.solarLeafBottom:
          left += 8.0;
          break;
        case BubbleTailType.comicBeakBottom:
        case BubbleTailType.neuroNotchBottom:
          left += 10.0;
          break;
        case BubbleTailType.pixelVoxelBottom:
          left += 6.0;
          break;
        case BubbleTailType.mechaChamfer:
        case BubbleTailType.none:
          break;
      }
    } else {
      // Sender: Ekor ada di sebelah kanan
      switch (spec.tailType) {
        case BubbleTailType.swoopTop:
        case BubbleTailType.candyTeardropTop:
        case BubbleTailType.solarLeafBottom:
          right += 8.0;
          break;
        case BubbleTailType.comicBeakBottom:
        case BubbleTailType.neuroNotchBottom:
          right += 10.0;
          break;
        case BubbleTailType.pixelVoxelBottom:
          right += 6.0;
          break;
        case BubbleTailType.mechaChamfer:
        case BubbleTailType.none:
          break;
      }
    }

    return EdgeInsets.only(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
    );
  }
}
