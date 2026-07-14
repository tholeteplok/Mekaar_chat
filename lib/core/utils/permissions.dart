import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

/// PermissionsHelper — Centralize semua permission request logic.
/// Screen tidak boleh memanggil Permission.xxx langsung; pakai helper ini.
class PermissionsHelper {
  PermissionsHelper._();

  static final Logger _logger = Logger();

  // ─────────────────────────────────────────
  // SOS Permissions (Location + Mic + Camera)
  // ─────────────────────────────────────────

  /// Request semua izin yang dibutuhkan fitur SOS.
  /// Mengembalikan map status setiap permission.
  static Future<Map<Permission, PermissionStatus>> requestSOSPermissions() async {
    _logger.i('PermissionsHelper: Requesting SOS permissions...');
    final statuses = await [
      Permission.location,
      Permission.microphone,
      Permission.camera,
    ].request();
    _logger.i('PermissionsHelper: SOS permissions result: $statuses');
    return statuses;
  }

  /// Cek apakah semua permission SOS sudah granted (tanpa request).
  static Future<bool> hasAllSOSPermissions() async {
    final location = await Permission.location.isGranted;
    final mic = await Permission.microphone.isGranted;
    final camera = await Permission.camera.isGranted;
    return location && mic && camera;
  }

  // ─────────────────────────────────────────
  // Individual Checks
  // ─────────────────────────────────────────

  static Future<bool> hasMicPermission() async {
    return await Permission.microphone.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }

  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  // ─────────────────────────────────────────
  // Individual Requests
  // ─────────────────────────────────────────

  static Future<bool> requestMic() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> requestLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // ─────────────────────────────────────────
  // Open App Settings (jika user sudah deny permanently)
  // ─────────────────────────────────────────

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Cek apakah permission sudah permanently denied (perlu buka settings)
  static Future<bool> isMicPermanentlyDenied() async {
    return await Permission.microphone.isPermanentlyDenied;
  }

  static Future<bool> isLocationPermanentlyDenied() async {
    return await Permission.location.isPermanentlyDenied;
  }
}
