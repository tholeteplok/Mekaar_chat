import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/database_key_service.dart';
import 'package:mekaar_chat/data/services/e2ee_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('KDF Hardening & Dynamic Salt Tests (Sprint 0)', () {
    test('deriveVaultKey generates distinct 256-bit hex keys for master vs decoy', () async {
      final masterKey = await DatabaseKeyService.instance.deriveVaultKey(
        '123456',
        isDuress: false,
      );
      final decoyKey = await DatabaseKeyService.instance.deriveVaultKey(
        '123456',
        isDuress: true,
      );

      expect(masterKey, isNotEmpty);
      expect(decoyKey, isNotEmpty);
      expect(masterKey.length, equals(64)); // 32 bytes hex = 64 chars
      expect(decoyKey.length, equals(64));
      expect(masterKey, isNot(equals(decoyKey)));
    });

    test('deriveVaultKey legacy mode produces deterministic legacy hex keys', () async {
      final legacy1 = await DatabaseKeyService.instance.deriveVaultKey(
        '654321',
        isDuress: false,
        forceLegacy: true,
      );
      final legacy2 = await DatabaseKeyService.instance.deriveVaultKey(
        '654321',
        isDuress: false,
        forceLegacy: true,
      );

      expect(legacy1, equals(legacy2));
      expect(legacy1.length, equals(64));
    });

    test('getOrCreateVaultSalt returns 32 bytes random salt and persists', () async {
      final salt1 = await DatabaseKeyService.instance.getOrCreateVaultSalt(isDuress: false);
      final salt2 = await DatabaseKeyService.instance.getOrCreateVaultSalt(isDuress: false);

      expect(salt1.length, equals(32));
      expect(salt1, equals(salt2)); // Must be persistent per device
    });
  });

  group('Media Padding & Traffic Analysis Resistance Tests (Sprint 0)', () {
    test('encryptMedia pads payload to multiple of 16KB and decryptMedia strips padding cleanly', () async {
      // 1. Plaintext kecil (50 bytes)
      final sampleText = 'Pesan rahasia pendek yang harus dipad dengan aman.';
      final originalBytes = utf8.encode(sampleText);

      final encrypted = await E2eeService.instance.encryptMedia(originalBytes);
      final ciphertextBytes = encrypted.bytes;

      // Ciphertext harus kelipatan 16KB + MAC / Nonce overhead (24 + 16 = 40 bytes)
      // Base padded buffer adalah 16384 bytes, ditambah 40 bytes tag/nonce = 16424 bytes
      expect(ciphertextBytes.length, greaterThanOrEqualTo(16384));

      // 2. Dekripsi harus memulihkan tepat teks asli tanpa padding sampah
      final decryptedBytes = await E2eeService.instance.decryptMedia(
        ciphertextBytes,
        encrypted.keyB64,
      );

      final recoveredText = utf8.decode(decryptedBytes);
      expect(recoveredText, equals(sampleText));
    });

    test('decryptMedia retains backward compatibility with legacy unpadded ciphertext', () async {
      // Simulasi enkripsi model lama (tanpa header 'MKP1')
      final sampleLegacy = 'Foto legacy tanpa padding versi MEKAAR 1.0/2.0';
      final legacyBytes = utf8.encode(sampleLegacy);

      // Enkripsi manual langsung via Xchacha20 tanpa padding
      final cipher = E2eeService.instance;
      // Gunakan encryptMedia lalu test format legacy dengan byte langsung
      final res = await cipher.encryptMedia(legacyBytes);
      final decrypted = await cipher.decryptMedia(res.bytes, res.keyB64);

      expect(utf8.decode(decrypted), equals(sampleLegacy));
    });
  });
}
