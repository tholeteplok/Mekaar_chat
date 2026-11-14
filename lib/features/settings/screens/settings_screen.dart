import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/strings.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auto_lock_provider.dart';
import '../../guardian/providers/guardian_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../../data/models/user_model.dart';
import '../providers/privacy_provider.dart';
import '../providers/two_fa_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../../chat/providers/nearby_friends_provider.dart';
import '../../chat/utils/nearby_permission_helper.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/account_snippet_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // ─────────────────────────────────────────────────
  // SECTION 1: Tampilan — selector tema & font
  // ─────────────────────────────────────────────────
  Widget _buildDisplaySection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Tampilan'),
        SettingsNavTile(
          icon: SolarIconsOutline.palette2,
          title: 'Tampilan Aplikasi',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.themeSettings),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsOutline.palette,
          title: 'Tema Ruang Obrolan',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.chatThemeSettings),
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
        SettingsSwitchTile(
          icon: SolarIconsOutline.screenShare,
          iconColor: MekaarColors.guardianTeal,
          title: 'Proteksi Privasi Layar',
          value: ref.watch(screenshotBlockProvider),
          onChanged: (value) =>
              ref.read(screenshotBlockProvider.notifier).toggle(value),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsOutline.user,
          title: 'Terakhir Dilihat & Online',
          valueText: ref.watch(lastSeenPrivacyProvider).label,
          onTap: () => _showLastSeenSheet(context, ref),
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: SolarIconsOutline.checkCircle,
          title: 'Bukti Baca Pesan',
          value: ref.watch(readReceiptsProvider),
          onChanged: (value) =>
              ref.read(readReceiptsProvider.notifier).setEnabled(value),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsOutline.userCheck,
          title: 'Proteksi Undangan Chat',
          valueText:
              ref.watch(chatInvitationModeProvider) == 'approved_only'
              ? 'Disetujui'
              : 'Semua',
          onTap: () => _showChatInvitationModeSheet(context, ref),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsOutline.radar2,
          iconColor: MekaarColors.guardianTeal,
          title: 'Teman Sekitar',
          valueText: ref.watch(nearbyFriendsProvider).isEnabled
              ? (ref.watch(nearbyFriendsProvider).visibilityMode ==
                        'everyone'
                    ? 'Semua'
                    : 'Kontak')
              : 'Nonaktif',
          onTap: () => _showNearbyFriendsPrivacySheet(context, ref),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsOutline.mapPoint,
          iconColor: MekaarColors.guardianTeal,
          title: 'Auto Check-In',
          onTap: () => Navigator.pushNamed(context, AppRoutes.tripList),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsBold.shieldKeyhole,
          iconColor: MekaarColors.guardianTeal,
          title: 'Privasi Lanjutan',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.advancedPrivacySettings,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 4: Keamanan
  // ─────────────────────────────────────────────────
  Widget _buildSecuritySection(BuildContext context, WidgetRef ref) {
    final isDecoy = ref.watch(authProvider).isDecoyActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Keamanan'),
        SettingsNavTile(
          icon: SolarIconsOutline.lockKeyhole,
          title: isDecoy
              ? 'PIN Keamanan Aplikasi'
              : 'Manajemen PIN Keamanan',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.pinManagement),
        ),
        const SettingsDivider(),
        SettingsNavTile(
          icon: SolarIconsOutline.clockCircle,
          title: 'Kunci Otomatis',
          valueText: ref.watch(autoLockTimeoutProvider).label,
          onTap: () => _showAutoLockBottomSheet(context, ref),
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: SolarIconsOutline.shieldWarning,
          iconColor: MekaarColors.sosCoral,
          title: 'Fitur Darurat SOS',
          value: ref.watch(sosFeatureEnabledProvider),
          onChanged: (val) => _handleSosToggle(context, ref, val),
        ),
        if (!isDecoy) ...[
          const SettingsDivider(),
          SettingsNavTile(
            icon: SolarIconsOutline.shieldKeyhole,
            iconColor: MekaarColors.guardianTeal,
            title: 'Verifikasi 2 Langkah (2FA)',
            valueText: ref.watch(twoFaProvider) ? 'Aktif' : 'Nonaktif',
            onTap: () => _handleTwoFactor(context, ref),
          ),
          const SettingsDivider(),
          SettingsNavTile(
            icon: SolarIconsOutline.smartphone,
            title: 'Perangkat Terhubung',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.connectedDevices),
          ),
          if (ref.watch(sosFeatureEnabledProvider)) ...[
            const SettingsDivider(),
            SettingsNavTile(
              icon: SolarIconsOutline.billList,
              iconColor: MekaarColors.sosRed,
              title: 'Riwayat SOS',
              onTap: () => Navigator.pushNamed(context, AppRoutes.logs),
            ),
            const SettingsDivider(),
            SettingsNavTile(
              icon: SolarIconsOutline.playCircle,
              iconColor: MekaarColors.warnAmber,
              title: 'Latihan SOS (Simulasi)',
              onTap: () => Navigator.pushNamed(context, AppRoutes.sosDrill),
            ),
          ],
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 5: Notifikasi — Nada & Suara
  // ─────────────────────────────────────────────────
  Widget _buildNotificationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Notifikasi'),
        SettingsNavTile(
          icon: SolarIconsOutline.bell,
          title: 'Nada & Suara',
          onTap: () => Navigator.pushNamed(context, AppRoutes.soundPicker),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 6: Sistem — haptic global + guardian & darurat
  // ─────────────────────────────────────────────────
  Widget _buildSystemSection(BuildContext context, WidgetRef ref) {
    final isDecoy = ref.watch(authProvider).isDecoyActive;

    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final hapticsEnabled = prefsAsync.value?.hapticsEnabled ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Sistem'),
        SettingsSwitchTile(
          icon: SolarIconsOutline.smartphoneVibration,
          title: 'Getaran (Haptics)',
          value: hapticsEnabled,
          onChanged: prefsAsync.hasValue
              ? (value) => ref
                    .read(notificationPreferencesProvider.notifier)
                    .toggleHaptics(value)
              : null,
        ),
        if (!isDecoy) ...[
          const SettingsDivider(),
          SettingsSwitchTile(
            icon: SolarIconsOutline.volumeLoud,
            iconColor: MekaarColors.guardianTeal,
            title: 'Izin Guardian Alarm',
            value: ref.watch(allowGuardianAlarmProvider),
            onChanged: (value) => ref
                .read(allowGuardianAlarmProvider.notifier)
                .setEnabled(value),
          ),
          const SettingsDivider(),
          SettingsNavTile(
            icon: SolarIconsOutline.gps,
            title: 'Temukan Ponsel Saya',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.deviceLost),
          ),
          const SettingsDivider(),
          SettingsNavTile(
            icon: SolarIconsOutline.userBlock,
            iconColor: MekaarColors.sosCoral,
            title: 'Daftar Blokir',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.blockedList),
          ),
        ],
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
        const SettingsSectionHeader(title: 'Informasi'),
        SettingsNavTile(
          icon: SolarIconsOutline.infoCircle,
          title: 'Tentang Mekaar',
          onTap: () => Navigator.pushNamed(context, AppRoutes.about),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // BUILD UTAMA
  // ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDecoy = ref.watch(authProvider).isDecoyActive;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const MekaarTabHeader(title: 'Pengaturan'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: Column(
                  children: [

                    // ── 1. Akun (Snippet Profil) ──
                    _buildAccountSection(context, ref),

                    // ── 2. Tampilan ──
                    _buildDisplaySection(context, ref),

                    // ── 3. Privasi (tersembunyi saat decoy/duress) ──
                    if (!isDecoy) ...[_buildPrivacySection(context, ref)],

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
  // BOTTOM SHEET: Kunci Otomatis (Auto-Lock Timeout)
  // ─────────────────────────────────────────────────
  void _showAutoLockBottomSheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final current = sheetRef.watch(autoLockTimeoutProvider);
            final options = AutoLockTimeout.values;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Kunci Otomatis',
                    style: MekaarTypography.headingSM,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Tentukan kapan aplikasi meminta PIN kembali setelah ditinggalkan.',
                      style: MekaarTypography.bodySM,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...options.map((opt) {
                    final selected = opt == current;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? SolarIconsBold.checkCircle
                            : SolarIconsOutline.clockCircle,
                        color: selected
                            ? MekaarColors.primaryOf(context)
                            : null,
                      ),
                      title: Text(
                        opt.label,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          color: selected
                              ? MekaarColors.primaryOf(context)
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        opt.description,
                        style: MekaarTypography.caption,
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check,
                              color: MekaarColors.primaryOf(context),
                            )
                          : null,
                      onTap: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        sheetRef
                            .read(autoLockTimeoutProvider.notifier)
                            .setTimeout(opt);
                        Navigator.pop(ctx);
                        MekaarSnackbar.success(
                          context,
                          'Kunci otomatis diatur: ${opt.label}',
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  void _showChatInvitationModeSheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final current = sheetRef.watch(chatInvitationModeProvider);
            final options = [
              (
                'approved_only',
                'Hanya yang Disetujui',
                'Pengguna baru harus mengirim permintaan chat terlebih dahulu',
              ),
              (
                'everyone',
                'Semua Orang',
                'Siapapun dapat langsung mengirim pesan kepada Anda',
              ),
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
                        color: selected
                            ? MekaarColors.primaryOf(context)
                            : null,
                      ),
                      title: Text(opt.$2),
                      subtitle: Text(
                        opt.$3,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: selected
                          ? Icon(
                              MekaarIcons.check,
                              color: MekaarColors.primaryOf(context),
                            )
                          : null,
                      onTap: () {
                        sheetRef
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
      },
    );
  }

  // ─────────────────────────────────────────────────
  void _showNearbyFriendsPrivacySheet(BuildContext context, WidgetRef ref) {
    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final state = sheetRef.watch(nearbyFriendsProvider);
            final isEnabled = state.isEnabled;
            final currentMode = state.visibilityMode;
            final isProcessing = state.isLoading;
            final showPreview = sheetRef.watch(nearbyPreviewPreferenceProvider);

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
                    onChanged: isProcessing
                        ? null
                        : (value) async {
                            HapticService.trigger(MekaarHapticIntent.selection);
                            if (!value) {
                              await sheetRef
                                  .read(nearbyFriendsProvider.notifier)
                                  .toggleSharing(false);
                            } else {
                              await NearbyPermissionHelper.activateWithPermissionCheck(
                                ctx,
                                sheetRef,
                              );
                            }
                          },
                  ),
                  const Divider(),
                  SwitchListTile(
                    secondary: Icon(
                      showPreview
                          ? SolarIconsOutline.eye
                          : SolarIconsOutline.eyeClosed,
                      color: showPreview ? MekaarColors.guardianTeal : null,
                    ),
                    title: const Text('Preview di Tab Kontak'),
                    subtitle: const Text(
                      'Tampilkan kartu radar di atas daftar kontak saat fitur belum diaktifkan',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: showPreview,
                    onChanged: (value) {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      sheetRef
                          .read(nearbyPreviewPreferenceProvider.notifier)
                          .setVisible(value);
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
                          ? const Icon(
                              MekaarIcons.check,
                              color: MekaarColors.guardianTeal,
                            )
                          : null,
                      onTap: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        sheetRef
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
                          ? const Icon(
                              MekaarIcons.check,
                              color: MekaarColors.guardianTeal,
                            )
                          : null,
                      onTap: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        sheetRef
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
        return Consumer(
          builder: (context, sheetRef, _) {
            final current = sheetRef.watch(lastSeenPrivacyProvider);
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
                        color: selected
                            ? MekaarColors.primaryOf(context)
                            : null,
                      ),
                      title: Text(privacy.label),
                      trailing: selected
                          ? Icon(
                              MekaarIcons.check,
                              color: MekaarColors.primaryOf(context),
                            )
                          : null,
                      onTap: () {
                        sheetRef
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
              onPressed: () =>
                  Navigator.pop(ctx, passwordController.text.trim()),
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

  // ─────────────────────────────────────────────────
  // Handler & Wizard Fitur Darurat SOS Terpusat
  // ─────────────────────────────────────────────────
  Future<void> _handleSosToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    if (!enable) {
      // 1. Deaktivasi SOS -> Blocking modal konfirmasi dampak keselamatan
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => MekaarDialog(
          icon: const Icon(
            SolarIconsBold.shieldCross,
            color: MekaarColors.warnAmber,
            size: 28,
          ),
          title: 'Nonaktifkan Fitur Darurat SOS?',
          message:
              'Tombol darurat SOS di layar obrolan dan layar kunci akan disembunyikan. '
              'PIN Darurat (Duress PIN) akan dinonaktifkan, dan siaga sinyal GPS ke Guardian '
              'tidak akan dapat disiarkan jika Anda dalam bahaya.',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Tetap Aktif'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.sosRed.withValues(alpha: 0.15),
                foregroundColor: MekaarColors.sosRed,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(sosFeatureEnabledProvider.notifier).setEnabled(false);
        if (context.mounted) {
          MekaarSnackbar.info(
            context,
            'Fitur Darurat SOS dinonaktifkan. Mode Obrolan Privat Murni aktif.',
          );
        }
      }
    } else {
      // 2. Aktivasi SOS -> Cek kelengkapan Guardian & Duress PIN
      await ref.read(sosFeatureEnabledProvider.notifier).setEnabled(true);

      final hasGuardians =
          activeGuardiansOf(ref.read(guardianProvider)).isNotEmpty;
      final isDuressSet =
          await ref.read(authProvider.notifier).isDuressEnabled();

      if (hasGuardians && isDuressSet) {
        if (context.mounted) {
          MekaarSnackbar.success(
            context,
            'Fitur Darurat SOS aktif. Guardian & PIN Darurat siap sedia.',
          );
        }
        return;
      }

      if (context.mounted) {
        _showSafetySetupWizard(
          context,
          ref,
          hasGuardians: hasGuardians,
          isDuressSet: isDuressSet,
        );
      }
    }
  }

  void _showSafetySetupWizard(
    BuildContext context,
    WidgetRef ref, {
    required bool hasGuardians,
    required bool isDuressSet,
  }) {
    MekaarBottomSheet.show(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MekaarColors.sosCoral.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      SolarIconsBold.shieldWarning,
                      color: MekaarColors.sosCoral,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lengkapi Proteksi SOS',
                          style: MekaarTypography.headingMD.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fitur SOS telah aktif. Selesaikan konfigurasi agar perlindungan maksimal.',
                          style: MekaarTypography.caption.copyWith(
                            color: MekaarColors.textMutedOf(sheetContext),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Item 1: Guardian
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      SolarIconsBold.shieldUser,
                      color: hasGuardians
                          ? MekaarColors.guardianTeal
                          : MekaarColors.warnAmber,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kontak Guardian',
                            style: MekaarTypography.bodyMD.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasGuardians
                                ? 'Guardian aktif terhubung'
                                : 'Belum ada Guardian yang menerima sinyal SOS',
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(sheetContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasGuardians)
                      const Icon(
                        SolarIconsBold.checkCircle,
                        color: MekaarColors.lime,
                        size: 24,
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.guardianTeal,
                          foregroundColor: MekaarColors.textOnTeal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(MekaarRadius.md),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(context, AppRoutes.guardianAdd);
                        },
                        child: const Text('Tambah'),
                      ),
                  ],
                ),
              ),
              Divider(
                height: 16,
                thickness: 0.8,
                indent: 42,
                color: MekaarColors.borderOf(context).withValues(alpha: 0.35),
              ),

              // Item 2: Duress PIN
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      SolarIconsBold.shieldKeyhole,
                      color: isDuressSet
                          ? MekaarColors.brandPrimary
                          : MekaarColors.sosCoral,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MekaarCopy.quickResetPinTitle,
                            style: MekaarTypography.bodyMD.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDuressSet
                                ? 'Kode telah aktif'
                                : MekaarCopy.quickResetPinSubtitle,
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(sheetContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDuressSet)
                      const Icon(
                        SolarIconsBold.checkCircle,
                        color: MekaarColors.lime,
                        size: 24,
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              MekaarColors.surface2Of(sheetContext),
                          foregroundColor:
                              MekaarColors.textPrimaryOf(sheetContext),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(MekaarRadius.md),
                            side: BorderSide(
                              color: MekaarColors.borderOf(sheetContext),
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.pinManagement,
                          );
                        },
                        child: const Text('Atur PIN'),
                      ),
                  ],
                ),
              ),

              // Button Selesai
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Selesai'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
