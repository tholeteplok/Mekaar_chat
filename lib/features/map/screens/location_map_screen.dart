import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_app_bar.dart';

class LocationMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? locationName;

  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng centerPoint = LatLng(latitude, longitude);

    return Scaffold(
      appBar: CustomAppBar(
        title: locationName ?? 'Lokasi Terlacak',
        subtitle: 'Peta pelacakan darurat',
      ),
      body: Column(
        children: [
          // FlutterMap rendering OSM
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mekaar.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: centerPoint,
                      width: 60,
                      height: 60,
                      child: TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 1),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: const Icon(
                              Icons.location_on,
                              color: MekaarColors.sosRed,
                              size: 48,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bottom Info bar
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
                Row(
                  children: [
                    const Icon(Icons.location_pin, color: MekaarColors.sosRed, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationName ?? 'Koordinat Lokasi',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: MekaarColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lintang: $latitude\nBujur: $longitude',
                  style: const TextStyle(fontSize: 12, color: MekaarColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy_all_outlined, size: 20),
                        label: const Text('Salin Koordinat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '$latitude, $longitude'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Koordinat berhasil disalin!')),
                          );
                        },
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
