import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/sos_streaming_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../sos/providers/device_lost_provider.dart';
import '../../sos/providers/sos_provider.dart';

/// Layar pembaca SOS untuk Guardian.
///
/// Dibuka saat guardian mengetuk notifikasi SOS (FCM maupun realtime).
/// Menampilkan:
/// 1. Feed video & audio WebRTC real-time dari korban (jika korban menyalakan video)
/// 2. Lokasi GPS terakhir & riwayat koordinat darurat
/// 3. Kontrol tombol darurat (Peta & Perintah Sirine Jarak Jauh)
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

  // WebRTC Streaming
  late final SosStreamingService _streamingService;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  SosStreamState _streamState = SosStreamState.idle;
  bool _hasRemoteVideo = false;

  @override
  void initState() {
    super.initState();
    _initWebRtc();
    _loadPing();

    // Segarkan koordinat otomatis tiap 10 detik
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadPing(silent: true);
    });
  }

  Future<void> _initWebRtc() async {
    try {
      await _remoteRenderer.initialize();
      _streamingService = SosStreamingService(Supabase.instance.client);

      _streamingService.onStreamStateChange = (state) {
        if (mounted) setState(() => _streamState = state);
      };

      _streamingService.onRemoteStream = (stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
            _hasRemoteVideo = stream.getVideoTracks().isNotEmpty;
          });
        }
      };

      final myUserId = SupabaseService().currentUserId;
      if (myUserId != null) {
        await _streamingService.joinStream(
          sessionId: widget.sessionId,
          myUserId: myUserId,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _streamingService.cleanUp();
    _remoteRenderer.dispose();
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
      final victimUserId = widget.userId;
      if (victimUserId == null || victimUserId.isEmpty) {
        MekaarSnackbar.error(
          context,
          'ID korban tidak ditemukan. Tidak dapat mengirim perintah sirine.',
        );
        return;
      }

      try {
        final repo = ref.read(deviceLostRepositoryProvider);
        await repo.sendRemoteCommand(
          targetProfileId: victimUserId,
          targetDeviceId: null, // Broadcast ke semua perangkat korban
          commandType: 'alarm',
          payload: {'sessionId': widget.sessionId},
        );
        if (mounted) {
          MekaarSnackbar.warning(
            context,
            'Perintah sirine darurat dikirim ke perangkat $userName.',
          );
        }
      } catch (e) {
        if (mounted) {
          MekaarSnackbar.error(
            context,
            'Gagal mengirim perintah sirine ke perangkat korban: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'SOS ${widget.userName ?? 'Darurat'}',
        subtitle: 'Pemantauan darurat real-time',
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
    if (_hasError && _ping == null) {
      return _buildMessageState(
        icon: SolarIconsOutline.dangerTriangle,
        message: 'Lokasi darurat tidak dapat dimuat.',
        actionLabel: 'Coba Lagi',
        onPressed: _loadPing,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPing(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Video Stream Player jika aktif ──
          if (_hasRemoteVideo && _remoteRenderer.srcObject != null) ...[
            _buildVideoStreamCard(),
            const SizedBox(height: 14),
          ] else ...[
            _buildStreamWaitingCard(),
            const SizedBox(height: 14),
          ],

          // ── 2. Info Lokasi GPS ──
          if (_updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Diperbarui ${_formatTimestamp(_updatedAt!.toIso8601String())}',
                style: MekaarTypography.caption.copyWith(
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
            ),

          if (_ping != null) _buildPingCard(),
        ],
      ),
    );
  }

  Widget _buildVideoStreamCard() {
    return CustomCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: Colors.black87,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MekaarColors.sosRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Siaran Langsung Korban',
                    style: MekaarTypography.labelSM.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MekaarColors.sosRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamWaitingCard() {
    return CustomCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MekaarColors.brandPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(MekaarRadius.sm),
            ),
            child: const Icon(
              SolarIconsOutline.videocameraRecord,
              color: MekaarColors.brandPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Umpan Video Darurat',
                  style: MekaarTypography.bodySM.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MekaarColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  _streamState == SosStreamState.waitingForViewer ||
                          _streamState == SosStreamState.connecting
                      ? 'Menghubungkan ke siaran korban…'
                      : 'Menunggu korban mengaktifkan kamera.',
                  style: MekaarTypography.caption.copyWith(
                    color: MekaarColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ),
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
            Icon(icon, size: 36, color: MekaarColors.textMutedOf(context)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textMutedOf(context),
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
      margin: EdgeInsets.zero,
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
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sesi SOS aktif',
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MekaarColors.sosRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'SOS Aktif',
                  style: MekaarTypography.labelSM.copyWith(
                    color: MekaarColors.sosRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Koordinat
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(MekaarRadius.md),
              border: Border.all(color: MekaarColors.cardBorderOf(context)),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  SolarIconsOutline.mapPoint,
                  'Latitude',
                  lat.toStringAsFixed(6),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  SolarIconsOutline.mapPoint,
                  'Longitude',
                  lon.toStringAsFixed(6),
                ),
                if (accuracy != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    SolarIconsOutline.gps,
                    'Akurasi',
                    '±${accuracy.toStringAsFixed(1)} m',
                  ),
                ],
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    SolarIconsOutline.clockCircle,
                    'Waktu Ping',
                    _formatTimestamp(timestamp),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tombol Aksi
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.map,
                      arguments: {
                        'lat': lat,
                        'lon': lon,
                        'title': 'Lokasi $userName',
                      },
                    );
                  },
                  icon: const Icon(SolarIconsOutline.map),
                  label: const Text('Lihat di Peta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.accentOf(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openInOpenStreetMap(lat, lon),
                icon: const Icon(SolarIconsOutline.link),
                label: const Text('OSM'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.sm),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tombol Sirine Peringatan
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleTriggerAlarm(userName),
              icon: const Icon(
                SolarIconsOutline.bellBing,
                color: MekaarColors.sosRed,
              ),
              label: Text(
                'Bunyikan Sirine Peringatan',
                style: TextStyle(color: MekaarColors.sosRed),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: MekaarColors.sosRed.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MekaarColors.textMutedOf(context)),
        const SizedBox(width: 8),
        Text(
          label,
          style: MekaarTypography.bodySM.copyWith(
            color: MekaarColors.textMutedOf(context),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: MekaarTypography.monoMD.copyWith(
            fontWeight: FontWeight.w600,
            color: MekaarColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}