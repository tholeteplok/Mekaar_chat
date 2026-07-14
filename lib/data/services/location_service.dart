import 'dart:math';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static loc.Location? _locationInstance;
  static loc.Location get _location {
    _locationInstance ??= loc.Location();
    return _locationInstance!;
  }

  // Request location permission
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) return true;
      
      // Fallback to location package's request
      final permissionStatus = await _location.requestPermission();
      return permissionStatus == loc.PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  // Get current device coordinates
  static Future<loc.LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        final requestEnabled = await _location.requestService();
        if (!requestEnabled) return null;
      }

      return await _location.getLocation();
    } catch (e) {
      return null;
    }
  }

  // Stream location updates
  static Stream<loc.LocationData> getLocationStream() {
    try {
      return _location.onLocationChanged;
    } catch (_) {
      return const Stream.empty();
    }
  }

  // Get full OpenStreetMap map URL
  static String getOpenStreetMapUrl(double lat, double lon) {
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon';
  }

  // Get Tile URL helper (for static mini map tile renders)
  static String getOpenStreetMapStaticUrl(double lat, double lon) {
    return 'https://tile.openstreetmap.org/17/${_tileX(lat, lon)}/${_tileY(lat, lon)}.png';
  }

  static int _tileX(double lat, double lon) {
    return ((lon + 180) / 360 * (1 << 17)).floor();
  }

  static int _tileY(double lat, double lon) {
    final latRad = lat * pi / 180;
    return ((1 - (log(tan(latRad) + 1 / cos(latRad)) / pi)) / 2 * (1 << 17)).floor();
  }
}
