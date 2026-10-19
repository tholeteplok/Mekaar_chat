import 'dart:math';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static loc.Location? _locationInstance;
  static loc.Location get _location {
    _locationInstance ??= loc.Location();
    return _locationInstance!;
  }

  /// Memeriksa apakah izin lokasi berstatus ditolak permanen
  static Future<bool> isLocationPermanentlyDenied() async {
    try {
      final status = await Permission.location.status;
      return status.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  // Request location permission
  // [allowOpenSettings] default false agar tidak membajak layar secara otomatis (terutama saat alur darurat SOS)
  static Future<bool> requestPermission({bool allowOpenSettings = false}) async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) return true;

      // Jika user sudah permanently deny, arahkan ke Settings HANYA jika diizinkan eksplisit
      if (status.isPermanentlyDenied) {
        if (allowOpenSettings) {
          await openAppSettings();
          // Cek lagi setelah user kembali dari settings
          final recheckStatus = await Permission.location.status;
          return recheckStatus.isGranted;
        }
        return false;
      }

      // Fallback to location package's request
      final permissionStatus = await _location.requestPermission();
      return permissionStatus == loc.PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  // Get current device coordinates with timeout and service check
  static Future<loc.LocationData?> getCurrentLocation({bool allowOpenSettings = false}) async {
    try {
      final hasPermission = await requestPermission(allowOpenSettings: allowOpenSettings);
      if (!hasPermission) return null;

      final serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        final requestEnabled = await _location.requestService();
        if (!requestEnabled) return null;
      }

      try {
        await _location.changeSettings(
          accuracy: loc.LocationAccuracy.high,
          interval: 1000,
        );
      } catch (_) {}

      // Timeout 12 detik untuk memastikan GPS hardware berhasil mengunci koordinat satelit
      try {
        return await _location.getLocation().timeout(const Duration(seconds: 12));
      } catch (_) {
        try {
          await _location.changeSettings(accuracy: loc.LocationAccuracy.balanced);
          return await _location.getLocation().timeout(const Duration(seconds: 6));
        } catch (_) {
          return null;
        }
      }
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
