import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/icons.dart';

/// Enum status tanda terima baca pesan
enum ReadReceiptStatus {
  pending, // clock: not yet sent to server
  sent, // single check: reached server
  delivered, // double check (muted): delivered to other device
  read, // double check (readReceiptGreen): other person opened the room
}

/// Read Receipt Icon (uses MekaarColors — no hardcoded colors)
class ReadReceiptIcon extends StatelessWidget {
  final ReadReceiptStatus status;
  final Color color;

  const ReadReceiptIcon({
    super.key,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
}
