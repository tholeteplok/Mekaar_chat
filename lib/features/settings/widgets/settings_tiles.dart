import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';

/// Header sub-settings terpusat dengan tombol kembali (<) squircle dan judul besar konsisten
class SettingsTopBar extends StatelessWidget {
  const SettingsTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  if (onBack != null) {
                    onBack!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                icon: Icon(
                  SolarIconsOutline.altArrowLeft,
                  color: MekaarColors.textPrimaryOf(context),
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: MekaarColors.surface2Of(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MekaarTypography.headingLG.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: MekaarColors.textPrimaryOf(context),
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu accordion dropdown terpusat untuk bagian pengaturan/informasi
/// yang dapat diperluas/diciutkan secara halus dengan animasi dan haptic feedback.
class SettingsExpandableCard extends StatefulWidget {
  const SettingsExpandableCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<SettingsExpandableCard> createState() => _SettingsExpandableCardState();
}

class _SettingsExpandableCardState extends State<SettingsExpandableCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.iconColor ?? MekaarColors.cyan;

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      color: effectiveColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: MekaarTypography.bodyMD.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle ??
                              (_isExpanded
                                  ? 'Ketuk untuk menutup'
                                  : 'Ketuk untuk melihat detail'),
                          style: MekaarTypography.caption.copyWith(
                            fontSize: 12,
                            color: MekaarColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      SolarIconsOutline.altArrowDown,
                      color: MekaarColors.textSecondaryOf(context),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: MekaarColors.border.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                ...widget.children,
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

/// Header seksi terpusat dengan tipografi bersih dan proporsional
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(left: 4, top: 18, bottom: 8),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: MekaarTypography.bodyMD.copyWith(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: MekaarColors.textPrimaryOf(context),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Widget terpusat untuk item toggle (switch) di halaman Pengaturan.
/// Menggunakan semantic MekaarColors tanpa hardcoded color.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor,
    this.iconBgColor,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final themePrimary = isDestructive
        ? MekaarColors.sosRed
        : MekaarColors.primaryOf(context);

    final effectiveIconColor = isDestructive
        ? MekaarColors.sosRed
        : (iconColor ?? themePrimary);

    final effectiveIconBgColor = isDestructive
        ? MekaarColors.sosRed.withValues(alpha: 0.12)
        : (iconBgColor ?? effectiveIconColor.withValues(alpha: 0.12));

    return InkWell(
      onTap: onChanged == null
          ? null
          : () {
              HapticService.trigger(MekaarHapticIntent.selection);
              onChanged!(!value);
            },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Icon Badge dengan background tint lembut
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveIconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: effectiveIconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: MekaarTypography.bodyMD.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? MekaarColors.sosRed
                          : MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: MekaarTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // State Label + Switch
            Text(
              value ? 'Aktif' : 'Off',
              style: MekaarTypography.caption.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: value
                    ? themePrimary
                    : MekaarColors.textMutedOf(context),
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (val) {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      onChanged!(val);
                    },
              activeThumbColor: themePrimary,
              activeTrackColor: themePrimary.withValues(alpha: 0.35),
              inactiveThumbColor: MekaarColors.textMutedOf(context),
              inactiveTrackColor: MekaarColors.surface2Of(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget terpusat untuk item navigasi (menu item) di halaman Pengaturan.
/// Menggunakan semantic MekaarColors tanpa hardcoded color.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.valueText,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final String? valueText;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isDestructive
        ? MekaarColors.sosRed
        : (iconColor ?? MekaarColors.cyan);

    final effectiveIconBgColor = isDestructive
        ? MekaarColors.sosRed.withValues(alpha: 0.12)
        : (iconBgColor ?? effectiveIconColor.withValues(alpha: 0.12));

    return InkWell(
      onTap: () {
        HapticService.trigger(MekaarHapticIntent.selection);
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Icon Badge dengan background tint lembut
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveIconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: effectiveIconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: MekaarTypography.bodyMD.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? MekaarColors.sosRed
                          : MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: MekaarTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Trailing status & arrow squircle
            if (trailing != null)
              trailing!
            else ...[
              if (valueText != null && valueText!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    valueText!,
                    style: MekaarTypography.bodySM.copyWith(
                      fontSize: 13,
                      color: MekaarColors.textMutedOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MekaarColors.surface2Of(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 14,
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
