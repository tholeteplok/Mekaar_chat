import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_icon_badge.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';

class SoundOption {
  final String name;
  final String path;

  const SoundOption(this.name, this.path);
}

class SoundPreferenceSection extends StatelessWidget {
  final String title;
  final List<SoundOption> options;
  final String selectedPath;
  final String? previewingPath;
  final bool previewIsPlaying;
  final Color accentColor;
  final bool enabled;
  final bool canDisable;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onPreview;
  final VoidCallback onPickCustom;
  final ValueChanged<bool>? onEnabledChanged;

  const SoundPreferenceSection({
    super.key,
    required this.title,
    required this.options,
    required this.selectedPath,
    required this.previewingPath,
    required this.previewIsPlaying,
    required this.accentColor,
    required this.enabled,
    required this.canDisable,
    required this.onSelected,
    required this.onPreview,
    required this.onPickCustom,
    this.onEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: MekaarTypography.bodyMD.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: MekaarColors.textPrimaryOf(context),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (canDisable)
                Switch.adaptive(
                  value: enabled,
                  onChanged: (val) {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    onEnabledChanged?.call(val);
                  },
                  activeThumbColor: accentColor,
                  activeTrackColor: accentColor.withValues(alpha: 0.35),
                  inactiveThumbColor: MekaarColors.textMutedOf(context),
                  inactiveTrackColor: MekaarColors.surface2Of(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          CustomCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: MekaarMotion.fast,
              child: Column(
                children: [
                  for (final option in options)
                    _SoundTile(
                      option: option,
                      selected: selectedPath == option.path,
                      previewing:
                          previewIsPlaying && previewingPath == option.path,
                      accentColor: accentColor,
                      enabled: enabled,
                      onSelected: onSelected,
                      onPreview: onPreview,
                    ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: enabled
                        ? () {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            onPickCustom();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          MekaarIconBadge(
                            icon: SolarIconsOutline.musicLibrary2,
                            color: accentColor,
                            circle: true,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pilih file kustom dari HP',
                              style: MekaarTypography.bodyMD.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              SolarIconsOutline.altArrowRight,
                              color: MekaarColors.textMutedOf(context),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  final SoundOption option;
  final bool selected;
  final bool previewing;
  final bool enabled;
  final Color accentColor;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onPreview;

  const _SoundTile({
    required this.option,
    required this.selected,
    required this.previewing,
    required this.enabled,
    required this.accentColor,
    required this.onSelected,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () {
              HapticService.trigger(MekaarHapticIntent.selection);
              onSelected(option.path);
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Play / Stop Icon Button Badge
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled
                  ? () {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      onPreview(option.path);
                    }
                  : null,
              child: MekaarIconBadge(
                icon: previewing
                    ? SolarIconsBold.stopCircle
                    : SolarIconsOutline.playCircle,
                color: accentColor,
                circle: true,
                size: 44,
                backgroundColor: accentColor.withValues(
                  alpha: previewing ? 0.25 : 0.12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.name,
                style: MekaarTypography.bodyMD.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
            ),
            if (selected)
              Icon(
                SolarIconsBold.checkCircle,
                color: accentColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
