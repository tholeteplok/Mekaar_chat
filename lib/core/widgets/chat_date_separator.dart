import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';

/// Pemisah tanggal di tengah chat dengan gaya pill ringan.
/// Menampilkan label kontekstual: "Hari ini", "Kemarin", "Senin, 20 Jul", dll.
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  String _formatLabel(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Hari ini';
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Kemarin';

    final diff = today.difference(msgDate).inDays;
    if (diff < 7) {
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      return '${days[msgDate.weekday - 1]}, ${msgDate.day} ${_monthAbbr(msgDate.month)}';
    }

    if (date.year == now.year) {
      return '${msgDate.day} ${_monthAbbr(msgDate.month)}';
    }
    return '${msgDate.day} ${_monthAbbr(msgDate.month)} ${msgDate.year}';
  }

  String _monthAbbr(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MekaarSpacing.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.lg,
            vertical: MekaarSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: MekaarColors.surface2Of(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(MekaarRadius.pill),
          ),
          child: Text(
            _formatLabel(context),
            style: MekaarTypography.labelSM.copyWith(
              color: MekaarColors.textMutedOf(context),
            ),
          ),
        ),
      ),
    );
  }
}
