import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/mekaar_tab_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/user_model.dart';
import '../../settings/providers/privacy_provider.dart';
import '../../settings/providers/auto_delete_provider.dart';
import '../../settings/providers/two_fa_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
                    // Theme selector
                    _buildSectionHeader('Tampilan'),
                    _ThemeSelector(
                      current: ref.watch(themeModeProvider),
                      onChanged: (mode) =>
                          ref.read(themeModeProvider.notifier).setMode(mode),
                    ),
                    Divider(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                      height: 32,
                    ),

                    // Menu Items List
                    _buildSectionHeader('Keamanan & Darurat'),
                    if (!wasDuress)
                      _buildMenuItem(
                        context,
                        icon: SolarIconsOutline.billList,
                        title: 'Riwayat SOS',
                        subtitle:
                            'Chat tetap privat; hanya insiden SOS yang dicatat',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.logs),
                      ),
                    _buildMenuItem(
                      context,
                      icon: SolarIconsOutline.gps,
                      title: 'Temukan Ponsel Saya',
                      subtitle: 'Mode perangkat hilang (self-guardian)',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.deviceLost),
                    ),
                    SwitchListTile(
                      activeThumbColor: MekaarColors.softCoral,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                      secondary: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? MekaarColors.cardDark
                              : MekaarColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          SolarIconsOutline.lock,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? MekaarColors.textSecondary
                              : Colors.black54,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Kunci PIN Aplikasi',
                        style: MekaarTypography.labelLG.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Minta PIN keamanan saat membuka aplikasi',
                        style: MekaarTypography.bodySM,
                      ),
                      value: ref.watch(pinLockEnabledProvider),
                      onChanged: (bool value) async {
                        try {
                          await ref
                              .read(pinLockEnabledProvider.notifier)
                              .toggle(value);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pengaturan kunci PIN gagal disimpan. Coba lagi.',
                                ),
                                backgroundColor: MekaarColors.sosRed,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    if (!wasDuress) ...[
                      Divider(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                        height: 32,
                      ),
                      _buildSectionHeader('Privasi'),
                      SwitchListTile(
                        activeThumbColor: MekaarColors.softCoral,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? MekaarColors.cardDark
                                : MekaarColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            SolarIconsOutline.screenShare,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Proteksi layar',
                          style: MekaarTypography.labelLG.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Jadikan proteksi sebagai default untuk ruang baru. Mencegah screenshot dan perekaman di Android; menyamarkan konten saat perekaman terdeteksi di iOS.',
                          style: MekaarTypography.bodySM,
                        ),
                        value: ref.watch(screenshotBlockProvider),
                        onChanged: (bool value) {
                          ref
                              .read(screenshotBlockProvider.notifier)
                              .toggle(value);
                        },
                      ),
                      SwitchListTile(
                        activeThumbColor: MekaarColors.softCoral,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? MekaarColors.cardDark
                                : MekaarColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            SolarIconsOutline.eye,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Sembunyikan Notifikasi Darurat',
                          style: MekaarTypography.labelLG.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Samarkan teks SOS/Alarm di layar kunci agar pelaku tidak curiga',
                          style: MekaarTypography.bodySM,
                        ),
                        value: ref.watch(notificationMaskingProvider),
                        onChanged: (bool value) {
                          ref
                              .read(notificationMaskingProvider.notifier)
                              .setEnabled(value);
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: SolarIconsOutline.user,
                        title: 'Terakhir Dilihat & Online',
                        subtitle: ref.watch(lastSeenPrivacyProvider).label,
                        onTap: () => _showLastSeenSheet(context, ref),
                      ),
                      SwitchListTile(
                        activeThumbColor: MekaarColors.softCoral,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 0,
                        ),
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? MekaarColors.cardDark
                                : MekaarColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            SolarIconsOutline.eye,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Bukti Baca (Read Receipt)',
                          style: MekaarTypography.labelLG.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Izinkan orang lain melihat pesan Anda telah dibaca',
                          style: MekaarTypography.bodySM,
                        ),
                        value: ref.watch(readReceiptsProvider),
                        onChanged: (bool value) {
                          ref
                              .read(readReceiptsProvider.notifier)
                              .setEnabled(value);
                        },
                      ),
                      _buildMenuItem(
                        context,
                        icon: SolarIconsOutline.history,
                        title: 'Pesan Menghilang',
                        subtitle: _autoDeleteLabel(
                          ref.watch(autoDeleteDefaultProvider),
                        ),
                        onTap: () => _showAutoDeleteSheet(context, ref),
                      ),
                      _buildMenuItem(
                        context,
                        icon: SolarIconsOutline.shieldKeyhole,
                        title: 'Verifikasi 2 Langkah',
                        subtitle: ref.watch(twoFaProvider)
                            ? 'Aktif · kode dari authenticator diperlukan saat login'
                            : 'Nonaktif · aktifkan untuk keamanan ekstra',
                        onTap: () => _handleTwoFactor(context, ref),
                      ),
                      _buildMenuItem(
                        context,
                        icon: SolarIconsOutline.userBlock,
                        title: 'Daftar Blokir',
                        subtitle: 'Kelola pengguna yang diblokir',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.blockedList),
                      ),
                      _buildMenuItem(
                        context,
                        icon: SolarIconsOutline.lockKeyhole,
                        title: 'PIN Paksaan (Duress)',
                        subtitle:
                            'PIN terpisah yang diam-diam memicu SOS saat dipaksa',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.duressPin),
                      ),
                    ],

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

  String _autoDeleteLabel(int hours) {
    if (hours <= 0) return 'Mati';
    if (hours == 1) return '1 Jam';
    if (hours == 24) return '1 Hari';
    if (hours == 168) return '7 Hari';
    return '$hours Jam';
  }

  void _showAutoDeleteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = ref.watch(autoDeleteDefaultProvider);
        final options = [
          (0, 'Mati', 'Pesan disimpan selamanya'),
          (1, '1 Jam', 'Pesan otomatis terhapus setelah 1 jam'),
          (24, '1 Hari', 'Pesan otomatis terhapus setelah 1 hari'),
          (168, '7 Hari', 'Pesan otomatis terhapus setelah 7 hari'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('Pesan Menghilang', style: MekaarTypography.headingSM),
              const SizedBox(height: 8),
              Text(
                'Atur berapa lama pesan otomatis terhapus secara default.',
                style: MekaarTypography.bodySM,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final selected = opt.$1 == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? SolarIconsBold.history
                        : SolarIconsOutline.history,
                    color: selected ? MekaarColors.softCoral : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3),
                  trailing: selected
                      ? const Icon(Icons.check, color: MekaarColors.softCoral)
                      : null,
                  onTap: () {
                    ref
                        .read(autoDeleteDefaultProvider.notifier)
                        .setHours(opt.$1);
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verifikasi 2 Langkah dimatikan.'),
                backgroundColor: MekaarColors.success,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
                ),
                backgroundColor: MekaarColors.sosRed,
              ),
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

  void _showLastSeenSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  Widget _buildSectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Text(label.toUpperCase(), style: MekaarTypography.overline),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? MekaarColors.cardDark : MekaarColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? MekaarColors.sosRed
              : (isDark ? MekaarColors.textSecondary : Colors.black54),
          size: 20,
        ),
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
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: MekaarColors.textMuted,
      ),
      onTap: onTap,
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.current, required this.onChanged});

  static const double z = 24.0; // Icon size (z)
  static const double activeSize = z + 16.0; // Active container (z + 16 = 40)
  static const double barHeight = z + 32.0; // Height (z + 32 = 56)
  static const double barWidth = 3.0 * (z + 32.0); // Total width (3 * 56 = 168)

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
              final inactiveColor = isDark
                  ? MekaarColors.textMuted
                  : Colors.black45;

              return Semantics(
                button: true,
                selected: selected,
                label: 'Tema ${opt.$3.toLowerCase()}',
                child: InkResponse(
                  onTap: () => onChanged(opt.$1),
                  radius: barHeight / 2,
                  child: SizedBox(
                    width: z + 32.0, // Exactly 56px width per tab
                    height: barHeight, // Exactly 56px height per tab
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
                                    color: MekaarColors.softCoral.withValues(
                                      alpha: 0.3,
                                    ),
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
