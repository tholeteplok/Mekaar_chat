import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../data/services/location_service.dart';

class LocationPickerResult {
  final LatLng location;
  final String? labelHint;

  const LocationPickerResult({
    required this.location,
    this.labelHint,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final int radiusMeters;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.radiusMeters = 150,
    this.title = 'Pilih Lokasi Tujuan di Peta',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  late LatLng _selectedLocation;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Default awal jika lokasi belum dikirim
    _selectedLocation = widget.initialLocation ?? const LatLng(-6.2088, 106.8456);

    // Ambil lokasi GPS fisik real-time saat layar pertama dibuka jika tidak ada lokasi awal
    if (widget.initialLocation == null) {
      _fetchCurrentGpsLocation();
    }
  }

  Future<void> _fetchCurrentGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      final locData = await LocationService.getCurrentLocation();
      if (locData != null && locData.latitude != null && locData.longitude != null) {
        final currentGps = LatLng(locData.latitude!, locData.longitude!);
        setState(() {
          _selectedLocation = currentGps;
        });
        _mapController.move(currentGps, 16.5);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedLocation = latLng;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = MekaarColors.surfaceOf(context);

    return MekaarScaffold(
      appBar: CustomAppBar(
        title: widget.title,
        subtitle: 'Ketuk peta untuk menentukan lokasi tujuan',
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 16,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mekaar.app',
              ),
              // Lingkaran visualisasi Geofence radius
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _selectedLocation,
                    radius: widget.radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: MekaarColors.cyan.withValues(alpha: 0.22),
                    borderColor: MekaarColors.cyan,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // Marker Pin Tujuan
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      SolarIconsBold.mapPoint,
                      color: MekaarColors.sosCoral,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tombol Re-center GPS (Lokasi Saya)
          Positioned(
            top: MekaarSpacing.md,
            right: MekaarSpacing.md,
            child: FloatingActionButton.small(
              heroTag: 'my_location_btn',
              backgroundColor: surfaceColor,
              foregroundColor: MekaarColors.cyan,
              onPressed: () {
                HapticFeedback.selectionClick();
                _fetchCurrentGpsLocation();
              },
              child: _isLoadingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: MekaarColors.cyan),
                    )
                  : const Icon(SolarIconsBold.gps, size: 20),
            ),
          ),

          // Floating Info & Selection Bar di bagian bawah
          Positioned(
            left: MekaarSpacing.md,
            right: MekaarSpacing.md,
            bottom: MekaarSpacing.lg,
            child: Container(
              padding: const EdgeInsets.all(MekaarSpacing.md),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(MekaarRadius.lg),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MekaarColors.cyan.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          SolarIconsBold.mapPointSearch,
                          color: MekaarColors.cyan,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: MekaarSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Koordinat Dipilih',
                              style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
                            ),
                            Text(
                              '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                              style: MekaarTypography.bodyMD.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MekaarSpacing.sm),
                  Text(
                    'Radius Geofence: ${widget.radiusMeters} meter (ditampilkan lingkaran biru)',
                    style: MekaarTypography.bodySM.copyWith(color: MekaarColors.textMutedOf(context)),
                  ),
                  const SizedBox(height: MekaarSpacing.md),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(
                          context,
                          LocationPickerResult(location: _selectedLocation),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MekaarColors.yellow,
                        foregroundColor: MekaarColors.textOnYellow,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Konfirmasi Lokasi Ini',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
