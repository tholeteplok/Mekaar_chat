import 'package:flutter/material.dart';
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
    return Container(
      decoration: BoxDecoration(
        color: MekaarColors.surface2,
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        border: Border.all(
          color: errorText == null ? Colors.transparent : MekaarColors.sosRed,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.lg),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: MekaarColors.textMuted,
            size: MekaarSizes.iconMd,
          ),
          const SizedBox(width: MekaarSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
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
