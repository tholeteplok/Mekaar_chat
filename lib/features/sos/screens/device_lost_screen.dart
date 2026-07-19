import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/alarm_service.dart';

class DeviceLostScreen extends StatefulWidget {
  const DeviceLostScreen({super.key});

  @override
  State<DeviceLostScreen> createState() => _DeviceLostScreenState();
}

class _DeviceLostScreenState extends State<DeviceLostScreen> {
  final _messageController = TextEditingController();
  double? _lat;
  double? _lon;
  bool _isLoadingLocation = true;
  String? _locationError;
  bool _isAlarmPlaying = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLocation);
    _isAlarmPlaying = AlarmService.isPlaying;
  }

  Future<void> _toggleAlarm() async {
    if (_isAlarmPlaying) {
      await AlarmService.stopAlarm();
      setState(() {
        _isAlarmPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm berhasil dimatikan.'),
            backgroundColor: MekaarColors.success,
          ),
        );
      }
    } else {
      await AlarmService.playSOSAlarm();
      setState(() {
        _isAlarmPlaying = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarm berbunyi keras!'),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
      _lat = null;
      _lon = null;
    });

    try {
      final locData = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = locData?.latitude;
        _lon = locData?.longitude;
        _isLoadingLocation = false;
        _locationError = locData == null
            ? 'Lokasi tidak dapat diperoleh. Periksa izin dan koneksi GPS.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'Gagal memuat lokasi perangkat.';
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openInOsm() async {
    if (_lat == null || _lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi tidak tersedia'),
          backgroundColor: MekaarColors.sosRed,
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = LocationService.getOpenStreetMapUrl(_lat!, _lon!);
      final launched = await launchUrl(Uri.parse(url));
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka OpenStreetMap'),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka OpenStreetMap'),
          backgroundColor: MekaarColors.sosRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Temukan Ponsel Saya'),
      body: Column(
        children: [
          // OSM Map showing last location
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _isLoadingLocation
                      ? const Center(child: CircularProgressIndicator())
                      : _locationError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const MikaIllustration(
                                  pose: MikaPose.huft,
                                  size: 90,
                                  semanticLabel: 'Gagal memuat lokasi',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _locationError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white70
                                        : MekaarColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _loadLocation,
                                  icon: const Icon(SolarIconsOutline.refresh),
                                  label: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_lat!, _lon!),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.mekaar.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_lat!, _lon!),
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    SolarIconsOutline.smartphone,
                                    color: MekaarColors.sosRed,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _lat == null || _lon == null
                        ? 'Koordinat: -'
                        : 'Koordinat: $_lat, $_lon',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : MekaarColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Remote command interface panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Perintah Jarak Jauh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : MekaarColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(SolarIconsOutline.volumeLoud),
                        label: Text(_isAlarmPlaying ? 'Matikan Alarm' : 'Bunyikan Alarm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isAlarmPlaying
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: _isAlarmPlaying
                              ? Theme.of(context).colorScheme.onError
                              : Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _toggleAlarm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(SolarIconsOutline.map),
                    label: const Text('Buka di OpenStreetMap'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _openInOsm,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pesan Kunci Layar (belum tersedia)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : MekaarColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: false,
                        decoration: const InputDecoration(
                          hintText: 'Ponsel ini hilang. Hubungi 0812...',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: null,
                      icon: const Icon(SolarIconsOutline.plain, size: 20),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
