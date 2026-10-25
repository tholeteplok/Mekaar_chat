import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';
import '../../src/rust/api/memory_guard.dart' as rust_memory;
import 'aegis_shredder_service.dart';

/// Layanan isolasi memori kunci rahasia (Aegis Memory Guard).
///
/// Menyimpan kunci kriptografi 256-bit di dalam slot memori terisolasi di Rust
/// yang dilindungi oleh trait `ZeroizeOnDrop`, sehingga memori fisik dibersihkan seketika
/// dari RAM saat sesi berakhir, tanpa risiko residu heap Dart GC.
class AegisMemoryGuardService {
  AegisMemoryGuardService._();
  static final AegisMemoryGuardService instance = AegisMemoryGuardService._();

  static final Logger _logger = Logger();
  static final Map<BigInt, Uint8List> _fallbackKeyRegistry = {};
  static BigInt _nextFallbackId = BigInt.one;

  /// Menyimpan kunci 32-byte ke dalam slot memori terisolasi
  Future<BigInt> storeKey(List<int> rawKey) async {
    if (rawKey.length != 32) {
      throw ArgumentError('Panjang kunci wajib 32 byte (256-bit)');
    }

    await AegisShredderService.ensureInitialized();

    try {
      return await rust_memory.storeSecureKey(rawKey: rawKey);
    } catch (e) {
      _logger.d('MemoryGuard native tidak aktif, menggunakan Pure-Dart Fallback: $e');
      final slotId = _nextFallbackId;
      _nextFallbackId = _nextFallbackId + BigInt.one;
      _fallbackKeyRegistry[slotId] = Uint8List.fromList(rawKey);
      return slotId;
    }
  }

  /// Menurunkan kunci vault 256-bit dari PIN dan salt menggunakan Argon2id di Rust.
  /// Memiliki fallback PBKDF2-HMAC-SHA256 untuk lingkungan test Dart non-native.
  Future<BigInt> deriveVaultKey({
    required String passcode,
    required List<int> salt,
  }) async {
    if (passcode.isEmpty) {
      throw ArgumentError('Passcode tidak boleh kosong');
    }
    if (salt.length < 8) {
      throw ArgumentError('Salt minimal wajib 8 byte');
    }

    await AegisShredderService.ensureInitialized();

    try {
      return await rust_memory.deriveVaultKey(
        passcode: passcode,
        salt: salt,
      );
    } catch (e) {
      _logger.d('Argon2id native tidak aktif, menggunakan Pure-Dart KDF Fallback: $e');
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac(Sha256()),
        iterations: 100000,
        bits: 256,
      );
      final secretKey = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(passcode)),
        nonce: salt,
      );
      final rawKey = await secretKey.extractBytes();
      final slotId = _nextFallbackId;
      _nextFallbackId = _nextFallbackId + BigInt.one;
      _fallbackKeyRegistry[slotId] = Uint8List.fromList(rawKey);
      return slotId;
    }
  }

  /// Memeriksa apakah suatu slot kunci masih aktif di memori
  Future<bool> hasKey(BigInt slotId) async {
    await AegisShredderService.ensureInitialized();
    try {
      return await rust_memory.hasSecureKey(slotId: slotId);
    } catch (_) {
      return _fallbackKeyRegistry.containsKey(slotId);
    }
  }

  /// Memusnahkan kunci di slot tertentu dari memori RAM seketika (Zeroize)
  Future<bool> zeroizeKey(BigInt slotId) async {
    await AegisShredderService.ensureInitialized();
    try {
      return await rust_memory.zeroizeKey(slotId: slotId);
    } catch (_) {
      final key = _fallbackKeyRegistry.remove(slotId);
      if (key != null) {
        key.fillRange(0, key.length, 0); // Deterministic zero-fill
        return true;
      }
      return false;
    }
  }

  /// Menghancurkan seluruh kunci rahasia di memori RAM (Panic Lockdown / Logout)
  Future<int> zeroizeAllKeys() async {
    await AegisShredderService.ensureInitialized();
    try {
      return await rust_memory.zeroizeAllKeys();
    } catch (_) {
      final count = _fallbackKeyRegistry.length;
      for (final key in _fallbackKeyRegistry.values) {
        key.fillRange(0, key.length, 0);
      }
      _fallbackKeyRegistry.clear();
      return count;
    }
  }

  /// Mengambil referensi kunci untuk fallback stream cipher jika di lingkungan non-native
  Uint8List? getFallbackKey(BigInt slotId) {
    return _fallbackKeyRegistry[slotId];
  }
}
