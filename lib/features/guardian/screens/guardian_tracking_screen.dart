import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
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
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSessions);
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

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
          ping = null;
        }
        result.add({'session': session, 'ping': ping});
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _sessions = result;
      _isLoading = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka OpenStreetMap.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Lacak Guardian',
        subtitle: 'Lokasi live pemilik dalam mode darurat',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MekaarColors.sosRed),
            )
          : _sessions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tidak ada Guardian yang sedang dalam mode darurat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MekaarColors.textMuted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final item = _sessions[index];
                final session = item['session'] as Map<String, dynamic>;
                final ping = item['ping'] as Map<String, dynamic>?;
                return _buildSessionCard(session, ping);
              },
            ),
    );
  }

  Widget _buildSessionCard(
    Map<String, dynamic> session,
    Map<String, dynamic>? ping,
  ) {
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: MekaarColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MekaarColors.textMuted,
                      ),
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
                child: const Text(
                  'SOS Aktif',
                  style: TextStyle(
                    fontSize: 9,
                    color: MekaarColors.sosRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ping == null)
            const Row(
              children: [
                Icon(
                  Icons.location_searching,
                  size: 16,
                  color: MekaarColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'Menunggu koordinat...',
                  style: TextStyle(fontSize: 12, color: MekaarColors.textMuted),
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
                    icon: const Icon(Icons.map_outlined, size: 18),
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
                    icon: const Icon(Icons.open_in_new, size: 18),
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
            const Icon(Icons.location_on, size: 16, color: MekaarColors.sosRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 12,
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
              Icons.access_time,
              size: 16,
              color: MekaarColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              _formatTimestamp(timestamp),
              style: const TextStyle(
                fontSize: 12,
                color: MekaarColors.textMuted,
              ),
            ),
          ],
        ),
        if (accuracy != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.gps_fixed,
                size: 16,
                color: MekaarColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Akurasi: ${accuracy.toStringAsFixed(1)} m',
                style: const TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
