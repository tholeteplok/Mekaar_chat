import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/theme_resolver.dart';
import '../../../core/constants/time_palette.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/font_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';

import '../widgets/settings_tiles.dart';

/// Layar Terpisah untuk Pengaturan Tampilan, Tema, dan Tipografi MEKAAR.
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    ref.watch(timeTickProvider);
    final currentPref = ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.auto;
    final currentFontKey = ref.watch(fontFamilyProvider).valueOrNull ?? AppFontFamily.defaultFontKey;
    final activeFont = AppFontFamily.findByKey(currentFontKey);
    final activeThemeData = ref.watch(resolvedThemeDataProvider);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Tampilan & Tema'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Live Preview Card ──
                    _buildLivePreviewCard(context, activeThemeData, activeFont, currentPref),

            const SizedBox(height: MekaarSpacing.xl),

            // ── 2. Mode Tema Utama ──
            Text('MODE TEMA & ATMOSFER WAKTU', style: MekaarTypography.overline),
            const SizedBox(height: MekaarSpacing.sm),
            _buildThemePreferenceSelector(context, ref, currentPref),

            const SizedBox(height: MekaarSpacing.xl),

            // ── 3. Tipografi & Font Family ──
            Text('TIPOGRAFI & GAYA TULISAN', style: MekaarTypography.overline),
            const SizedBox(height: MekaarSpacing.sm),
            CustomCard(
              padding: const EdgeInsets.all(MekaarSpacing.md),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MekaarColors.accentTextOf(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                  child: Icon(SolarIconsOutline.text, color: MekaarColors.accentTextOf(context), size: 22),
                ),
                title: Text(
                  activeFont.displayName,
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.textPrimaryOf(context),
                  ),
                ),
                subtitle: Text(
                  activeFont.subtitle,
                  style: MekaarTypography.bodySM.copyWith(
                    color: MekaarColors.textMutedOf(context),
                  ),
                ),
                trailing: Icon(
                  SolarIconsOutline.altArrowRight,
                  color: MekaarColors.textMutedOf(context),
                  size: 18,
                ),
                onTap: () => _openFontPickerBottomSheet(context, ref, currentFontKey),
              ),
            ),

            const SizedBox(height: MekaarSpacing.xl),

            // ── 4. Slot Ekstensi Kustomisasi Masa Depan ──
            Text('KUSTOMISASI LANJUTAN (SEGERA HADIR)', style: MekaarTypography.overline),
            const SizedBox(height: MekaarSpacing.sm),
            CustomCard(
              padding: const EdgeInsets.all(MekaarSpacing.md),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                      ),
                      child: Icon(SolarIconsOutline.palette, color: MekaarColors.textMutedOf(context), size: 20),
                    ),
                    title: Text(
                      'Aksen Warna Primary',
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    subtitle: Text(
                      'Default disesuaikan otomatis dengan palet fase waktu.',
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Auto', style: MekaarTypography.bodySM.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MekaarColors.accentTextOf(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                      ),
                      child: Icon(SolarIconsOutline.gallery, color: MekaarColors.accentTextOf(context), size: 20),
                    ),
                    title: Text(
                      'Wallpaper Chat & Gelembung',
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    subtitle: Text(
                      'Atur wallpaper, gaya gelembung, dan warna obrolan.',
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                    trailing: Icon(
                      SolarIconsOutline.altArrowRight,
                      color: MekaarColors.textMutedOf(context),
                      size: 18,
                    ),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.chatThemeSettings),
                  ),
                ],
              ),
            ),
                    const SizedBox(height: MekaarSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Live Card Preview yang memperlihatkan tema & font aktif secara instan.
  Widget _buildLivePreviewCard(
    BuildContext context,
    ThemeData activeTheme,
    AppFontFamily activeFont,
    ThemePreference currentPref,
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

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.lg),
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
          SizedBox(height: MekaarSpacing.md),
          Text(
            'Halo, MEKAAR User!',
            style: GoogleFonts.getFont(
              activeFont.key,
              textStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MekaarColors.textPrimaryOf(context),
              ),
            ),
          ),
          SizedBox(height: 4),
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

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        children: List.generate(options.length, (index) {
          final opt = options[index];
          final selected = currentPref == opt.$1;

          return InkWell(
            onTap: () => notifier.setPreference(opt.$1),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: opt.$5.withValues(alpha: selected ? 0.20 : 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(opt.$4, color: opt.$5, size: 20),
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
                        SizedBox(height: 2),
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
          );
        }),
      ),
    );
  }

  /// Bottom Sheet Pemilih Font Family
  void _openFontPickerBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String currentFontKey,
  ) {
    final notifier = ref.read(fontFamilyProvider.notifier);

    MekaarBottomSheet.show(
      context: context,
      title: 'Pilih Gaya Tulisan (Font)',
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              labelColor: MekaarColors.accentTextOf(context),
              unselectedLabelColor: MekaarColors.textMutedOf(context),
              indicatorColor: MekaarColors.accentTextOf(context),
              tabs: const [
                Tab(text: 'Modern & Clean'),
                Tab(text: 'Playful & Komik'),
              ],
            ),
            SizedBox(
              height: 320,
              child: TabBarView(
                children: [
                  _buildFontListCategory(
                    context,
                    notifier,
                    currentFontKey,
                    FontCategory.modern,
                  ),
                  _buildFontListCategory(
                    context,
                    notifier,
                    currentFontKey,
                    FontCategory.playful,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontListCategory(
    BuildContext context,
    FontFamilyNotifier notifier,
    String currentFontKey,
    FontCategory category,
  ) {
    final fonts = AppFontFamily.availableFonts
        .where((f) => f.category == category)
        .toList();

    return ListView.separated(
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