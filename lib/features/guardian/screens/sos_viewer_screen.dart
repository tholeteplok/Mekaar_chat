import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/alarm_service.dart';
import '../../../data/services/location_service.dart';
import '../../sos/providers/sos_provider.dart';

/// Layar pembaca SOS untuk Guardian.
///
/// Dibuka saat guardian mengetuk notifikasi SOS (FCM maupun realtime).
/// Berbeda dari `SOSActiveScreen` yang merupakan sisi korban: layar ini
/// TIDAK akan mengaktifkan SOS apa pun — hanya menampilkan identitas korban
/// dan koordinat terakhir agar guardian bisa segera menuju lokasi.
class SOSViewerScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? userId;
  final String? userName;

  const SOSViewerScreen({
    super.key,
    required this.sessionId,
    this.userId,
    this.userName,
  });

  @override
  ConsumerState<SOSViewerScreen> createState() => _SOSViewerScreenState();
}

class _SOSViewerScreenState extends ConsumerState<SOSViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _updatedAt;
  Map<String, dynamic>? _ping;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPing();
    // Segarkan koordinat otomatis tiap 10 detik selama layar terbuka
    // agar guardian selalu melihat lokasi korban terbaru.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadPing(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPing({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    final repo = ref.read(sosRepositoryProvider);
    try {
      final ping = await repo.getLatestLocationPing(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _ping = ping;
        _isLoading = false;
        _updatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return timestamp;
    }
  }

  Future<void> _openInOpenStreetMap(double lat, double lon) async {
    try {
      final url = Uri.parse(LocationService.getOpenStreetMapUrl(lat, lon));
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Tidak dapat membuka OpenStreetMap.');
    }
  }

  Future<void> _handleTriggerAlarm(String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MekaarDialog(
        icon: const Icon(
          SolarIconsBold.bellBing,
          color: MekaarColors.sosRed,
          size: 28,
        ),
        title: 'Bunyikan Sirine?',
        message:
            'Sirine darurat akan dibunyikan pada perangkat untuk membantu menemukan dan memberi sinyal peringatan kepada orang di sekitar $userName.',
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
            child: const Text('Bunyikan Sirine'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AlarmService.playSOSAlarm();
      if (mounted) {
        MekaarSnackbar.warning(
          context,
          'Sirine peringatan darurat dibunyikan.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'SOS ${widget.userName ?? 'Darurat'}',
        subtitle: 'Lokasi darurat korban',
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.refresh),
            onPressed: _isLoading ? null : _loadPing,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _ping == null) {
      return const MekaarStateView(
        pose: MikaPose.shield,
        title: 'Memuat Lokasi Darurat',
        message: 'Mengambil koordinat terakhir korban…',
        layout: MekaarStateLayout.centered,
        semanticLabel: 'Memuat lokasi darurat',
      );
    }
    if (_hasError) {
      return _buildMessageState(
        icon: SolarIconsOutline.dangerTriangle,
        message: 'Lokasi darurat tidak dapat dimuat.',
        actionLabel: 'Coba Lagi',
        onPressed: _loadPing,
      );
    }
    if (_ping == null) {
      return _buildMessageState(
        icon: SolarIconsOutline.gps,
        message: 'Belum ada koordinat yang diterima dari korban. '
            'Menunggu ping lokasi berikutnya…',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPing(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Diperbarui ${_formatTimestamp(_updatedAt!.toIso8601String())}',
              style: MekaarTypography.bodySM,
            ),
          ),
          _buildPingCard(),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: MekaarColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textMuted,
              ),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPingCard() {
    final userName = widget.userName ?? 'Korban';
    final ping = _ping!;
    final lat = (ping['latitude'] as num).toDouble();
    final lon = (ping['longitude'] as num).toDouble();
    final timestamp = ping['timestamp'] as String? ?? '';
    final accuracy = (ping['accuracy'] as num?)?.toDouble();

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: MekaarTypography.labelLG.copyWith(
                        color: MekaarColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sesi SOS aktif',
                      style: MekaarTypography.bodySM,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MekaarColors.sosLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'SOS Aktif',
                  style: MekaarTypography.labelSM.copyWith(
                    color: MekaarColors.sosRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                SolarIconsOutline.mapPoint,
                size: 16,
                color: MekaarColors.sosRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                  style: MekaarTypography.bodySM.copyWith(
                    color: MekaarColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (timestamp.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  SolarIconsOutline.clockSquare,
                  size: 16,
                  color: MekaarColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Diperbarui ${_formatTimestamp(timestamp)}',
                  style: MekaarTypography.bodySM,
                ),
              ],
            ),
          ],
          if (accuracy != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  SolarIconsOutline.gps,
                  size: 16,
                  color: MekaarColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Akurasi: ${accuracy.toStringAsFixed(1)} m',
                  style: MekaarTypography.bodySM,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(SolarIconsOutline.map, size: 18),
                  label: const Text('Lihat di Peta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MekaarColors.textPrimary,
                    side: const BorderSide(color: MekaarColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.map,
                    arguments: {
                      'latitude': lat,
                      'longitude': lon,
                      'locationName': 'Lokasi $userName',
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(SolarIconsOutline.globus, size: 18),
                  label: const Text('OpenStreetMap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.sosRed,
                    foregroundColor: MekaarColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _openInOpenStreetMap(lat, lon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(
                SolarIconsOutline.volumeLoud,
                size: 18,
                color: MekaarColors.sosRed,
              ),
              label: const Text(
                'Bunyikan Sirine Peringatan',
                style: TextStyle(
                  color: MekaarColors.sosRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: MekaarColors.sosRed),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _handleTriggerAlarm(userName),
            ),
          ),
        ],
      ),
    );
  }
}