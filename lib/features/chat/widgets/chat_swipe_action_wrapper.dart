import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/services/haptic_service.dart';

/// Gesture wrapper untuk aksi swipe-to-reply (geser ke kanan).
class ChatSwipeActionWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;

  const ChatSwipeActionWrapper({
    super.key,
    required this.child,
    this.onReply,
  });

  @override
  State<ChatSwipeActionWrapper> createState() => _ChatSwipeActionWrapperState();
}

class _ChatSwipeActionWrapperState extends State<ChatSwipeActionWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recoilController;
  double _dragOffset = 0.0;
  bool _rightThresholdReached = false;

  static const double _actionThreshold = 48.0;
  static const double _maxDragDistance = 72.0;

  @override
  void initState() {
    super.initState();
    _recoilController = AnimationController(
      vsync: this,
      duration: MekaarMotion.fast,
    );
  }

  @override
  void dispose() {
    _recoilController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;
    final delta = details.primaryDelta ?? 0.0;

    // Hanya merespons geseran ke kanan (Reply)
    if (delta > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, _maxDragDistance);
        if (_dragOffset >= _actionThreshold && !_rightThresholdReached) {
          _rightThresholdReached = true;
          HapticService.trigger(MekaarHapticIntent.selection);
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_rightThresholdReached) {
      widget.onReply?.call();
    }
    _rightThresholdReached = false;

    // Animasi recoil kembali ke posisi netral (0.0)
    if (_dragOffset != 0.0) {
      final startOffset = _dragOffset;
      final anim = Tween<double>(begin: startOffset, end: 0.0).animate(
        CurvedAnimation(parent: _recoilController, curve: MekaarMotion.standard),
      );
      anim.addListener(() {
        setState(() {
          _dragOffset = anim.value;
        });
      });
      _recoilController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ikon Reply di sisi kiri (saat digeser ke kanan)
          if (_dragOffset > 6)
            Positioned(
              left: 14,
              child: Opacity(
                opacity: (_dragOffset / _actionThreshold).clamp(0.0, 1.0),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: MekaarColors.guardianTeal.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.reply,
                      color: MekaarColors.guardianTeal,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),

          // Bubble utama yang digeser
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
