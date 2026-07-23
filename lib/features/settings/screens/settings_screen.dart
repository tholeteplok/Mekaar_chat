import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/font_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/user_model.dart';
import '../providers/privacy_provider.dart';
import '../providers/two_fa_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/account_snippet_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // ─────────────────────────────────────────────────
  // Helper: divider antar section
  // ─────────────────────────────────────────────────
  Widget _divider(BuildContext context) {
    return Divider(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
      height: 32,
    );
  }

  // ─────────────────────────────────────────────────
  // Helper: header section (label uppercase)
  // ─────────────────────────────────────────────────
  Widget _sectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Text(label.toUpperCase(), style: MekaarTypography.overline),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 1: Tampilan — selector tema & font
  // ─────────────────────────────────────────────────
  Widget _buildDisplaySection(BuildContext context, WidgetRef ref) {
    final currentFontKey = ref.watch(fontFamilyProvider);
    final activeFont = AppFontFamily.findByKey(currentFontKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tampilan'),
        _ThemeSelector(
          current: ref.watch(themeModeProvider),
          onChanged: (mode) =>
              ref.read(themeModeProvider.notifier).setMode(mode),
        ),
        SettingsNavTile(
          icon: SolarIconsOutline.textSquare,
          title: 'Gaya Font',
          subtitle:
              '${activeFont.displayName} (${activeFont.category == FontCategory.playful ? "Playful" : "Modern"})',
          onTap: () => _showFontPickerSheet(context, ref),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 2: Akun — snippet profil + logout
  // ─────────────────────────────────────────────────
  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Akun'),
        const AccountSnippetCard(),
        if (!wasDuress) ...[
          const SizedBox(height: 4),
          const SettingsLogoutTile(),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // ─────────────────────────────────────────────────
  // SECTION 3: Privasi
  // ─────────────────────────────────────────────────
  Widget _buildPrivacySection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Privasi'),
        SettingsSwitchTile(
          icon: SolarIconsOutline.screenShare,
          title: 'Proteksi Layar',
          subtitle: 'Cegah screenshot & perekaman layar',
          value: ref.watch(screenshotBlockProvider),
          onChanged: (value) =>
              ref.read(screenshotBlockProvider.notifier).toggle(value),
        ),
        SettingsSwitchTile(
          icon: SolarIconsOutline.eye,
          title: 'Sembunyikan Notifikasi Darurat',
          subtitle: 'Samarkan teks alarm di layar kunci',
          value: ref.watch(notificationMaskingProvider),
          onChanged: (value) =>
              ref.read(notificationMaskingProvider.notifier).setEnabled(value),
        ),
        SettingsNavTile(
          icon: SolarIconsOutline.user,
          title: 'Terakhir Dilihat & Online',
          subtitle: ref.watch(lastSeenPrivacyProvider).label,
          onTap: () => _showLastSeenSheet(context, ref),
        ),
        SettingsSwitchTile(
          icon: SolarIconsOutline.checkCircle,
          title: 'Bukti Baca (Read Receipt)',
          subtitle: 'Tanda centang biru saat pesan dibaca',
          value: ref.watch(readReceiptsProvider),
          onChanged: (value) =>
              ref.read(readReceiptsProvider.notifier).setEnabled(value),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 4: Keamanan
  // ─────────────────────────────────────────────────
  Widget _buildSecuritySection(BuildContext context, WidgetRef ref) {
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Keamanan'),
        SettingsSwitchTile(
          icon: SolarIconsOutline.lock,
          title: 'Kunci PIN Aplikasi',
          subtitle: 'Kunci aplikasi dengan 6-digit PIN',
          value: ref.watch(pinLockEnabledProvider),
          onChanged: (bool value) async {
            try {
              await ref.read(pinLockEnabledProvider.notifier).toggle(value);
            } catch (_) {
              if (context.mounted) {
                MekaarSnackbar.error(
                  context,
                  'Pengaturan kunci PIN gagal disimpan. Coba lagi.',
                );
              }
            }
          },
        ),
        if (!wasDuress) ...[
          SettingsNavTile(
            icon: SolarIconsOutline.lockKeyhole,
            title: 'PIN Paksaan (Duress)',
            subtitle: 'PIN rahasia pemicu alarm SOS',
            onTap: () => Navigator.pushNamed(context, AppRoutes.duressPin),
          ),
          SettingsNavTile(
            icon: SolarIconsOutline.shieldKeyhole,
            title: 'Verifikasi 2 Langkah',
            subtitle: ref.watch(twoFaProvider)
                ? 'Aktif · kode authenticator'
                : 'Nonaktif · keamanan ekstra',
            onTap: () => _handleTwoFactor(context, ref),
          ),
          SettingsNavTile(
            icon: SolarIconsOutline.billList,
            title: 'Riwayat SOS',
            subtitle: 'Catatan insiden darurat SOS',
            onTap: () => Navigator.pushNamed(context, AppRoutes.logs),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 5: Notifikasi — suara & nada
  // ─────────────────────────────────────────────────
  Widget _buildNotificationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Notifikasi'),
        SettingsNavTile(
          icon: SolarIconsOutline.bell,
          title: 'Nada & Suara',
          subtitle: 'Nada notifikasi pesan & alarm SOS',
          onTap: () => Navigator.pushNamed(context, AppRoutes.soundPicker),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 6: Sistem — haptic global + guardian & darurat
  // ─────────────────────────────────────────────────
  Widget _buildSystemSection(BuildContext context, WidgetRef ref) {
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;

    // Baca preferensi haptics dari notificationPreferencesProvider
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final hapticsEnabled = prefsAsync.value?.hapticsEnabled ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Sistem'),
        SettingsSwitchTile(
          icon: SolarIconsOutline.smartphoneVibration,
          title: 'Getaran',
          subtitle:
              'Aktifkan respons getar untuk ketukan, konfirmasi, dan peringatan di seluruh aplikasi',
          value: hapticsEnabled,
          onChanged: prefsAsync.hasValue
              ? (value) => ref
                  .read(notificationPreferencesProvider.notifier)
                  .toggleHaptics(value)
              : null,
        ),
        if (!wasDuress) ...[
          SettingsSwitchTile(
            icon: SolarIconsOutline.volumeLoud,
            title: 'Izin Guardian Alarm',
            subtitle:
                'Izinkan wali membunyikan sirine keras pada perangkat Anda (berlaku untuk SOS & non-SOS)',
            value: ref.watch(allowGuardianAlarmProvider),
            onChanged: (value) =>
                ref.read(allowGuardianAlarmProvider.notifier).setEnabled(value),
          ),
          SettingsNavTile(
            icon: SolarIconsOutline.gps,
            title: 'Temukan Ponsel Saya',
            subtitle: 'Mode perangkat hilang (self-guardian)',
            onTap: () => Navigator.pushNamed(context, AppRoutes.deviceLost),
          ),
          SettingsNavTile(
            icon: SolarIconsOutline.userBlock,
            title: 'Daftar Blokir',
            subtitle: 'Kelola pengguna yang diblokir',
            onTap: () => Navigator.pushNamed(context, AppRoutes.blockedList),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wasDuress = ref.watch(authProvider).lastUnlockWasDuress;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const MekaarTabHeader(title: 'Pengaturan'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── 1. Tampilan ──
                    _buildDisplaySection(context, ref),
                    _divider(context),

                    // ── 2. Akun ──
                    _buildAccountSection(context, ref),
                    _divider(context),

                    // ── 3. Privasi (tersembunyi saat duress) ──
                    if (!wasDuress) ...[
                      _buildPrivacySection(context, ref),
                      _divider(context),
                    ],

                    // ── 4. Keamanan ──
                    _buildSecuritySection(context, ref),
                    _divider(context),

                    // ── 5. Notifikasi ──
                    _buildNotificationSection(context),
                    _divider(context),

                    // ── 6. Sistem ──
                    _buildSystemSection(context, ref),

                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Bottom sheet: Custom Font Picker (Playful & Modern)
  // ─────────────────────────────────────────────────
  void _showFontPickerSheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Consumer(
          builder: (context, refWatch, _) {
            final activeKey = refWatch.watch(fontFamilyProvider);

            final playfulFonts = AppFontFamily.availableFonts
                .where((f) => f.category == FontCategory.playful)
                .toList();
            final modernFonts = AppFontFamily.availableFonts
                .where((f) => f.category == FontCategory.modern)
                .toList();

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Pilih Gaya Font Aplikasi',
                          style: MekaarTypography.headingSM,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Ubah karakter teks di seluruh aplikasi (Youth & Playful)',
                          style: MekaarTypography.bodySM.copyWith(
                            color: isDark
                                ? MekaarColors.textMuted
                                : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Kategori 1: Youth & Playful / Comic
                      _fontCategoryHeader('YOUTH & PLAYFUL / COMIC'),
                      const SizedBox(height: 8),
                      ...playfulFonts.map(
                        (font) => _buildFontTile(
                          ctx,
                          ref,
                          font,
                          activeKey == font.key,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Kategori 2: Clean & Modern
                      _fontCategoryHeader('CLEAN & MODERN'),
                      const SizedBox(height: 8),
                      ...modernFonts.map(
                        (font) => _buildFontTile(
                          ctx,
                          ref,
                          font,
                          activeKey == font.key,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fontCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: MekaarTypography.overline.copyWith(
          color: MekaarColors.softCoral,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFontTile(
    BuildContext context,
    WidgetRef ref,
    AppFontFamily font,
    bool isSelected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontStyle = GoogleFonts.getFont(
      font.key,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? MekaarColors.softCoral.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? MekaarColors.softCoral : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          font.displayName,
          style: fontStyle.copyWith(
            color: isSelected
                ? MekaarColors.softCoral
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        subtitle: Text(
          font.subtitle,
          style: MekaarTypography.bodySM.copyWith(
            fontSize: 12,
            color: isDark ? MekaarColors.textMuted : Colors.black54,
          ),
        ),
        trailing: isSelected
            ? const Icon(
                SolarIconsBold.checkCircle,
                color: MekaarColors.softCoral,
              )
            : const Icon(
                Icons.radio_button_unchecked,
                color: MekaarColors.textMuted,
                size: 20,
              ),
        onTap: () {
          ref.read(fontFamilyProvider.notifier).setFontFamily(font.key);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Bottom sheet: Last Seen Privacy
  // ─────────────────────────────────────────────────
  void _showLastSeenSheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final current = ref.watch(lastSeenPrivacyProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Terakhir Dilihat & Online',
                style: MekaarTypography.headingSM,
              ),
              const SizedBox(height: 8),
              ...LastSeenPrivacy.values.map((privacy) {
                final selected = privacy == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? SolarIconsBold.checkCircle
                        : SolarIconsOutline.user,
                    color: selected ? MekaarColors.softCoral : null,
                  ),
                  title: Text(privacy.label),
                  trailing: selected
                      ? const Icon(Icons.check, color: MekaarColors.softCoral)
                      : null,
                  onTap: () {
                    ref
                        .read(lastSeenPrivacyProvider.notifier)
                        .setPrivacy(privacy);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // Dialog: Two Factor Authentication
  // ─────────────────────────────────────────────────
  Future<void> _handleTwoFactor(BuildContext context, WidgetRef ref) async {
    final enabled = ref.read(twoFaProvider);
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Matikan 2 Langkah?'),
          content: const Text(
            'Login tidak lagi meminta kode authenticator. Akun jadi kurang aman.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Matikan'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        try {
          await ref.read(twoFaProvider.notifier).disable();
          if (context.mounted) {
            MekaarSnackbar.success(context, 'Verifikasi 2 Langkah dimatikan.');
          }
        } catch (e) {
          if (context.mounted) {
            MekaarSnackbar.error(
              context,
              'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
            );
          }
        }
      }
    } else {
      if (context.mounted) {
        Navigator.pushNamed(context, AppRoutes.twoFactorSetup);
      }
    }
  }
}

// ─────────────────────────────────────────────────
// Theme Selector Widget (tidak berubah dari versi sebelumnya)
// ─────────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.current, required this.onChanged});

  static const double z = 24.0;
  static const double activeSize = z + 16.0;
  static const double barHeight = z + 32.0;
  static const double barWidth = 3.0 * (z + 32.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    final navBgColor = isDark ? MekaarColors.cardDark : MekaarColors.surface2;
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    const options = [
      (ThemeMode.system, SolarIconsOutline.tuning, 'Sistem'),
      (ThemeMode.light, SolarIconsOutline.sun, 'Terang'),
      (ThemeMode.dark, SolarIconsOutline.moon, 'Gelap'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          width: barWidth,
          height: barHeight,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: navBgColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: navBorderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: options.map((opt) {
              final selected = current == opt.$1;
              final inactiveColor =
                  isDark ? MekaarColors.textMuted : Colors.black45;

              return Semantics(
                button: true,
                selected: selected,
                label: 'Tema ${opt.$3.toLowerCase()}',
                child: InkResponse(
                  onTap: () => onChanged(opt.$1),
                  radius: barHeight / 2,
                  child: SizedBox(
                    width: z + 32.0,
                    height: barHeight,
                    child: Center(
                      child: AnimatedContainer(
                        duration: animationsDisabled
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: selected ? activeSize : z,
                        height: selected ? activeSize : z,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? MekaarColors.softCoral
                              : Colors.transparent,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: MekaarColors.softCoral
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            opt.$2,
                            color: selected ? Colors.white : inactiveColor,
                            size: z,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
