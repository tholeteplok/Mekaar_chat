import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../providers/log_provider.dart';
import '../../../data/models/security_log_model.dart';
import '../widgets/settings_tiles.dart';

class SecurityLogsScreen extends ConsumerStatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  ConsumerState<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends ConsumerState<SecurityLogsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(securityLogProvider.notifier).loadLogs();
    });
  }

  void _exportCSV() async {
    final result = await ref
        .read(securityLogProvider.notifier)
        .exportSignedLogs();

    if (mounted) {
      final hasSignature = result['signature']?.isNotEmpty ?? false;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ekspor Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log keamanan berhasil diekspor sebagai file CSV dan siap dibagikan.',
              ),
              if (hasSignature) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MekaarColors.guardianTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tertandatangani secara kriptografis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: MekaarColors.guardianTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result['statement'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${result['algorithm']?.isNotEmpty ?? false ? result['algorithm'] : 'Ed25519'}: ${result['signature']}',
                        style: MekaarTypography.monoMD.copyWith(
                          fontSize: 11,
                          color: MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                      if (result['public_key']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Public key server (untuk verifikasi independen):',
                          style: TextStyle(
                            fontSize: 11,
                            color: MekaarColors.textMutedOf(context),
                          ),
                        ),
                        Text(
                          result['public_key'] ?? '',
                          style: MekaarTypography.monoMD.copyWith(
                            fontSize: 11,
                            color: MekaarColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'Catatan: Ekspor offline lokal (belum ditandatangani oleh server).',
                  style: TextStyle(
                    fontSize: 11,
                    color: MekaarColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(securityLogProvider);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsTopBar(
              title: 'Riwayat SOS',
              subtitle: 'Catatan insiden darurat selama 90 hari',
              trailing: IconButton(
                icon: Icon(
                  SolarIconsOutline.download,
                  color: MekaarColors.textPrimaryOf(context),
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: MekaarColors.surface2Of(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _exportCSV,
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? AnimatedAppear(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: MekaarColors.surface2Of(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                SolarIconsOutline.history,
                                size: 40,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada riwayat SOS',
                              style: MekaarTypography.headingSM.copyWith(
                                color: MekaarColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Aktivitas pengaktifan SOS atau penonaktifan darurat akan dicatat di sini secara permanen.',
                                textAlign: TextAlign.center,
                                style: MekaarTypography.bodySM.copyWith(
                                  color: MekaarColors.textSecondaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: logs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return AnimatedAppear(
                          delay: Duration(milliseconds: (index * 30).clamp(0, 240)),
                          child: _buildLogItem(log),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(SecurityLog log) {
    final iconData = _getIconForEvent(log.eventType);
    final color = _getColorForEvent(log.eventType);
    final timeStr = DateFormat('dd MMM, HH:mm').format(log.createdAt.toLocal());

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitleForEvent(log.eventType),
                  style: MekaarTypography.labelLG.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  log.details?['description'] ??
                      _getDefaultDescForEvent(log.eventType),
                  style: MekaarTypography.bodySM,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(timeStr, style: MekaarTypography.labelSM),
        ],
      ),
    );
  }

  IconData _getIconForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return SolarIconsOutline.danger;
      case 'sos_ended':
        return SolarIconsOutline.checkCircle;
      case 'guardian_location_accessed':
        return SolarIconsOutline.mapPoint;
      case 'guardian_audio_accessed':
        return SolarIconsOutline.microphone;
      case 'emergency_media_sent':
        return SolarIconsOutline.videocamera;
      default:
        return SolarIconsOutline.infoCircle;
    }
  }

  Color _getColorForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return MekaarColors.sosRed;
      case 'sos_ended':
        return MekaarColors.success;
      case 'guardian_location_accessed':
        return MekaarColors.info;
      case 'guardian_audio_accessed':
        return MekaarColors.guardianTeal;
      case 'emergency_media_sent':
        return MekaarColors.warning;
      default:
        return MekaarColors.textMuted;
    }
  }

  String _getTitleForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return 'SOS Diaktifkan';
      case 'sos_ended':
        return 'SOS Diakhiri';
      case 'guardian_location_accessed':
        return 'Lokasi GPS Diakses';
      case 'guardian_audio_accessed':
        return 'Mikrofon Diakses';
      case 'emergency_media_sent':
        return 'Video Darurat Dikirim';
      default:
        return 'Aktivitas SOS';
    }
  }

  String _getDefaultDescForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return 'Tombol darurat SOS ditekan oleh Anda.';
      case 'sos_ended':
        return 'Mode darurat SOS dinonaktifkan secara manual.';
      case 'guardian_location_accessed':
        return 'Guardian mengakses koordinat lokasi Anda.';
      case 'guardian_audio_accessed':
        return 'Guardian mendengarkan audio sekitar perangkat.';
      case 'emergency_media_sent':
        return 'Anda memulai streaming video VC darurat.';
      default:
        return 'Metadata keselamatan tercatat selama SOS aktif.';
    }
  }
}
