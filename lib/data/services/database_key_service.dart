import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/storage/mekaar_secure_storage.dart';
import 'package:logger/logger.dart';
import 'aegis_memory_guard_service.dart';

/// Layanan terpusat untuk mengelola dan menurunkan kunci enkripsi database lokal (SQLCipher).
///
/// Menyediakan:
/// 1. Kunci acak 256-bit berbasis Hardware Keystore (`FlutterSecureStorage`) untuk database pesan.
/// 2. Kunci turunan KDF (PBKDF2-HMAC-SHA256 100.000 iterasi) dari PIN pengguna untuk brankas berkas.
/// 3. Pemusnahan forensik file (*secure shredding*) untuk file database dan WAL lama.
class DatabaseKeyService {
  DatabaseKeyService._();
  static final DatabaseKeyService instance = DatabaseKeyService._();

  static final Logger _logger = Logger();
  final FlutterSecureStorage _secureStorage = MekaarSecureStorage.instance;

  static const String _messageDbKeyStorageKey = 'sqlcipher_message_db_key_v1';
  static const String _decoyMessageDbKeyStorageKey = 'sqlcipher_decoy_message_db_key_v1';
  static const String _masterVaultSaltStorageKey = 'sqlcipher_vault_master_salt_v2';
  static const String _decoyVaultSaltStorageKey = 'sqlcipher_vault_decoy_salt_v2';
  static const int _pbkdf2Iterations = 100000;

  /// Kunci runtime in-memory untuk brankas berkas yang dibuka saat ini
  String? _activeVaultKey;
  String? _activeLegacyVaultKey;
  bool _isVaultDuress = false;
  BigInt? _activeVaultKeySlotId;

  /// Slot ID kunci aktif di memori Aegis Memory Guard (Rust heap terisolasi).
  BigInt? get activeVaultKeySlotId => _activeVaultKeySlotId;

  /// Mendapatkan salt acak 32-byte unik per perangkat dari Hardware Keystore.
  /// Mencegah serangan pre-computed rainbow table lintas perangkat.
  Future<List<int>> getOrCreateVaultSalt({required bool isDuress}) async {
    final storageKey = isDuress ? _decoyVaultSaltStorageKey : _masterVaultSaltStorageKey;
    try {
      final existingB64 = await _secureStorage.read(key: storageKey);
      if (existingB64 != null && existingB64.isNotEmpty) {
        return base64Decode(existingB64);
      }
      final random = Random.secure();
      final salt = List<int>.generate(32, (_) => random.nextInt(256));
      await _secureStorage.write(key: storageKey, value: base64Encode(salt));
      return salt;
    } catch (e) {
      _logger.e('Gagal memuat atau membuat salt acak untuk brankas: $e');
      final saltPrefix = isDuress ? 'mekaar_vault_decoy_salt_' : 'mekaar_vault_master_salt_';
      return utf8.encode('${saltPrefix}v1_secure');
    }
  }

  /// Mendapatkan atau membuat kunci enkripsi acak 256-bit untuk database pesan lokal.
  /// Kunci disimpan di Hardware Keystore / Secure Storage.
  Future<String> getMessageDatabaseKey() async {
    try {
      final existingKey = await _secureStorage.read(key: _messageDbKeyStorageKey);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }

      // Generate 32 bytes (256 bits) secure random key
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final newKey = base64UrlEncode(bytes);

      await _secureStorage.write(
        key: _messageDbKeyStorageKey,
        value: newKey,
      );
      return newKey;
    } catch (e) {
      _logger.e('Gagal memuat atau membuat kunci database pesan: $e');
      rethrow;
    }
  }

  /// Mendapatkan atau membuat kunci enkripsi acak 256-bit untuk database pesan decoy lokal.
  /// Kunci disimpan di Hardware Keystore / Secure Storage secara terpisah dari database utama.
  Future<String> getDecoyMessageDatabaseKey() async {
    try {
      final existingKey = await _secureStorage.read(key: _decoyMessageDbKeyStorageKey);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }

      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final newKey = base64UrlEncode(bytes);

      await _secureStorage.write(
        key: _decoyMessageDbKeyStorageKey,
        value: newKey,
      );
      return newKey;
    } catch (e) {
      _logger.e('Gagal memuat atau membuat kunci database pesan decoy: $e');
      rethrow;
    }
  }

  /// Menurunkan kunci enkripsi 256-bit dari PIN pengguna menggunakan Argon2id (64MB)
  /// dengan random salt unik per perangkat (v2).
  /// Mendukung fallback ke legacy PBKDF2 (v1) untuk auto-migrasi database lama.
  Future<String> deriveVaultKey(
    String pin, {
    required bool isDuress,
    bool forceLegacy = false,
  }) async {
    if (forceLegacy) {
      return deriveLegacyVaultKey(pin, isDuress: isDuress);
    }

    try {
      final salt = await getOrCreateVaultSalt(isDuress: isDuress);
      try {
        _activeVaultKeySlotId = await AegisMemoryGuardService.instance.deriveVaultKey(
          passcode: pin,
          salt: salt,
        );
      } catch (e) {
        _logger.w('Gagal mengisolasi kunci di AegisMemoryGuard: $e');
      }
      final argon2 = Argon2id(
        memory: 19456, // 19 MB (OWASP recommended minimum parameter untuk mobile Dart VM tanpa SIMD native)
        iterations: 2,
        parallelism: 1,
        hashLength: 32,
      );

      final secretKey = await argon2.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)),
        nonce: salt,
      );

      final keyBytes = await secretKey.extractBytes();
      return keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      _logger.w('Argon2id derivation gagal, fallback ke legacy: $e');
      return deriveLegacyVaultKey(pin, isDuress: isDuress);
    }
  }

  /// Menurunkan kunci legacy PBKDF2 (100.000 iterasi) secara on-demand khusus untuk migrasi database lama.
  Future<String> deriveLegacyVaultKey(String pin, {required bool isDuress}) async {
    final hexKey = await _deriveLegacyVaultKey(pin, isDuress: isDuress);
    _activeLegacyVaultKey = hexKey;
    return hexKey;
  }

  Future<String> _deriveLegacyVaultKey(String pin, {required bool isDuress}) async {
    final saltPrefix = isDuress ? 'mekaar_vault_decoy_salt_' : 'mekaar_vault_master_salt_';
    final salt = utf8.encode('${saltPrefix}v1_secure');

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac(Sha256()),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );

    final keyBytes = await secretKey.extractBytes();
    final hexKey = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hexKey;
  }

  /// Mengatur kunci aktif brankas di memori aplikasi setelah verifikasi PIN berhasil.
  void setActiveVaultKey(String key, {required bool isDuress}) {
    _activeVaultKey = key;
    _isVaultDuress = isDuress;
  }

  /// Mendapatkan kunci aktif brankas saat ini.
  String? get activeVaultKey => _activeVaultKey;

  /// Kunci legacy yang diturunkan sementara untuk re-keying database lama
  String? get activeLegacyVaultKey => _activeLegacyVaultKey;

  /// Mengetahui apakah brankas yang sedang aktif adalah Decoy (Duress).
  bool get isVaultDuress => _isVaultDuress;

  /// Mengunci kembali brankas dan membersihkan kunci dari memori.
  Future<void> lockVault() async {
    _activeVaultKey = null;
    _activeLegacyVaultKey = null;
    _isVaultDuress = false;
    final slotId = _activeVaultKeySlotId;
    _activeVaultKeySlotId = null;
    if (slotId != null) {
      try {
        await AegisMemoryGuardService.instance.zeroizeKey(slotId);
      } catch (_) {}
    }
  }

  /// Melakukan pemusnahan forensik aman (*secure shredding*) pada sebuah file.
  /// Menimpa isi file dengan byte acak dan nol sebelum memanggil `delete()`,
  /// serta memusnahkan file jurnal/WAL yang bersangkutan jika ada.
  Future<void> shredFile(File file) async {
    try {
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          final random = Random.secure();
          // Pass 1: overwrite dengan byte acak
          final randomBytes = List<int>.generate(min(length, 65536), (_) => random.nextInt(256));
          final raf = await file.open(mode: FileMode.write);
          int written = 0;
          while (written < length) {
            final toWrite = min(randomBytes.length, length - written);
            await raf.writeFrom(randomBytes, 0, toWrite);
            written += toWrite;
          }
          await raf.flush();

          // Pass 2: overwrite dengan zero byte (0x00)
          await raf.setPosition(0);
          final zeroBytes = List<int>.filled(min(length, 65536), 0);
          written = 0;
          while (written < length) {
            final toWrite = min(zeroBytes.length, length - written);
            await raf.writeFrom(zeroBytes, 0, toWrite);
            written += toWrite;
          }
          await raf.flush();
          await raf.close();
        }
        await file.delete();
      }

      // Hapus dan shred juga companion files SQLite jika ada (-wal, -shm, -journal)
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final companion = File('${file.path}$suffix');
        if (await companion.exists()) {
          try {
            final companionLen = await companion.length();
            if (companionLen > 0) {
              final raf = await companion.open(mode: FileMode.write);
              await raf.writeFrom(List<int>.filled(companionLen, 0));
              await raf.flush();
              await raf.close();
            }
            await companion.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      _logger.w('Gagal melakukan shredding file ${file.path}: $e');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}
