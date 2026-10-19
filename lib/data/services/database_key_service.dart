import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _messageDbKeyStorageKey = 'sqlcipher_message_db_key_v1';
  static const int _pbkdf2Iterations = 100000;

  /// Kunci runtime in-memory untuk brankas berkas yang dibuka saat ini
  String? _activeVaultKey;
  bool _isVaultDuress = false;

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

  /// Menurunkan kunci enkripsi 256-bit dari PIN pengguna menggunakan PBKDF2.
  /// Membedakan salt antara Master PIN dan Duress PIN agar derivasi kunci terpisah total.
  Future<String> deriveVaultKey(String pin, {required bool isDuress}) async {
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

  /// Mengetahui apakah brankas yang sedang aktif adalah Decoy (Duress).
  bool get isVaultDuress => _isVaultDuress;

  /// Mengunci kembali brankas dan membersihkan kunci dari memori.
  void lockVault() {
    _activeVaultKey = null;
    _isVaultDuress = false;
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
