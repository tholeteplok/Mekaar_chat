import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/font_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/user_model.dart';
import '../providers/privacy_provider.dart';
import '../providers/two_fa_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../../chat/providers/nearby_friends_provider.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/account_snippet_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // ─────────────────────────────────────────────────
  // SECTION 1: Tampilan — selector tema & font
  // ─────────────────────────────────────────────────
  Widget _buildDisplaySection(BuildContext context, WidgetRef ref) {
    final currentFontKey = ref.watch(fontFamilyProvider).valueOrNull ?? AppFontFamily.defaultFontKey;
    final activeFont = AppFontFamily.findByKey(currentFontKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Tampilan'),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingsNavTile(
                icon: SolarIconsOutline.palette,
                iconColor: MekaarColors.purple,
                title: 'Tampilan & Font',
                valueText: activeFont.displayName,
                onTap: () => Navigator.pushNamed(context, AppRoutes.themeSettings),
              ),
              SettingsNavTile(
                icon: SolarIconsOutline.chatRoundDots,
                title: 'Tema & Wallpaper Chat',
                onTap: () => Navigator.pushNamed(context, AppRoutes.chatThemeSettings),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: 'Akun'),
        AccountSnippetCard(),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 3: Privasi
  // ─────────────────────────────────────────────────
  Widget _buildPrivacySection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Privasi'),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingsSwitchTile(
                icon: SolarIconsOutline.screenShare,
                iconColor: MekaarColors.guardianTeal,
                title: 'Proteksi Layar',
                value: ref.watch(screenshotBlockProvider),
                onChanged: (value) =>
                    ref.read(screenshotBlockProvider.notifier).toggle(value),
              ),
              SettingsSwitchTile(
                icon: SolarIconsOutline.eye,
                iconColor: MekaarColors.warning,
                title: 'Sembunyikan Notifikasi Darurat',
                value: ref.watch(notificationMaskingProvider),
                onChanged: (value) =>
                    ref.read(notificationMaskingProvider.notifier).setEnabled(value),
              ),
              SettingsNavTile(
                icon: SolarIconsOutline.user,
                iconColor: MekaarColors.info,
                title: 'Terakhir Dilihat & Online',
                valueText: ref.watch(lastSeenPrivacyProvider).label,
                onTap: () => _showLastSeenSheet(context, ref),
              ),
              SettingsSwitchTile(
                icon: SolarIconsOutline.checkCircle,
                iconColor: MekaarColors.lime,
                title: 'Bukti Baca (Read Receipt)',
                value: ref.watch(readReceiptsProvider),
                onChanged: (value) =>
                    ref.read(readReceiptsProvider.notifier).setEnabled(value),
              ),
              SettingsNavTile(
                icon: SolarIconsOutline.shieldUser,
                title: 'Proteksi Undangan Chat',
                valueText: ref.watch(chatInvitationModeProvider) == 'approved_only'
                    ? 'Disetujui'
                    : 'Semua',
                onTap: () => _showChatInvitationModeSheet(context, ref),
              ),
              SettingsNavTile(
                icon: SolarIconsOutline.radar2,
                iconColor: MekaarColors.guardianTeal,
                title: 'Teman Sekitar (Proximity)',
                valueText: ref.watch(nearbyFriendsProvider).isEnabled
                    ? (ref.watch(nearbyFriendsProvider).visibilityMode == 'everyone'
                        ? 'Semua'
                        : 'Kontak')
                    : 'Nonaktif',
                onTap: () => _showNearbyFriendsPrivacySheet(context, ref),
              ),
              SettingsNavTile(
                icon: SolarIconsOutline.mapPoint,
                iconColor: MekaarColors.guardianTeal,
                title: 'Mekaar Beacon (Auto Check-In)',
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
        const SettingsSectionHeader(title: 'Keamanan'),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: MekaarColors.guardianTeal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: MekaarColors.guardianTeal.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: const Row(
            children: [
              Icon(
                SolarIconsBold.shieldCheck,
                color: MekaarColors.guardianTeal,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mekaar Aegis Protocol',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: MekaarColors.guardianTeal,
                      ),
                    ),
                    Text(
                      'Enkripsi ujung-ke-ujung & proteksi privasi aktif',
                      style: TextStyle(
                        fontSize: 11,
                        color: MekaarColors.guardianTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingsSwitchTile(
                icon: SolarIconsOutline.lock,
                iconColor: MekaarColors.yellow,
                title: 'Kunci PIN Aplikasi',
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
                  iconColor: MekaarColors.sosCoral,
                  title: 'PIN Paksaan (Duress)',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.duressPin),
                ),
                SettingsNavTile(
                  icon: SolarIconsOutline.shieldKeyhole,
                  iconColor: MekaarColors.guardianTeal,
                  title: 'Verifikasi 2 Langkah',
                  valueText: ref.watch(twoFaProvider) ? 'Aktif' : 'Nonaktif',
                  onTap: () => _handleTwoFactor(context, ref),
                ),
                SettingsNavTile(
                  icon: SolarIconsOutline.smartphone,
                  iconColor: MekaarColors.brandPrimary,
                  title: 'Perangkat Terhubung',
                  onTap: () => Navigator.pushNamed(
                      context, AppRoutes.connectedDevices),
                ),
                SettingsNavTile(
                  icon: SolarIconsOutline.billList,
                  iconColor: MekaarColors.sosRed,
                  title: 'Riwayat SOS',
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
        const SettingsSectionHeader(title: 'Notifikasi'),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SettingsNavTile(
            icon: SolarIconsOutline.bell,
            title: 'Nada & Suara',
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

    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final hapticsEnabled = prefsAsync.value?.hapticsEnabled ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Sistem'),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SettingsSwitchTile(
                icon: SolarIconsOutline.smartphoneVibration,
                iconColor: MekaarColors.purpleLight,
                title: 'Getaran (Haptics)',
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
                  iconColor: MekaarColors.guardianTeal,
                  title: 'Izin Guardian Alarm',
                  value: ref.watch(allowGuardianAlarmProvider),
                  onChanged: (value) =>
                      ref.read(allowGuardianAlarmProvider.notifier).setEnabled(value),
                ),
                SettingsNavTile(
                  icon: SolarIconsOutline.gps,
                    title: 'Temukan Ponsel Saya',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.deviceLost),
                ),
                SettingsNavTile(
                  icon: SolarIconsOutline.userBlock,
                  iconColor: MekaarColors.sosCoral,
                  title: 'Daftar Blokir',
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
  // SECTION 7: Informasi & Bantuan
  // ─────────────────────────────────────────────────
  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const SettingsSectionHeader(title: 'Informasi'),
        CustomCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SettingsNavTile(
            icon: SolarIconsOutline.infoCircle,
            title: 'Tentang MEKAAR',
            subtitle: 'Versi aplikasi & kebijakan privasi',
            onTap: () => Navigator.pushNamed(context, AppRoutes.about),
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

                    // ── 1. Akun (Snippet Profil) ──
                    _buildAccountSection(context, ref),

                    // ── 2. Tampilan ──
                    _buildDisplaySection(context, ref),

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

                    // ── 7. Informasi ──
                    _buildAboutSection(context),

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
                    color: selected ? MekaarColors.primaryOf(context) : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3, style: const TextStyle(fontSize: 12)),
                  trailing: selected
                      ? Icon(MekaarIcons.check, color: MekaarColors.primaryOf(context))
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
  void _showNearbyFriendsPrivacySheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final state = ref.watch(nearbyFriendsProvider);
        final isEnabled = state.isEnabled;
        final currentMode = state.visibilityMode;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Teman Sekitar & Proksimitas',
                style: MekaarTypography.headingSM,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Bagikan radius jarak kasar dengan kontak untuk mengetahui siapa yang sedang berada di dekat Anda.',
                  style: MekaarTypography.bodySM,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                secondary: Icon(
                  SolarIconsOutline.radar2,
                  color: isEnabled ? MekaarColors.guardianTeal : null,
                ),
                title: const Text('Aktifkan Teman Sekitar'),
                subtitle: const Text(
                  'Hanya membagikan radius kasar (<500 m, 500 m–2 km, satu kota)',
                  style: TextStyle(fontSize: 12),
                ),
                value: isEnabled,
                onChanged: (value) async {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  final success = await ref
                      .read(nearbyFriendsProvider.notifier)
                      .toggleSharing(value);
                  if (!success && ctx.mounted) {
                    MekaarSnackbar.error(
                      ctx,
                      'Izin lokasi diperlukan untuk mengaktifkan fitur ini.',
                    );
                  }
                },
              ),
              if (isEnabled) ...[
                const Divider(),
                ListTile(
                  leading: Icon(
                    currentMode == 'contacts_only'
                        ? SolarIconsBold.checkCircle
                        : SolarIconsOutline.usersGroupRounded,
                    color: currentMode == 'contacts_only'
                        ? MekaarColors.guardianTeal
                        : null,
                  ),
                  title: const Text('Hanya Kontak Saya'),
                  subtitle: const Text(
                    'Hanya kontak yang saling menyimpan yang dapat melihat jarak',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: currentMode == 'contacts_only'
                      ? const Icon(MekaarIcons.check,
                          color: MekaarColors.guardianTeal)
                      : null,
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    ref
                        .read(nearbyFriendsProvider.notifier)
                        .setVisibilityMode('contacts_only');
                  },
                ),
                ListTile(
                  leading: Icon(
                    currentMode == 'everyone'
                        ? SolarIconsBold.checkCircle
                        : SolarIconsOutline.globus,
                    color: currentMode == 'everyone'
                        ? MekaarColors.guardianTeal
                        : null,
                  ),
                  title: const Text('Semua Pengguna di Sekitar'),
                  subtitle: const Text(
                    'Termasuk pengguna non-kontak yang juga mengaktifkan fitur ini',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: currentMode == 'everyone'
                      ? const Icon(MekaarIcons.check,
                          color: MekaarColors.guardianTeal)
                      : null,
                  onTap: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    ref
                        .read(nearbyFriendsProvider.notifier)
                        .setVisibilityMode('everyone');
                  },
                ),
              ],
              const SizedBox(height: 16),
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
                    color: selected ? MekaarColors.primaryOf(context) : null,
                  ),
                  title: Text(privacy.label),
                  trailing: selected
                      ? Icon(MekaarIcons.check, color: MekaarColors.primaryOf(context))
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


