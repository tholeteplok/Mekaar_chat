import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sentralisasi konfigurasi FlutterSecureStorage untuk MEKAAR 3.0.
///
/// Memastikan seluruh penyimpanan kredensial, hash PIN, token sesi, dan
/// kunci kriptografi (E2EE/Database) terlindungi oleh perangkat keras
/// (Android Keystore TEE/StrongBox & iOS Keychain) serta tidak pernah
/// disinkronkan ke layanan pencadangan cloud (iCloud / iTunes / Google Drive).
class MekaarSecureStorage {
  MekaarSecureStorage._();

  /// Opsi penyimpanan aman Android dengan Enkripsi Hardware Keystore
  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// Opsi penyimpanan aman iOS dengan isolasi perangkat lokal
  /// (tidak disinkronkan ke iCloud Keychain atau iTunes backup).
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Instance sentral FlutterSecureStorage dengan proteksi Android & iOS lengkap
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iosOptions,
  );

  /// Helper untuk membuat instance baru dengan konfigurasi standar yang sama
  static FlutterSecureStorage create() => const FlutterSecureStorage(
        aOptions: androidOptions,
        iOptions: iosOptions,
      );
}
