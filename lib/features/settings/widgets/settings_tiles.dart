import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';

/// Widget terpusat untuk item toggle (switch) di halaman Pengaturan.
/// Gunakan ini sebagai pengganti [SwitchListTile] inline agar konsisten
/// antar semua section settings — tidak ada hardcoded color.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Jika true, icon dan title ditampilkan dengan warna merah/warning.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDestructive
        ? MekaarColors.sosRed
        : (isDark ? MekaarColors.textSecondary : Colors.black54);

    return SwitchListTile(
      activeThumbColor: MekaarColors.softCoral,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 0,
      ),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? MekaarColors.cardDark : MekaarColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: MekaarTypography.labelLG.copyWith(
          fontWeight: FontWeight.bold,
          color: isDestructive ? MekaarColors.sosRed : null,
        ),
      ),
      subtitle: Text(subtitle, style: MekaarTypography.bodySM),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Widget terpusat untuk item navigasi (menu item) di halaman Pengaturan.
/// Gunakan ini sebagai pengganti [ListTile] inline agar konsisten
/// antar semua section settings — tidak ada hardcoded color.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  /// Widget custom di trailing (misal: label status). Default: chevron_right.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDestructive
        ? MekaarColors.sosRed
        : (isDark ? MekaarColors.textSecondary : Colors.black54);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? MekaarColors.cardDark : MekaarColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: MekaarTypography.labelLG.copyWith(
          fontWeight: FontWeight.bold,
          color: isDestructive
              ? MekaarColors.sosRed
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(subtitle, style: MekaarTypography.bodySM),
      trailing: trailing ??
          const Icon(
            SolarIconsOutline.altArrowRight,
            size: 18,
            color: MekaarColors.textMuted,
          ),
      onTap: onTap,
    );
  }
}
