import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Mengelola identitas unik perangkat (device_id) per instalasi.
///
/// Menggunakan dual-storage persistence:
/// 1. [SharedPreferences] sebagai media penyimpanan utama (kebal terhadap Android KeyStore reset/update)
/// 2. [FlutterSecureStorage] sebagai backup sekunder
class DeviceIdentityService {
  static const _storageKey = 'mekaar_persistent_device_id';
  static const _legacyStorageKey = 'mekaar_device_id';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String? _cachedDeviceId;
  static String? _cachedDeviceLabel;

  /// Mendapatkan device_id permanen per instalasi.
  /// Membaca dari SharedPreferences atau FlutterSecureStorage, atau men-generate UUID baru sekali saja.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final storedFromPrefs = prefs.getString(_storageKey) ??
          prefs.getString(_legacyStorageKey);
      if (storedFromPrefs != null && storedFromPrefs.isNotEmpty) {
        _cachedDeviceId = storedFromPrefs;
        // Pastikan tersimpan juga dengan key baru dan di secure storage
        await prefs.setString(_storageKey, storedFromPrefs);
        try {
          await _secureStorage.write(key: _storageKey, value: storedFromPrefs);
        } catch (_) {}
        return storedFromPrefs;
      }
    } catch (_) {}

    // Fallback: coba baca dari FlutterSecureStorage
    try {
      final storedFromSecure = (await _secureStorage.read(key: _storageKey)) ??
          (await _secureStorage.read(key: _legacyStorageKey));
      if (storedFromSecure != null && storedFromSecure.isNotEmpty) {
        _cachedDeviceId = storedFromSecure;
        if (prefs != null) {
          await prefs.setString(_storageKey, storedFromSecure);
        }
        return storedFromSecure;
      }
    } catch (_) {}

    // Generate UUID baru dan simpan ke kedua media penyimpanan
    final newId = const Uuid().v4();
    if (prefs != null) {
      try {
        await prefs.setString(_storageKey, newId);
      } catch (_) {}
    }
    try {
      await _secureStorage.write(key: _storageKey, value: newId);
    } catch (_) {}

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
