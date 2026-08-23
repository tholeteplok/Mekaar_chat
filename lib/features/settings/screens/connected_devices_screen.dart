import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../providers/connected_devices_provider.dart';
import '../widgets/settings_tiles.dart';
import '../../../data/models/user_device.dart';

/// Layar daftar perangkat terhubung (mirip "Sesi Aktif" di Telegram).
///
/// Menampilkan perangkat saat ini di atas dengan badge "Perangkat Ini",
/// dan daftar perangkat lain dengan opsi revoke (keluar) per-perangkat.
class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() =>
      _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState
    extends ConsumerState<ConnectedDevicesScreen> {
  @override
  void initState() {
    super.initState();
    // Muat daftar perangkat saat layar dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(connectedDevicesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectedDevicesProvider);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Perangkat Terhubung'),
            Expanded(child: _buildBody(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ConnectedDevicesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MikaIllustration(
              pose: MikaPose.neutral,
              size: 110,
              semanticLabel: 'Tidak ada perangkat terdaftar',
            ),
            const SizedBox(height: MekaarSpacing.lg),
            Text(
              'Belum Ada Perangkat',
              style: MekaarTypography.headingMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: MekaarSpacing.sm),
            Padding(
              padding: MekaarSpacing.screen,
              child: Text(
                'Perangkat akan muncul di sini setelah Anda login dan mengizinkan notifikasi.',
                textAlign: TextAlign.center,
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () => ref.read(connectedDevicesProvider.notifier).load(),
      child: ListView(
        padding: MekaarSpacing.screen.copyWith(top: MekaarSpacing.md),
        children: [
          // ── Perangkat Saat Ini ──
          if (state.currentDevice != null) ...[
            const _SectionLabel(label: 'Perangkat Ini'),
            const SizedBox(height: MekaarSpacing.xs),
            _DeviceCard(
              device: state.currentDevice!,
              isCurrent: true,
              onRevoke: null, // Tidak bisa revoke perangkat sendiri
            ),
            const SizedBox(height: MekaarSpacing.lg),
          ],

          // ── Perangkat Lain ──
          if (state.otherDevices.isNotEmpty) ...[
            const _SectionLabel(label: 'Perangkat Lain'),
            const SizedBox(height: MekaarSpacing.xs),
            ...state.otherDevices.map(
              (device) => Padding(
                padding: const EdgeInsets.only(bottom: MekaarSpacing.xs),
                child: _DeviceCard(
                  device: device,
                  isCurrent: false,
                  onRevoke: () => _confirmRevoke(device),
                ),
              ),
            ),
            const SizedBox(height: MekaarSpacing.md),
            // Tombol "Keluar dari Semua Perangkat Lain"
            _RevokeAllButton(
              count: state.otherDevices.length,
              onTap: () => _confirmRevokeAll(state.otherDevices.length),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRevoke(UserDevice device) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        icon: const Icon(
          SolarIconsBold.logout,
          color: MekaarColors.sosRed,
          size: 28,
        ),
        title: 'Keluarkan & Logout?',
        message:
            'Sesi pada "${device.deviceLabel ?? device.platform}" akan diputuskan dan data akun akan dikeluarkan.\n\n⚠️ Jika perangkat hilang atau dicuri, gunakan menu "Temukan Ponsel Saya" terlebih dahulu untuk mengunci layar atau melacak lokasi sebelum mengeluarkan perangkat.',
        isDestructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: MekaarColors.textMutedOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluarkan & Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(connectedDevicesProvider.notifier)
          .revokeDevice(device.deviceId);
      if (!mounted) return;
      MekaarSnackbar.success(
        context,
        'Perangkat berhasil dikeluarkan & logout dikirim.',
      );
    }
  }

  Future<void> _confirmRevokeAll(int count) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        icon: const Icon(
          SolarIconsBold.logout,
          color: MekaarColors.sosRed,
          size: 28,
        ),
        title: 'Keluarkan Semua Perangkat Lain?',
        message:
            '$count perangkat lain akan dikeluarkan dan sesi login-nya akan diputuskan secara remote.\n\n⚠️ Perangkat yang dikeluarkan tidak akan bisa lagi menerima perintah pelacakan jarak jauh.',
        isDestructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: MekaarColors.textMutedOf(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluarkan Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(connectedDevicesProvider.notifier)
          .revokeAllOtherDevices();
      if (!mounted) return;
      MekaarSnackbar.success(
        context,
        'Semua perangkat lain berhasil dikeluarkan.',
      );
    }
  }
}

// ─── Komponen Pendukung ───

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: MekaarTypography.labelSM.copyWith(
        color: MekaarColors.textMutedOf(context),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final UserDevice device;
  final bool isCurrent;
  final VoidCallback? onRevoke;

  const _DeviceCard({
    required this.device,
    required this.isCurrent,
    this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final brandAccent = MekaarColors.accentOf(context);

    return CustomCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Row(
        children: [
          // Ikon platform
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isCurrent ? brandAccent : MekaarColors.textMutedOf(context))
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(MekaarRadius.md),
            ),
            child: Icon(
              _platformIcon,
              color: isCurrent ? brandAccent : MekaarColors.textMutedOf(context),
              size: 22,
            ),
          ),
          const SizedBox(width: MekaarSpacing.md),

          // Info perangkat
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.deviceLabel ?? device.platform,
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MekaarColors.guardianTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Aktif',
                          style: MekaarTypography.caption.copyWith(
                            color: MekaarColors.safeTextOf(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: MekaarTypography.caption.copyWith(
                    color: MekaarColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),

          // Tombol revoke
          if (onRevoke != null)
            IconButton(
              icon: Icon(
                SolarIconsOutline.logout,
                color: MekaarColors.sosRed.withValues(alpha: 0.8),
                size: 20,
              ),
              tooltip: 'Keluarkan perangkat',
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }

  IconData get _platformIcon {
    switch (device.platform.toLowerCase()) {
      case 'android':
      case 'ios':
        return SolarIconsOutline.smartphone;
      default:
        return SolarIconsOutline.monitor;
    }
  }

  String get _subtitle {
    final parts = <String>[];
    if (device.appVersion != null) parts.add('v${device.appVersion}');
    parts.add(_formatLastSeen(device.lastSeenAt));
    return parts.join(' • ');
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 2) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }
}

class _RevokeAllButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _RevokeAllButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(
        SolarIconsOutline.logout,
        color: MekaarColors.sosRed,
        size: 18,
      ),
      label: Text(
        'Keluarkan $count Perangkat Lain',
        style: MekaarTypography.bodySM.copyWith(
          color: MekaarColors.sosRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
