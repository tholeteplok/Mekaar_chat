import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/theme_resolver.dart';
import '../../../core/constants/theme_preference.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/widgets/mekaar_icon_badge.dart';
import '../../../core/widgets/mekaar_scaffold.dart';

import '../../auth/providers/auth_provider.dart';
import '../widgets/settings_tiles.dart';

/// Layar Terpisah untuk Pengaturan Tampilan, Tema, dan Tipografi MEKAAR.
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).profile == null) {
        ref.read(authProvider.notifier).loadProfile();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    ref.watch(timeTickProvider);
    final currentPref = ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.auto;
    final activeThemeData = ref.watch(resolvedThemeDataProvider);
    final authState = ref.watch(authProvider);
    final profile = authState.profile;
    final displayName = profile?.displayName?.trim();
    final fullName = profile?.fullName?.trim();
    final username = profile?.username.trim();

    final greetingName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (username != null && username.isNotEmpty)
                ? username
                : 'MEKAAR User';

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Tampilan & Tema'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Live Preview Card ──
                    _buildLivePreviewCard(context, activeThemeData, currentPref, greetingName),

                    // ── 2. Mode Tema Utama ──
                    const SettingsSectionHeader(title: 'Mode Tema'),
                    _buildThemePreferenceSelector(context, ref, currentPref),

                    const SizedBox(height: MekaarSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Live Preview Viewport yang memperlihatkan tema aktif secara instan.
  Widget _buildLivePreviewCard(
    BuildContext context,
    ThemeData activeTheme,
    ThemePreference currentPref,
    String greetingName,
  ) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final isDark = ThemeResolver.isCurrentlyDark(currentPref);

    String modeBadge;
    switch (currentPref) {
      case ThemePreference.light:
        modeBadge = '☀️ Mode Terang';
        break;
      case ThemePreference.dark:
        modeBadge = '🌙 Mode Gelap';
        break;
      case ThemePreference.auto:
        modeBadge = isDark ? '🌙 Otomatis (Gelap)' : '🌤 Otomatis (Terang)';
        break;
    }

    const brandColor = AppColors.blue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(MekaarSpacing.lg),
      decoration: BoxDecoration(
        color: MekaarColors.surface2Of(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  modeBadge,
                  style: MekaarTypography.bodySM.copyWith(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: MekaarTypography.monoLG.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: MekaarSpacing.md),
          Text(
            'Halo, $greetingName!',
            style: MekaarTypography.headingMD.copyWith(
              color: MekaarColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pratinjau antarmuka Clean Core MEKAAR.',
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textMutedOf(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Pilihan Mode Tema Utama (3 Pilihan: Otomatis, Terang, Gelap)
  Widget _buildThemePreferenceSelector(
    BuildContext context,
    WidgetRef ref,
    ThemePreference currentPref,
  ) {
    final notifier = ref.read(themePreferenceProvider.notifier);

    final options = [
      (
        ThemePreference.auto,
        'Otomatis (Ikuti Jam Device)',
        '06.00–18.00 Terang, 18.00–06.00 Gelap.',
        SolarIconsOutline.clockCircle,
        AppColors.blue,
      ),
      (
        ThemePreference.light,
        'Mode Terang (Light)',
        'Tampilan bersih dan minimalis sepanjang hari.',
        SolarIconsOutline.sun2,
        AppColors.blue,
      ),
      (
        ThemePreference.dark,
        'Mode Gelap (Dark)',
        'Tampilan gelap yang nyaman di mata sepanjang hari.',
        SolarIconsOutline.moon,
        AppColors.blue,
      ),
    ];

    return Column(
      children: List.generate(options.length, (index) {
        final opt = options[index];
        final selected = currentPref == opt.$1;

        return Column(
          children: [
            if (index > 0)
              Divider(
                height: 1,
                thickness: 0.8,
                indent: 74,
                endIndent: 0,
                color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
              ),
            InkWell(
              onTap: () => notifier.setPreference(opt.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    MekaarIconBadge(
                      icon: opt.$4,
                      color: opt.$5,
                      circle: true,
                      size: 40,
                      backgroundColor:
                          opt.$5.withValues(alpha: selected ? 0.20 : 0.10),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.$2,
                            style: MekaarTypography.bodyMD.copyWith(
                              fontSize: 15,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                              color: MekaarColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.$3,
                            style: MekaarTypography.bodySM.copyWith(
                              fontSize: 12,
                              color: MekaarColors.textMutedOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(SolarIconsBold.checkCircle, color: opt.$5, size: 22),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}