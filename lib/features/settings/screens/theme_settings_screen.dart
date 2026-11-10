import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/theme_resolver.dart';
import '../../../core/constants/theme_preference.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/font_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_icon_badge.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';

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
    final currentFontKey = ref.watch(fontFamilyProvider).valueOrNull ?? AppFontFamily.defaultFontKey;
    final activeFont = AppFontFamily.findByKey(currentFontKey);
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
                    _buildLivePreviewCard(context, activeThemeData, activeFont, currentPref, greetingName),

                    // ── 2. Mode Tema Utama ──
                    const SettingsSectionHeader(title: 'Mode Tema'),
                    _buildThemePreferenceSelector(context, ref, currentPref),

                    // ── 3. Tipografi & Font Family ──
                    const SettingsSectionHeader(title: 'Tipografi & Gaya Tulisan'),
                    SettingsNavTile(
                      icon: SolarIconsOutline.text,
                      iconColor: MekaarColors.accentTextOf(context),
                      title: activeFont.displayName,
                      subtitle: activeFont.subtitle,
                      onTap: () => _openFontPickerBottomSheet(context, ref, currentFontKey),
                    ),

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

  /// Live Preview Viewport yang memperlihatkan tema & font aktif secara instan.
  Widget _buildLivePreviewCard(
    BuildContext context,
    ThemeData activeTheme,
    AppFontFamily activeFont,
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
            style: GoogleFonts.getFont(
              activeFont.key,
              textStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MekaarColors.textPrimaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pratinjau antarmuka Clean Core dengan font "${activeFont.displayName}".',
            style: GoogleFonts.getFont(
              activeFont.key,
              textStyle: TextStyle(
                fontSize: 14,
                color: MekaarColors.textMutedOf(context),
              ),
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

  /// Bottom Sheet Pemilih Font Family
  void _openFontPickerBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String currentFontKey,
  ) {
    final notifier = ref.read(fontFamilyProvider.notifier);

    int selectedTabIndex = 0;

    MekaarBottomSheet.show(
      context: context,
      title: 'Pilih Gaya Tulisan (Font)',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: MekaarSlidingSegmentBar(
                  margin: EdgeInsets.zero,
                  height: 40,
                  tabs: const [
                    'Modern & Clean',
                    'Playful & Komik',
                  ],
                  selectedIndex: selectedTabIndex,
                  onTabSelected: (index) {
                    setSheetState(() {
                      selectedTabIndex = index;
                    });
                  },
                ),
              ),
              SizedBox(
                height: 320,
                child: AnimatedSwitcher(
                  duration: context.motion(MekaarMotion.fast),
                  child: _buildFontListCategory(
                    context,
                    notifier,
                    currentFontKey,
                    selectedTabIndex == 0
                        ? FontCategory.modern
                        : FontCategory.playful,
                    key: ValueKey<int>(selectedTabIndex),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFontListCategory(
    BuildContext context,
    FontFamilyNotifier notifier,
    String currentFontKey,
    FontCategory category, {
    Key? key,
  }) {
    final fonts = AppFontFamily.availableFonts
        .where((f) => f.category == category)
        .toList();

    return ListView.separated(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: MekaarSpacing.md),
      itemCount: fonts.length,
      separatorBuilder: (ctx, index) => const MekaarCardDivider(indent: 16),
      itemBuilder: (ctx, idx) {
        final font = fonts[idx];
        final selected = font.key == currentFontKey;

        return ListTile(
          selected: selected,
          title: Text(
            font.displayName,
            style: GoogleFonts.getFont(
              font.key,
              textStyle: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
                color: selected ? MekaarColors.accentTextOf(context) : MekaarColors.textPrimaryOf(context),
              ),
            ),
          ),
          subtitle: Text(
            font.subtitle,
            style: GoogleFonts.getFont(
              font.key,
              textStyle: TextStyle(
                fontSize: 12,
                color: MekaarColors.textMutedOf(context),
              ),
            ),
          ),
          trailing: selected
              ? Icon(SolarIconsBold.checkCircle, color: MekaarColors.accentTextOf(context), size: 20)
              : null,
          onTap: () async {
            await notifier.setFontFamily(font.key);
            if (ctx.mounted) {
              Navigator.pop(ctx);
              MekaarSnackbar.success(context, 'Font diubah ke ${font.displayName}');
            }
          },
        );
      },
    );
  }
}