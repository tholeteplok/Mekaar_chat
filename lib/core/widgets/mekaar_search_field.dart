import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

class MekaarSearchField extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String hintText;
  final String? errorText;

  const MekaarSearchField({
    super.key,
    this.onChanged,
    this.controller,
    this.hintText = 'Cari...',
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? MekaarColors.cardDark : MekaarColors.surface2,
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        border: Border.all(
          color: errorText == null ? Colors.transparent : MekaarColors.sosRed,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.lg),
      child: Row(
        children: [
          Icon(
            SolarIconsOutline.magnifier,
            color: isDark ? MekaarColors.textMuted : Colors.black45,
            size: MekaarSizes.iconMd,
          ),
          const SizedBox(width: MekaarSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: isDark ? MekaarColors.textMuted : Colors.black38,
                ),
                errorText: errorText,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: MekaarSpacing.md,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
