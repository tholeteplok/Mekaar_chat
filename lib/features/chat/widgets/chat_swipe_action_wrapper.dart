import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/services/haptic_service.dart';

/// Gesture wrapper untuk aksi swipe-to-reply (ke kanan) dan swipe-to-delete (ke kiri 2x).
class ChatSwipeActionWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const ChatSwipeActionWrapper({
    super.key,
    required this.child,
    this.onReply,
    this.onDelete,
  });

  @override
  State<ChatSwipeActionWrapper> createState() => _ChatSwipeActionWrapperState();
}

class _ChatSwipeActionWrapperState extends State<ChatSwipeActionWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recoilController;
  double _dragOffset = 0.0;
  bool _rightThresholdReached = false;
  bool _leftThresholdReached = false;
  int _leftSwipeCount = 0;
  Timer? _leftSwipeTimer;

  static const double _actionThreshold = 48.0;
  static const double _maxDragDistance = 72.0;
  static const Duration _doubleSwipeWindow = Duration(milliseconds: 2000);

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
    _leftSwipeTimer?.cancel();
    _recoilController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;

    // 1. Geser ke kanan (Reply)
    if ((delta > 0 || _dragOffset > 0) &&
        _dragOffset >= 0 &&
        widget.onReply != null) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, _maxDragDistance);
        if (_dragOffset >= _actionThreshold && !_rightThresholdReached) {
          _rightThresholdReached = true;
          HapticService.trigger(MekaarHapticIntent.selection);
        }
      });
      return;
    }

    // 2. Geser ke kiri (Delete)
    if ((delta < 0 || _dragOffset < 0) &&
        _dragOffset <= 0 &&
        widget.onDelete != null) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(-_maxDragDistance, 0.0);
        if (_dragOffset <= -_actionThreshold && !_leftThresholdReached) {
          _leftThresholdReached = true;
          HapticService.trigger(
            _leftSwipeCount == 1
                ? MekaarHapticIntent.destructive
                : MekaarHapticIntent.selection,
          );
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // 1. Tangani swipe kanan (Reply)
    if (_rightThresholdReached) {
      _resetLeftSwipe();
      widget.onReply?.call();
    }
    _rightThresholdReached = false;

    // 2. Tangani swipe kiri (Delete 2x)
    if (_leftThresholdReached) {
      if (_leftSwipeCount == 0) {
        // Geseran pertama: catat dan aktifkan jendela 2.0 detik
        setState(() {
          _leftSwipeCount = 1;
        });
        _leftSwipeTimer?.cancel();
        _leftSwipeTimer = Timer(_doubleSwipeWindow, () {
          if (mounted) {
            setState(() {
              _leftSwipeCount = 0;
            });
          }
        });
      } else if (_leftSwipeCount == 1) {
        // Geseran kedua: konfirmasi hapus!
        _resetLeftSwipe();
        widget.onDelete?.call();
      }
    }
    _leftThresholdReached = false;

    // Animasi recoil kembali ke posisi netral (0.0)
    if (_dragOffset != 0.0) {
      final startOffset = _dragOffset;
      final anim = Tween<double>(begin: startOffset, end: 0.0).animate(
        CurvedAnimation(parent: _recoilController, curve: Curves.easeOutCubic),
      );
      anim.addListener(() {
        setState(() {
          _dragOffset = anim.value;
        });
      });
      _recoilController.forward(from: 0.0);
    }
  }

  void _resetLeftSwipe() {
    _leftSwipeTimer?.cancel();
    _leftSwipeTimer = null;
    if (_leftSwipeCount != 0 && mounted) {
      setState(() {
        _leftSwipeCount = 0;
      });
    } else {
      _leftSwipeCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ikon Reply di sisi kiri (saat digeser ke kanan)
          if (_dragOffset > 6 && widget.onReply != null)
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

          // Ikon Hapus di sisi kanan (saat digeser ke kiri)
          if (_dragOffset < -6 && widget.onDelete != null)
            Positioned(
              right: 14,
              child: Opacity(
                opacity: (-_dragOffset / _actionThreshold).clamp(0.0, 1.0),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: MekaarColors.sosRed.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: _leftSwipeCount == 1
                        ? Border.all(color: MekaarColors.sosRed, width: 1.5)
                        : null,
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.trashBinTrash,
                      color: MekaarColors.sosRed,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),

          // Petunjuk visual saat geseran pertama aktif (menunggu geseran kedua)
          if (_leftSwipeCount == 1 &&
              _dragOffset.abs() < 6 &&
              widget.onDelete != null)
            Positioned(
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MekaarColors.sosRed.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: MekaarColors.sosRed.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      SolarIconsBold.trashBinMinimalistic,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Geser 1x lagi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
