import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../providers/log_provider.dart';
import '../../../data/models/security_log_model.dart';

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
    final result =
        await ref.read(securityLogProvider.notifier).exportSignedLogs();

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
                        'SHA-256: ${result['signature']}',
                        style: const TextStyle(
                            fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'Catatan: tanda tangan kriptografis belum aktif (Edge Function sign-logs belum di-deploy).',
                  style: TextStyle(fontSize: 11, color: MekaarColors.textMuted),
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

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Log?'),
        content: const Text(
          'Ini adalah catatan aktivitas keamanan. Menghapusnya dapat menghilangkan bukti penting. Tindakan penghapusan ini tetap akan dicatat di log baru.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(securityLogProvider.notifier).clearLogs();
            },
            child: const Text('Hapus Semua', style: TextStyle(color: MekaarColors.sosRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(securityLogProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Log Sistem',
        subtitle: 'Catatan aktivitas keamanan permanen',
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: MekaarColors.textSecondary),
            onPressed: _exportCSV,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: MekaarColors.sosRed),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: logs.isEmpty
          ? AnimatedAppear(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MekaarColors.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history, size: 40, color: MekaarColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada log keamanan.',
                      style: MekaarTypography.headingSM,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Aktivitas SOS, akses Guardian, dan penghapusan pesan akan tercatat di sini.',
                        style: MekaarTypography.bodyMD
                            .copyWith(color: MekaarColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return AnimatedAppear(
                  delay: Duration(milliseconds: (index * 30).clamp(0, 240)),
                  child: _buildLogItem(log),
                );
              },
            ),
    );
  }

  Widget _buildLogItem(SecurityLog log) {
    final iconData = _getIconForEvent(log.eventType);
    final color = _getColorForEvent(log.eventType);
    final timeStr = DateFormat('dd MMM, HH:mm').format(log.createdAt);

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
                  log.details?['description'] ?? _getDefaultDescForEvent(log.eventType),
                  style: MekaarTypography.bodySM,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: MekaarTypography.labelSM,
          ),
        ],
      ),
    );
  }

  IconData _getIconForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return Icons.warning_amber_rounded;
      case 'sos_ended':
        return Icons.check_circle_outline_rounded;
      case 'guardian_gps_access':
        return Icons.location_on_outlined;
      case 'guardian_mic_access':
        return Icons.mic_none_rounded;
      case 'video_sent':
        return Icons.videocam_outlined;
      case 'message_deleted':
        return Icons.delete_outline_rounded;
      case 'log_deleted':
        return Icons.history_toggle_off_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return MekaarColors.sosRed;
      case 'sos_ended':
        return MekaarColors.success;
      case 'guardian_gps_access':
        return MekaarColors.info;
      case 'guardian_mic_access':
        return MekaarColors.guardianTeal;
      case 'video_sent':
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
      case 'guardian_gps_access':
        return 'Lokasi GPS Diakses';
      case 'guardian_mic_access':
        return 'Mikrofon Diakses';
      case 'video_sent':
        return 'Video Darurat Dikirim';
      case 'message_deleted':
        return 'Pesan Dihapus';
      case 'log_deleted':
        return 'Log Dihapus';
      default:
        return 'Keamanan Terdaftar';
    }
  }

  String _getDefaultDescForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return 'Tombol darurat SOS ditekan oleh Anda.';
      case 'sos_ended':
        return 'Mode darurat SOS dinonaktifkan secara manual.';
      case 'guardian_gps_access':
        return 'Guardian mengakses koordinat lokasi Anda.';
      case 'guardian_mic_access':
        return 'Guardian mendengarkan audio sekitar perangkat.';
      case 'video_sent':
        return 'Anda memulai streaming video VC darurat.';
      default:
        return 'Aktivitas keamanan tercatat.';
    }
  }
}
