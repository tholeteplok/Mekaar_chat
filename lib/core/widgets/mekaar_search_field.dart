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

    final borderColor = errorText != null
        ? MekaarColors.sosRed
        : (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.14));

    final borderWidth = errorText != null ? 1.2 : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: MekaarColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.lg),
      child: Row(
        children: [
          Icon(
            SolarIconsOutline.magnifier,
            color: MekaarColors.textMutedOf(context),
            size: MekaarSizes.iconMd,
          ),
          const SizedBox(width: MekaarSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              style: TextStyle(
                color: MekaarColors.textPrimaryOf(context),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: MekaarColors.textMutedOf(context),
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
