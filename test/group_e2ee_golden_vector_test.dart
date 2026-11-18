import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/group_sender_key_models.dart';
import 'package:mekaar_chat/data/services/group_e2ee_service.dart';

List<int> _hexToBytes(String hex) {
  final result = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('Fase 2 Temuan 4: Pure Dart Signal Sender Keys Golden Protocol Vectors (Brief §10)', () {
    late Map<String, dynamic> fixture;
    late Hkdf hkdf;
    late Ed25519 ed25519;
    late Xchacha20 xchacha;

    setUpAll(() async {
      final file = File('test/fixtures/group_e2ee_test_vectors.json');
      final content = await file.readAsString();
      fixture = jsonDecode(content) as Map<String, dynamic>;

      hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      ed25519 = Ed25519();
      xchacha = Xchacha20.poly1305Aead();
    });

    test('1. Derivasi Rantai HKDF Counter 0-4 cocok byte-for-byte dengan Golden Vector', () async {
      final initialChainKey = _hexToBytes(fixture['initial_chain_key_hex'] as String);
      List<int> currentChainKey = initialChainKey;

      final derivations = fixture['chain_derivations'] as List;
      expect(derivations.length, equals(5));

      for (int i = 0; i < derivations.length; i++) {
        final d = derivations[i] as Map<String, dynamic>;
        final counter = d['counter'] as int;
        expect(counter, equals(i));

        // Verifikasi chain key saat ini
        expect(_bytesToHex(currentChainKey), equals(d['chain_key_hex']));

        // Turunkan message key menggunakan konstanta protokol resmi
        final msgSecretKey = await hkdf.deriveKey(
          secretKey: SecretKey(currentChainKey),
          info: utf8.encode(GroupE2eeService.infoMessageKey),
        );
        final msgKeyBytes = await msgSecretKey.extractBytes();
        expect(_bytesToHex(msgKeyBytes), equals(d['message_key_hex']));

        // Ratchet ke chain key berikutnya menggunakan konstanta protokol resmi
        final nextSecretKey = await hkdf.deriveKey(
          secretKey: SecretKey(currentChainKey),
          info: utf8.encode(GroupE2eeService.infoChainNext),
        );
        final nextKeyBytes = await nextSecretKey.extractBytes();
        expect(_bytesToHex(nextKeyBytes), equals(d['next_chain_key_hex']));

        currentChainKey = nextKeyBytes;
      }
    });

    test('2. Uji Kesengajaan (Fail-Fast): Modifikasi konstanta HKDF info pasti menggagalkan verifikasi vektor', () async {
      final initialChainKey = _hexToBytes(fixture['initial_chain_key_hex'] as String);

      // Sengaja ubah satu karakter pada info string ('mekaar-sk-msg' -> 'mekaar-sk-msg-tampered')
      final tamperedSecretKey = await hkdf.deriveKey(
        secretKey: SecretKey(initialChainKey),
        info: utf8.encode('mekaar-sk-msg-tampered'),
      );
      final tamperedBytes = await tamperedSecretKey.extractBytes();

      final expectedHex = (fixture['chain_derivations'] as List)[0]['message_key_hex'] as String;
      expect(_bytesToHex(tamperedBytes), isNot(equals(expectedHex)));
    });

    test('3. Ed25519 Deterministic Identity Signature cocok persis dengan Golden Vector', () async {
      final edVector = fixture['ed25519_vector'] as Map<String, dynamic>;
      final seed = _hexToBytes(edVector['seed_hex'] as String);

      final keyPair = await ed25519.newKeyPairFromSeed(seed);
      final pubKey = await keyPair.extractPublicKey();

      expect(_bytesToHex(pubKey.bytes), equals(edVector['public_key_hex']));
      expect(base64Encode(pubKey.bytes), equals(edVector['public_key_b64']));

      final payload = edVector['payload'] as String;
      final signature = await ed25519.sign(utf8.encode(payload), keyPair: keyPair);

      expect(base64Encode(signature.bytes), equals(edVector['signature_b64']));

      // Verifikasi kebalikan: tanda tangan sah diverifikasi dengan public key
      final isValid = await ed25519.verify(
        utf8.encode(payload),
        signature: Signature(signature.bytes, publicKey: pubKey),
      );
      expect(isValid, isTrue);
    });

    test('4. XChaCha20-Poly1305 Ciphertext + Poly1305 MAC cocok persis dengan Golden Vector', () async {
      final cVector = fixture['xchacha20_poly1305_vector'] as Map<String, dynamic>;
      final keyBytes = _hexToBytes(cVector['key_hex'] as String);
      final nonceBytes = _hexToBytes(cVector['nonce_hex'] as String);
      final aad = cVector['aad'] as String;
      final plaintext = cVector['plaintext'] as String;

      final secretBox = await xchacha.encrypt(
        utf8.encode(plaintext),
        secretKey: SecretKey(keyBytes),
        nonce: nonceBytes,
        aad: utf8.encode(aad),
      );

      final combined = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
      combined.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
      combined.setRange(secretBox.cipherText.length, combined.length, secretBox.mac.bytes);

      expect(base64Encode(combined), equals(cVector['ciphertext_combined_b64']));

      // Dekripsi ulang dan pastikan integritas pesan
      final decryptedBytes = await xchacha.decrypt(
        SecretBox(
          combined.sublist(0, combined.length - 16),
          nonce: nonceBytes,
          mac: Mac(combined.sublist(combined.length - 16)),
        ),
        secretKey: SecretKey(keyBytes),
        aad: utf8.encode(aad),
      );
      expect(utf8.decode(decryptedBytes), equals(plaintext));
    });

    test('5. Canonical AAD format matches Golden Vector expectation', () {
      final cVector = fixture['xchacha20_poly1305_vector'] as Map<String, dynamic>;
      final expectedAad = cVector['aad'] as String;

      final computedAad = GroupMessageEnvelope.buildCanonicalAad(
        groupId: 'group_golden',
        senderId: 'user_alice',
        keyId: 1,
        counter: 0,
        nonceB64: cVector['nonce_b64'] as String,
      );

      expect(computedAad, equals(expectedAad));
    });
  });
}
