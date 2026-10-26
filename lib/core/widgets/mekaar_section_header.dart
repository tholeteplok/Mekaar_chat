import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';

/// Header seksi terpusat dengan tipografi seragam, proporsional, dan adaptif.
/// Digunakan di seluruh halaman aplikasi (Settings, Sheets, Info, dll.)
/// untuk menjamin konsistensi ukuran font, ketebalan, dan ritme vertikal.
class MekaarSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? titleColor;
  final EdgeInsetsGeometry padding;

  const MekaarSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleColor,
    this.padding = const EdgeInsets.only(left: 4, top: 18, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: MekaarTypography.sectionHeader.copyWith(
        color: titleColor ?? MekaarColors.textPrimaryOf(context),
      ),
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing == null)
            titleWidget
          else
            Row(
              children: [
                Expanded(child: titleWidget),
                trailing!,
              ],
            ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
