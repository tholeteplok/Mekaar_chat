import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';

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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 48 + (value * 16),
                                  height: 48 + (value * 16),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.sosRed
                                        .withValues(alpha: 0.18 * (1 - value)),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on,
                                  color: MekaarColors.sosRed,
                                  size: 48,
                                ),
                              ],
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
              color: MekaarColors.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
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
                        style: MekaarTypography.headingSM,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lintang: $latitude\nBujur: $longitude',
                  style: MekaarTypography.bodySM.copyWith(height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                        label: const Text('Salin Koordinat'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MekaarColors.textPrimaryOf(context),
                          side: BorderSide(
                              color: MekaarColors.textMutedOf(context)
                                  .withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: '$latitude, $longitude'));
                          MekaarSnackbar.success(
                            context,
                            'Koordinat berhasil disalin!',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Rute Navigasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.softCoral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () =>
                            _openExternalMap(context, latitude, longitude),
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

  Future<void> _openExternalMap(
      BuildContext context, double lat, double lon) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    // 1. Coba geo: URI (Intent Native Android / iOS Map App)
    final geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
    try {
      final launched =
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 2. Fallback Google Maps Web URL
    final googleMapsUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    try {
      final launched =
          await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 3. Fallback OpenStreetMap Web URL
    final osmUri = Uri.parse(
        'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon');
    try {
      await launchUrl(osmUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (context.mounted) {
        MekaarSnackbar.error(
            context, 'Tidak dapat membuka aplikasi peta eksternal.');
      }
    }
  }
}
