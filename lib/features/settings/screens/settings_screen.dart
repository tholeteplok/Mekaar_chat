import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/font_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
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
  // Helper: header section (label uppercase)
  // ─────────────────────────────────────────────────
  Widget _sectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label.toUpperCase(), style: MekaarTypography.overline),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 1: Tampilan — selector tema & font
  // ─────────────────────────────────────────────────
  Widget _buildDisplaySection(BuildContext context, WidgetRef ref) {
    final currentFontKey = ref.watch(fontFamilyProvider).valueOrNull ?? AppFontFamily.defaultFontKey;
    final activeFont = AppFontFamily.findByKey(currentFontKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Tampilan'),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingsNavTile(
                icon: SolarIconsOutline.palette,
                title: 'Tampilan & Font',
                subtitle: 'Mode terang/gelap & font ${activeFont.displayName}',
                onTap: () => Navigator.pushNamed(context, AppRoutes.themeSettings),
              ),
              const MekaarCardDivider(),
              SettingsNavTile(
                icon: SolarIconsOutline.chatRoundDots,
                title: 'Tema & Wallpaper Chat',
                subtitle: 'Preset obrolan, wallpaper canvas & gaya gelembung',
                onTap: () => Navigator.pushNamed(context, AppRoutes.chatThemeSettings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Akun'),
        const AccountSnippetCard(),
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
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
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
              SettingsNavTile(
                icon: SolarIconsOutline.shieldUser,
                title: 'Proteksi Undangan Chat',
                subtitle: ref.watch(chatInvitationModeProvider) == 'approved_only'
                    ? 'Hanya yang disetujui'
                    : 'Semua orang',
                onTap: () => _showChatInvitationModeSheet(context, ref),
              ),
              SettingsNavTile(
                icon: SolarIconsOutline.mapPoint,
                title: 'Auto Check-In Rute',
                subtitle: 'Otomatisasi pengiriman pesan aman ke Guardian',
                onTap: () => Navigator.pushNamed(context, AppRoutes.tripList),
              ),
            ],
          ),
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
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
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
          ),
        ),
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
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SettingsNavTile(
            icon: SolarIconsOutline.bell,
            title: 'Nada & Suara',
            subtitle: 'Nada notifikasi pesan & alarm SOS',
            onTap: () => Navigator.pushNamed(context, AppRoutes.soundPicker),
          ),
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
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
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
          ),
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── 1. Tampilan ──
                    _buildDisplaySection(context, ref),

                    // ── 2. Akun ──
                    _buildAccountSection(context, ref),

                    // ── 3. Privasi (tersembunyi saat duress) ──
                    if (!wasDuress) ...[
                      _buildPrivacySection(context, ref),
                    ],

                    // ── 4. Keamanan ──
                    _buildSecuritySection(context, ref),

                    // ── 5. Notifikasi ──
                    _buildNotificationSection(context),

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
  void _showChatInvitationModeSheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final current = ref.watch(chatInvitationModeProvider);
        final options = [
          ('approved_only', 'Hanya yang Disetujui', 'Pengguna baru harus mengirim permintaan chat terlebih dahulu'),
          ('everyone', 'Semua Orang', 'Siapapun dapat langsung mengirim pesan kepada Anda'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Proteksi Undangan Chat',
                style: MekaarTypography.headingSM,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tentukan siapa yang dapat mengirim pesan langsung kepada Anda.',
                  style: MekaarTypography.bodySM,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final selected = opt.$1 == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? SolarIconsBold.checkCircle
                        : SolarIconsOutline.shieldUser,
                    color: selected ? MekaarColors.softCoral : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3, style: const TextStyle(fontSize: 12)),
                  trailing: selected
                      ? const Icon(MekaarIcons.check, color: MekaarColors.softCoral)
                      : null,
                  onTap: () {
                    ref
                        .read(chatInvitationModeProvider.notifier)
                        .setMode(opt.$1);
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
                      ? const Icon(MekaarIcons.check, color: MekaarColors.softCoral)
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
      final passwordController = TextEditingController();
      final password = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: MekaarColors.surface2Of(ctx),
          title: Text('Matikan 2 Langkah', style: MekaarTypography.headingSM),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan password Anda untuk mengonfirmasi penonaktifan 2FA.',
                style: MekaarTypography.bodySM,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, passwordController.text.trim()),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      );

      if (password != null && password.isNotEmpty && context.mounted) {
        try {
          await ref.read(twoFaProvider.notifier).disable(password);
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


