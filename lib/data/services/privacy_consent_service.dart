import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/mekaar_secure_storage.dart';

/// Layanan pencatatan dan verifikasi persetujuan komunikasi privasi (Informed Consent)
/// MEKAAR 3.0 secara lokal pada perangkat.
///
/// Menyimpan stempel waktu (timestamp) ISO-8601 UTC ke Android Keystore / iOS Keychain
/// via [MekaarSecureStorage] dengan sinkronisasi ke [SharedPreferences] untuk
/// pembacaan instan tanpa blocking.
class PrivacyConsentService {
  PrivacyConsentService._();

  static final PrivacyConsentService instance = PrivacyConsentService._();

  static const String keyConsentTimestamp = 'privacy_consent_timestamp';

  /// Mencatat waktu persetujuan privasi secara lokal.
  Future<void> recordConsent({DateTime? timestamp}) async {
    final effectiveTime = (timestamp ?? DateTime.now().toUtc()).toUtc().toIso8601String();

    try {
      await MekaarSecureStorage.instance.write(
        key: keyConsentTimestamp,
        value: effectiveTime,
      );
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyConsentTimestamp, effectiveTime);
    } catch (_) {}
  }

  /// Mengambil stempel waktu ISO-8601 persetujuan privasi jika telah disetujui.
  Future<String?> getConsentTimestamp() async {
    // 1. Coba baca dari SharedPreferences untuk performa instan
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(keyConsentTimestamp);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}

    // 2. Fallback ke SecureStorage
    try {
      return await MekaarSecureStorage.instance.read(key: keyConsentTimestamp);
    } catch (_) {
      return null;
    }
  }

  /// Memeriksa apakah pengguna sudah pernah menyetujui kontrak privasi.
  Future<bool> hasConsented() async {
    final timestamp = await getConsentTimestamp();
    return timestamp != null && timestamp.isNotEmpty;
  }

  /// Menghapus data persetujuan (digunakan untuk pengujian atau reset akun).
  Future<void> clearConsent() async {
    try {
      await MekaarSecureStorage.instance.delete(key: keyConsentTimestamp);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyConsentTimestamp);
    } catch (_) {}
  }
}
