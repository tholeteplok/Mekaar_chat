import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/icons.dart';
import '../../constants/motion.dart';

/// Enum status tanda terima baca pesan
enum ReadReceiptStatus {
  pending, // clock: not yet sent to server
  sent, // single check: reached server
  delivered, // double check (muted): delivered to other device
  read, // double check (readReceiptGreen): other person opened the room
}

/// Read Receipt Icon (uses MekaarColors — no hardcoded colors)
///
/// Dibungkus dalam kotak stabil 16x16 dengan transisi mikro [AnimatedSwitcher]
/// berskala 0.6 -> 1.0 yang menghormati preferensi reduce-motion sistem.
class ReadReceiptIcon extends StatelessWidget {
  final ReadReceiptStatus status;
  final Color color;

  const ReadReceiptIcon({
    super.key,
    required this.status,
    required this.color,
  });

  Widget _iconFor(ReadReceiptStatus status) {
    switch (status) {
      case ReadReceiptStatus.pending:
        return Icon(MekaarIcons.timerOutlined, size: 12, color: color);
      case ReadReceiptStatus.sent:
        return Icon(MekaarIcons.receiptSent, size: 15, color: color);
      case ReadReceiptStatus.delivered:
        return Icon(MekaarIcons.receiptDelivered, size: 15, color: color);
      case ReadReceiptStatus.read:
        return const Icon(
          MekaarIcons.receiptRead,
          size: 15,
          color: MekaarColors.readReceiptGreen,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: AnimatedSwitcher(
          duration: context.motion(MekaarMotion.fast),
          switchInCurve: MekaarMotion.bounce,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: KeyedSubtree(
            key: ValueKey(status),
            child: _iconFor(status),
          ),
        ),
      ),
    );
  }
}
