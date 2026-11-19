import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/storage/mekaar_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'aegis_memory_guard_service.dart';

/// Isolasi 3 jalur ruang Brankas Berkas berbasis mode PIN yang sedang aktif.
enum VaultSpace {
  master,
  guest,
  duress;

  String get dbFileName => switch (this) {
        VaultSpace.master => 'mekaar_vault.db',
        VaultSpace.guest => 'mekaar_vault_guest.db',
        VaultSpace.duress => 'mekaar_vault_decoy.db',
      };

  String get folderName => switch (this) {
        VaultSpace.master => 'master',
        VaultSpace.guest => 'guest',
        VaultSpace.duress => 'duress',
      };
}

/// Layanan terpusat untuk mengelola dan menurunkan kunci enkripsi database lokal (SQLCipher).
///
/// Menyediakan:
/// 1. Kunci acak 256-bit berbasis Hardware Keystore (`FlutterSecureStorage`) untuk database pesan.
/// 2. Kunci turunan KDF (Argon2id / legacy PBKDF2) dari PIN pengguna untuk brankas berkas 3 jalur.
/// 3. Pemusnahan forensik file (*secure shredding*) untuk file database dan WAL lama.
class DatabaseKeyService {
  DatabaseKeyService._();
  static final DatabaseKeyService instance = DatabaseKeyService._();

  static final Logger _logger = Logger();
  final FlutterSecureStorage _secureStorage = MekaarSecureStorage.instance;

  static const String _messageDbKeyStorageKey = 'sqlcipher_message_db_key_v1';
  static const String _decoyMessageDbKeyStorageKey = 'sqlcipher_decoy_message_db_key_v1';
  static const String _masterVaultSaltStorageKey = 'sqlcipher_vault_master_salt_v2';
  static const String _guestVaultSaltStorageKey = 'sqlcipher_vault_guest_salt_v2';
  static const String _decoyVaultSaltStorageKey = 'sqlcipher_vault_decoy_salt_v2';
  static const int _pbkdf2Iterations = 100000;

  /// Kunci runtime in-memory untuk brankas berkas yang dibuka saat ini
  String? _activeVaultKey;
  String? _activeLegacyVaultKey;
  VaultSpace _activeVaultSpace = VaultSpace.master;
  BigInt? _activeVaultKeySlotId;

  /// Slot ID kunci aktif di memori Aegis Memory Guard (Rust heap terisolasi).
  BigInt? get activeVaultKeySlotId => _activeVaultKeySlotId;

  static VaultSpace resolveVaultSpace({
    VaultSpace? space,
    bool isDuress = false,
  }) =>
      space ?? (isDuress ? VaultSpace.duress : VaultSpace.master);

  String _saltStorageKeyFor(VaultSpace space) => switch (space) {
        VaultSpace.master => _masterVaultSaltStorageKey,
        VaultSpace.guest => _guestVaultSaltStorageKey,
        VaultSpace.duress => _decoyVaultSaltStorageKey,
      };

  /// Mendapatkan salt acak 32-byte unik per perangkat dari Hardware Keystore.
  /// Mencegah serangan pre-computed rainbow table lintas perangkat.
  Future<List<int>> getOrCreateVaultSalt({
    bool isDuress = false,
    VaultSpace? space,
  }) async {
    final resolvedSpace = resolveVaultSpace(space: space, isDuress: isDuress);
    final storageKey = _saltStorageKeyFor(resolvedSpace);
    try {
      final existingB64 = await _secureStorage.read(key: storageKey);
      if (existingB64 != null && existingB64.isNotEmpty) {
        return base64Decode(existingB64);
      }
      final random = Random.secure();
      final salt = List<int>.generate(32, (_) => random.nextInt(256));
      await _secureStorage.write(key: storageKey, value: base64Encode(salt));
      return salt;
    } catch (e, st) {
      if (e is MissingPluginException) {
        _logger.w(
          'Platform secure storage tidak tersedia (MissingPluginException), memicu fallback: $e',
        );
      } else {
        _logger.e(
          'Gagal memuat atau membuat salt acak untuk brankas: $e',
          error: e,
          stackTrace: st,
        );
      }
      rethrow;
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

  /// Menurunkan kunci enkripsi 256-bit dari PIN pengguna menggunakan Argon2id
  /// dengan random salt unik per ruang brankas (v2).
  /// Mendukung fallback ke legacy PBKDF2 (v1) untuk auto-migrasi database lama.
  Future<String> deriveVaultKey(
    String pin, {
    bool isDuress = false,
    VaultSpace? space,
    bool forceLegacy = false,
    bool updateActiveSlot = true,
  }) async {
    final resolvedSpace = resolveVaultSpace(space: space, isDuress: isDuress);
    if (forceLegacy) {
      return deriveLegacyVaultKey(pin, space: resolvedSpace);
    }

    final derived = await _deriveArgon2KeyAndSlot(
      pin,
      space: resolvedSpace,
      assignActiveSlot: updateActiveSlot,
    );
    return derived.key;
  }

  /// Menurunkan pasangan kunci Argon2id + slot AegisMemoryGuard baru tanpa
  /// menimpa `_activeVaultKeySlotId` (digunakan saat rekey atomik brankas).
  Future<({String key, BigInt? slotId})> deriveVaultKeyForRekey(
    String pin, {
    required VaultSpace space,
  }) =>
      _deriveArgon2KeyAndSlot(
        pin,
        space: space,
        assignActiveSlot: false,
      );

  Future<({String key, BigInt? slotId})> _deriveArgon2KeyAndSlot(
    String pin, {
    required VaultSpace space,
    required bool assignActiveSlot,
  }) async {
    try {
      final salt = await getOrCreateVaultSalt(space: space);
      BigInt? slotId;
      try {
        slotId = await AegisMemoryGuardService.instance.deriveVaultKey(
          passcode: pin,
          salt: salt,
        );
        if (assignActiveSlot) {
          _activeVaultKeySlotId = slotId;
        }
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
      final hexKey = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return (key: hexKey, slotId: slotId);
    } catch (e) {
      _logger.w('Argon2id derivation gagal, fallback ke legacy: $e');
      final legacyKey = await deriveLegacyVaultKey(pin, space: space);
      return (key: legacyKey, slotId: null);
    }
  }

  /// Menurunkan kunci legacy PBKDF2 (100.000 iterasi) secara on-demand khusus untuk migrasi database lama.
  Future<String> deriveLegacyVaultKey(
    String pin, {
    bool isDuress = false,
    VaultSpace? space,
  }) async {
    final resolvedSpace = resolveVaultSpace(space: space, isDuress: isDuress);
    final hexKey = await _deriveLegacyVaultKey(pin, space: resolvedSpace);
    _activeLegacyVaultKey = hexKey;
    return hexKey;
  }

  Future<String> _deriveLegacyVaultKey(
    String pin, {
    required VaultSpace space,
  }) async {
    final saltPrefix = switch (space) {
      VaultSpace.master => 'mekaar_vault_master_salt_',
      VaultSpace.guest => 'mekaar_vault_guest_salt_',
      VaultSpace.duress => 'mekaar_vault_decoy_salt_',
    };
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
  void setActiveVaultKey(
    String key, {
    bool isDuress = false,
    VaultSpace? space,
    BigInt? slotId,
  }) {
    _activeVaultKey = key;
    _activeVaultSpace = resolveVaultSpace(space: space, isDuress: isDuress);
    if (slotId != null) {
      _activeVaultKeySlotId = slotId;
    }
  }

  /// Mendapatkan kunci aktif brankas saat ini.
  String? get activeVaultKey => _activeVaultKey;

  /// Kunci legacy yang diturunkan sementara untuk re-keying database lama
  String? get activeLegacyVaultKey => _activeLegacyVaultKey;

  /// Ruang brankas yang sedang aktif saat ini.
  VaultSpace get activeVaultSpace => _activeVaultSpace;

  /// Mengetahui apakah brankas yang sedang aktif adalah Decoy (Duress).
  bool get isVaultDuress => _activeVaultSpace == VaultSpace.duress;

  /// Mengetahui apakah brankas yang sedang aktif adalah Ruang Tamu (Guest).
  bool get isVaultGuest => _activeVaultSpace == VaultSpace.guest;

  /// Mengunci kembali brankas dan membersihkan kunci dari memori.
  Future<void> lockVault() async {
    _activeVaultKey = null;
    _activeLegacyVaultKey = null;
    _activeVaultSpace = VaultSpace.master;
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
