import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../data/services/location_service.dart';

class DeviceLostScreen extends StatefulWidget {
  const DeviceLostScreen({super.key});

  @override
  State<DeviceLostScreen> createState() => _DeviceLostScreenState();
}

class _DeviceLostScreenState extends State<DeviceLostScreen> {
  final _messageController = TextEditingController();
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final locData = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = locData?.latitude;
        _lon = locData?.longitude;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _triggerAlarm() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Perintah Alarm Terkirim! Perangkat akan membunyikan alarm keras.',
        ),
        backgroundColor: MekaarColors.success,
      ),
    );
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

  void _lockWithCustomMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Layar Terkunci dengan Pesan: "$text"'),
        backgroundColor: MekaarColors.success,
      ),
    );
    _messageController.clear();
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
                  child: _lat == null || _lon == null
                      ? const Center(child: Text('Lokasi tidak tersedia'))
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
                                    Icons.phone_android,
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
                        ? 'Koordinat: —'
                        : 'Koordinat: $_lat, $_lon',
                    style: const TextStyle(
                      fontSize: 12,
                      color: MekaarColors.textSecondary,
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
              color: MekaarColors.surface,
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
                const Text(
                  'Perintah Jarak Jauh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MekaarColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Bunyikan Alarm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _triggerAlarm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('Buka di OpenStreetMap'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _openInOsm,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kirim Pesan Kunci Layar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
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
                    GestureDetector(
                      onTap: _lockWithCustomMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: MekaarColors.softCoral,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
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
