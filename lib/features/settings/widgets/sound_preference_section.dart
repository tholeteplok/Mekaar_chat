import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
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
              Expanded(child: Text(title, style: MekaarTypography.overline)),
              if (canDisable)
                Switch.adaptive(
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
            ],
          ),
          const SizedBox(height: 12),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 180),
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
                  const Divider(color: MekaarColors.borderLight, height: 1),
                  ListTile(
                    enabled: enabled,
                    leading: Icon(
                      SolarIconsOutline.musicLibrary2,
                      color: accentColor,
                    ),
                    title: Text(
                      'Pilih file kustom dari HP',
                      style: MekaarTypography.labelLG.copyWith(
                        color: accentColor,
                      ),
                    ),
                    onTap: enabled ? onPickCustom : null,
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
    return ListTile(
      enabled: enabled,
      leading: IconButton(
        tooltip: previewing ? 'Hentikan pratinjau' : 'Putar pratinjau',
        onPressed: enabled ? () => onPreview(option.path) : null,
        icon: Icon(
          previewing
              ? SolarIconsBold.stopCircle
              : SolarIconsOutline.playCircle,
          color: accentColor,
        ),
      ),
      title: Text(
        option.name,
        style: MekaarTypography.labelLG.copyWith(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? Icon(SolarIconsBold.checkCircle, color: accentColor)
          : null,
      onTap: enabled ? () => onSelected(option.path) : null,
    );
  }
}
