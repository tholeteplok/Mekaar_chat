import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/services/location_service.dart';
import '../../sos/providers/sos_provider.dart';

class GuardianTrackingScreen extends ConsumerStatefulWidget {
  const GuardianTrackingScreen({super.key});

  @override
  ConsumerState<GuardianTrackingScreen> createState() =>
      _GuardianTrackingScreenState();
}

class _GuardianTrackingScreenState
    extends ConsumerState<GuardianTrackingScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _updatedAt;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSessions);
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final repo = ref.read(sosRepositoryProvider);
    final result = <Map<String, dynamic>>[];

    try {
      final sessions = await repo.getActiveSessionsForMe();
      for (final session in sessions) {
        final sessionId = session['id'] as String;
        Map<String, dynamic>? ping;
        try {
          ping = await repo.getLatestLocationPing(sessionId);
        } catch (_) {
          result.add({'session': session, 'pingError': true});
          continue;
        }
        result.add({'session': session, 'ping': ping});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _sessions = result;
      _isLoading = false;
      _updatedAt = DateTime.now();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Lokasi Darurat',
        subtitle: 'Lokasi terakhir dari sesi SOS yang Anda jaga',
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.refresh),
            onPressed: _isLoading ? null : _loadSessions,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: MekaarColors.sosRed),
      );
    }
    if (_hasError) {
      return _buildMessageState(
        icon: SolarIconsOutline.dangerTriangle,
        message: 'Lokasi darurat tidak dapat dimuat.',
        actionLabel: 'Coba Lagi',
        onPressed: _loadSessions,
      );
    }
    if (_sessions.isEmpty) {
      return _buildMessageState(
        icon: SolarIconsOutline.shieldCheck,
        message: 'Tidak ada sesi SOS aktif yang sedang Anda jaga.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sessions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Diperbarui ${_formatDateTime(_updatedAt!)}',
                style: MekaarTypography.bodySM,
              ),
            );
          }
          final item = _sessions[index - 1];
          final session = item['session'] as Map<String, dynamic>;
          final ping = item['ping'] as Map<String, dynamic>?;
          return _buildSessionCard(
            session,
            ping,
            pingError: item['pingError'] == true,
          );
        },
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

  String _formatDateTime(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }

  Widget _buildSessionCard(
    Map<String, dynamic> session,
    Map<String, dynamic>? ping, {
    bool pingError = false,
  }) {
    final userName = session['user_name'] as String? ?? 'User';
    final userEmail = session['user_email'] as String? ?? '';

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
                      userEmail,
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
          if (pingError)
            Row(
              children: [
                Icon(
                  SolarIconsOutline.dangerTriangle,
                  size: 16,
                  color: MekaarColors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Koordinat terakhir tidak dapat dimuat. Coba perbarui.',
                    style: MekaarTypography.bodySM,
                  ),
                ),
              ],
            )
          else if (ping == null)
            Row(
              children: [
                Icon(
                  SolarIconsOutline.gps,
                  size: 16,
                  color: MekaarColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'Menunggu koordinat...',
                  style: MekaarTypography.bodySM,
                ),
              ],
            )
          else
            _buildPingInfo(ping),
          const SizedBox(height: 16),
          if (ping != null)
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
                        'latitude': ping['latitude'] as double,
                        'longitude': ping['longitude'] as double,
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
                    onPressed: () => _openInOpenStreetMap(
                      ping['latitude'] as double,
                      ping['longitude'] as double,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPingInfo(Map<String, dynamic> ping) {
    final lat = ping['latitude'] as double;
    final lon = ping['longitude'] as double;
    final timestamp = ping['timestamp'] as String;
    final accuracy = ping['accuracy'] as double?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}
