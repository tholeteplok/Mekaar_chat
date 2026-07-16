import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Pengaturan'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 16),
            // Theme selector
            _buildSectionHeader('Tampilan'),
            _ThemeSelector(
              current: ref.watch(themeModeProvider),
              onChanged: (mode) =>
                  ref.read(themeModeProvider.notifier).setMode(mode),
            ),
            const Divider(color: MekaarColors.borderLight, height: 32),
            // Menu Items List
            _buildSectionHeader('Keamanan & Darurat'),
            _buildMenuItem(
              context,
              icon: Icons.history_edu_outlined,
              title: 'Log Sistem',
              subtitle: 'Riwayat aktivitas keamanan permanen Anda',
              onTap: () => Navigator.pushNamed(context, AppRoutes.logs),
            ),
            _buildMenuItem(
              context,
              icon: Icons.find_in_page_outlined,
              title: 'Temukan Ponsel Saya',
              subtitle: 'Mode perangkat hilang (self-guardian)',
              onTap: () => Navigator.pushNamed(context, AppRoutes.deviceLost),
            ),
            SwitchListTile(
              activeThumbColor: MekaarColors.softCoral,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
                  Icons.lock_outline,
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
              onChanged: (bool value) {
                ref.read(pinLockEnabledProvider.notifier).toggle(value);
              },
            ),
            const Divider(color: MekaarColors.borderLight, height: 32),
            _buildSectionHeader('Privasi'),
            SwitchListTile(
              activeThumbColor: MekaarColors.softCoral,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
                  Icons.screenshot_outlined,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white70 
                      : Colors.black54,
                  size: 20,
                ),
              ),
              title: Text(
                'Blokir Screenshot',
                style: MekaarTypography.labelLG.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Cegah tangkapan & rekaman layar untuk privasi obrolan Anda',
                style: MekaarTypography.bodySM,
              ),
              value: ref.watch(screenshotBlockProvider),
              onChanged: (bool value) {
                ref.read(screenshotBlockProvider.notifier).toggle(value);
              },
            ),
            const Divider(color: MekaarColors.borderLight, height: 32),
            _buildSectionHeader('Akun'),
            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: 'Profil Saya',
              subtitle: 'Kelola username, foto, dan PIN keamanan',
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
            ),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: 'Keluar',
              subtitle: 'Hapus sesi login dari perangkat ini',
              isDestructive: true,
              onTap: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Keluar Aplikasi?'),
                    content: const Text('PIN keamanan lokal akan dihapus demi privasi.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context); // close dialog
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            );
                          }
                        },
                        child: const Text('Keluar', style: TextStyle(color: MekaarColors.sosRed)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Text(
          label.toUpperCase(),
          style: MekaarTypography.overline,
        ),
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
          color: isDestructive ? MekaarColors.sosRed : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: MekaarTypography.bodySM,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: MekaarColors.textMuted),
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
    
    final navBgColor = isDark ? MekaarColors.cardDark : MekaarColors.surface2;
    final navBorderColor = isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : Colors.black.withValues(alpha: 0.08);

    const options = [
      (ThemeMode.system, Icons.brightness_auto_outlined),
      (ThemeMode.light, Icons.light_mode_outlined),
      (ThemeMode.dark, Icons.dark_mode_outlined),
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
              final inactiveColor = isDark ? MekaarColors.textMuted : Colors.black45;

              return GestureDetector(
                onTap: () => onChanged(opt.$1),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: z + 32.0, // Exactly 56px width per tab
                  height: barHeight, // Exactly 56px height per tab
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: selected ? activeSize : z,
                      height: selected ? activeSize : z,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? MekaarColors.softCoral : Colors.transparent,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: MekaarColors.softCoral.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
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
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
