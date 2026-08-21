import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Mengelola identitas unik perangkat (device_id) per instalasi.
///
/// device_id di-generate sekali saat pertama kali dijalankan, kemudian
/// disimpan permanen di [FlutterSecureStorage] sehingga bertahan
/// meskipun user logout/login ulang, app di-update, atau data cache dihapus.
class DeviceIdentityService {
  static const _storageKey = 'mekaar_device_id';
  static const _storage = FlutterSecureStorage();
  static String? _cachedDeviceId;
  static String? _cachedDeviceLabel;

  /// Mendapatkan device_id permanen per instalasi.
  /// Generate UUID baru jika belum ada.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored != null && stored.isNotEmpty) {
        _cachedDeviceId = stored;
        return stored;
      }
    } catch (_) {
      // SecureStorage bisa gagal di beberapa perangkat; generate baru.
    }

    final newId = const Uuid().v4();
    try {
      await _storage.write(key: _storageKey, value: newId);
    } catch (_) {
      // Best-effort persist; jika gagal, ID tetap di-cache di memory.
    }
    _cachedDeviceId = newId;
    return newId;
  }

  /// Mendapatkan label perangkat yang ramah manusia.
  /// Contoh: "Samsung Galaxy S24", "iPhone 15 Pro".
  static Future<String> getDeviceLabel() async {
    if (_cachedDeviceLabel != null) return _cachedDeviceLabel!;

    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final brand = android.brand;
        final model = android.model;
        // Hindari duplikasi brand jika model sudah mengandung brand
        // e.g. "Samsung SM-S926B" → "Samsung SM-S926B" bukan "Samsung Samsung..."
        if (model.toLowerCase().startsWith(brand.toLowerCase())) {
          _cachedDeviceLabel = model;
        } else {
          _cachedDeviceLabel = '$brand $model';
        }
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        _cachedDeviceLabel = ios.utsname.machine; // e.g. "iPhone16,1"
        // Mapping ke nama komersial bisa ditambahkan nanti
      } else {
        _cachedDeviceLabel = 'Perangkat tidak dikenal';
      }
    } catch (_) {
      _cachedDeviceLabel = 'Perangkat tidak dikenal';
    }

    return _cachedDeviceLabel!;
  }

  /// Mendapatkan string platform.
  static String getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Reset cache (untuk testing).
  @visibleForTesting
  static void resetCache() {
    _cachedDeviceId = null;
    _cachedDeviceLabel = null;
  }
}
