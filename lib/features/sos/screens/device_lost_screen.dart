import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';

class DeviceLostScreen extends StatefulWidget {
  const DeviceLostScreen({super.key});

  @override
  State<DeviceLostScreen> createState() => _DeviceLostScreenState();
}

class _DeviceLostScreenState extends State<DeviceLostScreen> {
  final _messageController = TextEditingController();
  final double _mockLat = -6.200000;
  final double _mockLon = 106.816666;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _triggerAlarm() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perintah Alarm Terkirim! Perangkat akan membunyikan alarm keras.'),
        backgroundColor: MekaarColors.success,
      ),
    );
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
    return Scaffold(
      appBar: const CustomAppBar(title: 'Temukan Ponsel Saya'),
      body: Column(
        children: [
          // OSM Map showing last location
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(_mockLat, _mockLon),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mekaar.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_mockLat, _mockLon),
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
          // Remote command interface panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: MekaarColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MekaarColors.textPrimary),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _triggerAlarm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kirim Pesan Kunci Layar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: MekaarColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ponsel ini hilang. Hubungi 0812...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
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
