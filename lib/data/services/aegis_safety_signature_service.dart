import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';
import '../../src/rust/api/safety_signature.dart' as rust_sig;
import 'aegis_memory_guard_service.dart';
import 'aegis_shredder_service.dart';

/// Hasil pasangan kunci SOS (Anti-Spoofing Guardian Signature)
class SafetyKeyPair {
  /// ID slot memori aman di Aegis Memory Guard
  final BigInt keySlotId;

  /// Kunci publik Ed25519 (Base64) untuk verifikasi penerima / Guardian
  final String publicKeyB64;

  const SafetyKeyPair({
    required this.keySlotId,
    required this.publicKeyB64,
  });
}

/// Layanan penandatanganan dan verifikasi integritas paket darurat SOS (Aegis Safety Signature).
///
/// Menggunakan Ed25519 digital signature untuk mengamankan paket darurat dari serangan
/// modifikasi koordinat atau pemalsuan identitas (anti-spoofing). Private key disimpan
/// di dalam Aegis Memory Guard terisolasi dari heap GC.
class AegisSafetySignatureService {
  AegisSafetySignatureService._();
  static final AegisSafetySignatureService instance =
      AegisSafetySignatureService._();

  static final Logger _logger = Logger();
  static final Ed25519 _ed25519 = Ed25519();

  /// Membangun format string kanonikal dari paket darurat SOS.
  ///
  /// Format:
  /// `MEKAAR_SOS_V1:{senderId}:{isoTime}:{latitude}:{longitude}:{emergencyType}`
  static String buildCanonicalPayload({
    required String senderId,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    required String emergencyType,
  }) {
    final isoTime = timestamp.toUtc().toIso8601String();
    final latStr = latitude.toStringAsFixed(6);
    final lngStr = longitude.toStringAsFixed(6);
    return 'MEKAAR_SOS_V1:$senderId:$isoTime:$latStr:$lngStr:$emergencyType';
  }

  /// Menghasilkan pasangan kunci Ed25519 baru untuk pengirim SOS.
  /// Private key disimpan aman di Memory Guard (slotId).
  Future<SafetyKeyPair> generateKeyPair() async {
    await AegisShredderService.ensureInitialized();

    try {
      final res = await rust_sig.generateSosKeypair();
      return SafetyKeyPair(
        keySlotId: res.keySlotId,
        publicKeyB64: res.publicKeyB64,
      );
    } catch (e) {
      _logger.d('SafetySignature native tidak aktif, menggunakan Pure-Dart Fallback: $e');
      final keyPair = await _ed25519.newKeyPair();
      final seed = await keyPair.extractPrivateKeyBytes();
      final pubKey = await keyPair.extractPublicKey();

      final slotId = await AegisMemoryGuardService.instance.storeKey(seed);
      return SafetyKeyPair(
        keySlotId: slotId,
        publicKeyB64: base64Encode(pubKey.bytes),
      );
    }
  }

  /// Menandatangani paket data darurat kanonikal dengan Ed25519.
  /// Kunci privat ditarik langsung dari slot memori `keySlotId`.
  Future<String> signPayload({
    required String canonicalPayload,
    required BigInt keySlotId,
  }) async {
    await AegisShredderService.ensureInitialized();

    try {
      return await rust_sig.signSosPacket(
        canonicalPayload: canonicalPayload,
        keySlotId: keySlotId,
      );
    } catch (e) {
      _logger.d('Sign native tidak aktif, menggunakan Pure-Dart Fallback: $e');
      final rawKey = AegisMemoryGuardService.instance.getFallbackKey(keySlotId);
      if (rawKey == null) {
        throw StateError('Kunci rahasia untuk slot #$keySlotId tidak ditemukan di RAM');
      }

      final keyPair = await _ed25519.newKeyPairFromSeed(rawKey);
      final signature = await _ed25519.sign(
        utf8.encode(canonicalPayload),
        keyPair: keyPair,
      );
      return base64Encode(signature.bytes);
    }
  }

  /// Memverifikasi tanda tangan digital Ed25519 pada paket darurat kanonikal.
  /// Mengembalikan `true` jika tanda tangan valid dan tidak dimodifikasi.
  Future<bool> verifySignature({
    required String canonicalPayload,
    required String signatureB64,
    required String publicKeyB64,
  }) async {
    await AegisShredderService.ensureInitialized();

    try {
      return await rust_sig.verifySosPacket(
        canonicalPayload: canonicalPayload,
        signatureB64: signatureB64,
        publicKeyB64: publicKeyB64,
      );
    } catch (e) {
      _logger.d('Verify native tidak aktif, menggunakan Pure-Dart Fallback: $e');
      try {
        final pubKeyBytes = base64Decode(publicKeyB64);
        final sigBytes = base64Decode(signatureB64);

        if (pubKeyBytes.length != 32 || sigBytes.length != 64) {
          return false;
        }

        final publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);
        final signature = Signature(sigBytes, publicKey: publicKey);

        return await _ed25519.verify(
          utf8.encode(canonicalPayload),
          signature: signature,
        );
      } catch (_) {
        return false;
      }
    }
  }
}
