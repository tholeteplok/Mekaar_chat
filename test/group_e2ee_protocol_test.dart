import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/data/models/group_sender_key_models.dart';
import 'package:mekaar_chat/data/services/group_e2ee_service.dart';
import 'package:mekaar_chat/data/services/group_sender_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySenderKeyStore aliceStore;
  late InMemorySenderKeyStore bobStore;
  late GroupE2eeService aliceService;
  late GroupE2eeService bobService;

  const testGroupId = 'group_room_secure_999';
  const aliceId = 'usr_alice_001';
  const bobId = 'usr_bob_002';

  setUp(() {
    aliceStore = InMemorySenderKeyStore();
    bobStore = InMemorySenderKeyStore();
    aliceService = GroupE2eeService(store: aliceStore);
    bobService = GroupE2eeService(store: bobStore);
  });

  group('GroupMessageEnvelope Model & Serialization Tests', () {
    test('Canonical AAD format matches RFC specification', () {
      final aad = GroupMessageEnvelope.buildCanonicalAad(
        groupId: 'grp_123',
        senderId: 'usr_456',
        keyId: 2,
        counter: 15,
        nonceB64: 'bm9uY2VfZXhhbXBsZQ==',
      );
      expect(
        aad,
        equals('MEKAAR_GRP_V1:grp_123:usr_456:2:15:bm9uY2VfZXhhbXBsZQ=='),
      );
    });

    test('JSON serialization and tryParse round-trip preserved identically', () {
      const envelope = GroupMessageEnvelope(
        version: 1,
        groupId: 'grp_test',
        senderId: 'usr_alice',
        keyId: 3,
        counter: 42,
        nonceB64: 'MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIz',
        ciphertextB64: 'Y2lwaGVydGV4dF9kYXRhX2hlcmU=',
        signatureB64: 'c2lnbmF0dXJlX2J5dGVzX2hlcmU=',
      );

      final jsonStr = envelope.toJsonString();
      final parsed = GroupMessageEnvelope.tryParse(jsonStr);

      expect(parsed, isNotNull);
      expect(parsed!.version, equals(1));
      expect(parsed.groupId, equals('grp_test'));
      expect(parsed.senderId, equals('usr_alice'));
      expect(parsed.keyId, equals(3));
      expect(parsed.counter, equals(42));
      expect(parsed.nonceB64, equals('MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIz'));
      expect(parsed.ciphertextB64, equals('Y2lwaGVydGV4dF9kYXRhX2hlcmU='));
      expect(parsed.signatureB64, equals('c2lnbmF0dXJlX2J5dGVzX2hlcmU='));
    });

    test('tryParse returns null on invalid or corrupted JSON', () {
      expect(GroupMessageEnvelope.tryParse('invalid_json'), isNull);
      expect(GroupMessageEnvelope.tryParse('{"v": 2}'), isNull);
      expect(GroupMessageEnvelope.tryParse('{"v": 1, "gid": "only_gid"}'), isNull);
    });
  });

  group('Group E2EE Sender Keys Protocol Tests (In-Order)', () {
    test('Alice sends 3 in-order messages and Bob decrypts them successfully', () async {
      // 1. Alice inisialisasi Sender Key aktif
      final aliceKey = await aliceService.generateSenderKey(testGroupId, keyId: 1);

      // 2. Bob mendaftarkan state Alice (seperti menerima SKDM via 1:1)
      await bobService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: aliceKey.keyId,
        chainKey: aliceKey.chainKey,
        signingPublicKeyBytes: aliceKey.signingPublicKeyBytes,
      );

      // 3. Alice enkripsi 3 pesan
      final env0 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan rahasia 1 dari Alice',
      );
      final env1 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan rahasia 2 dari Alice',
      );
      final env2 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan rahasia 3 dari Alice',
      );

      expect(env0.counter, equals(0));
      expect(env1.counter, equals(1));
      expect(env2.counter, equals(2));

      // 4. Bob dekripsi berurutan
      final dec0 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env0,
      );
      final dec1 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env1,
      );
      final dec2 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env2,
      );

      expect(dec0, equals('Pesan rahasia 1 dari Alice'));
      expect(dec1, equals('Pesan rahasia 2 dari Alice'));
      expect(dec2, equals('Pesan rahasia 3 dari Alice'));
    });

    test('Two-way group chat: Bob replies back to Alice and Alice decrypts successfully', () async {
      // 1. Bob inisialisasi Sender Key aktif miliknya
      final bobKey = await bobService.generateSenderKey(testGroupId, keyId: 1);

      // 2. Alice daftarkan state Bob
      await aliceService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: bobId,
        keyId: bobKey.keyId,
        chainKey: bobKey.chainKey,
        signingPublicKeyBytes: bobKey.signingPublicKeyBytes,
      );

      // 3. Bob enkripsi balasan
      final replyEnv = await bobService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: bobId,
        plaintext: 'Siap Alice, pesan diterima aman!',
      );

      // 4. Alice dekripsi pesan Bob
      final decReply = await aliceService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: bobId,
        envelope: replyEnv,
      );

      expect(decReply, equals('Siap Alice, pesan diterima aman!'));
    });
  });

  group('Out-of-Order Delivery & Forward Secrecy Skipped Keys Tests', () {
    test('Bob receives messages out-of-order and resolves skipped keys cleanly', () async {
      final aliceKey = await aliceService.generateSenderKey(testGroupId, keyId: 1);

      await bobService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: aliceKey.keyId,
        chainKey: aliceKey.chainKey,
        signingPublicKeyBytes: aliceKey.signingPublicKeyBytes,
      );

      // Alice menghasilkan 5 pesan (counter 0, 1, 2, 3, 4)
      final env0 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan #0',
      );
      final env1 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan #1',
      );
      final env2 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan #2',
      );
      final env3 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan #3',
      );
      final env4 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan #4',
      );

      // Urutan kedatangan di Bob: #0 -> #3 (melompati 1 dan 2) -> #1 -> #2 -> #4
      final dec0 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env0,
      );
      expect(dec0, equals('Pesan #0'));

      // Pesan #3 tiba: Bob meratchet forward, menyimpan kunci #1 & #2 ke skipped keys
      final dec3 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env3,
      );
      expect(dec3, equals('Pesan #3'));

      final skippedCount = await bobStore.getSkippedKeyCount(testGroupId, aliceId, 1);
      expect(skippedCount, equals(2)); // kunci #1 dan #2 tersimpan

      // Pesan #1 tiba belakangan
      final dec1 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env1,
      );
      expect(dec1, equals('Pesan #1'));

      // Pesan #2 tiba belakangan
      final dec2 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env2,
      );
      expect(dec2, equals('Pesan #2'));

      // Seluruh skipped keys telah dikonsumsi dan dihapus
      final remainingSkipped = await bobStore.getSkippedKeyCount(testGroupId, aliceId, 1);
      expect(remainingSkipped, equals(0));

      // Pesan #4 tiba berurutan dari counter 4
      final dec4 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env4,
      );
      expect(dec4, equals('Pesan #4'));
    });

    test('Replay attack fails: cannot decrypt the same message twice', () async {
      final aliceKey = await aliceService.generateSenderKey(testGroupId, keyId: 1);

      await bobService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: aliceKey.keyId,
        chainKey: aliceKey.chainKey,
        signingPublicKeyBytes: aliceKey.signingPublicKeyBytes,
      );

      final env0 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan Satu Kali',
      );
      final env1 = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan Kedua',
      );

      // Bob dekripsi #1 (melompati #0)
      await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env1,
      );

      // Bob dekripsi #0 pertama kali (berhasil dan kunci #0 dihapus)
      final dec0 = await bobService.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env0,
      );
      expect(dec0, equals('Pesan Satu Kali'));

      // Penyerang mencoba memutar ulang (replay) paket #0 untuk kedua kalinya
      expect(
        () => bobService.decryptGroupMessage(
          groupId: testGroupId,
          senderId: aliceId,
          envelope: env0,
        ),
        throwsA(isA<GroupE2eeReplayOrMissingKeyException>()),
      );
    });
  });

  group('Cryptographic Tamper Resistance & Hard Limits', () {
    test('Ed25519 signature verification fails when ciphertext is tampered', () async {
      final aliceKey = await aliceService.generateSenderKey(testGroupId, keyId: 1);

      await bobService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: aliceKey.keyId,
        chainKey: aliceKey.chainKey,
        signingPublicKeyBytes: aliceKey.signingPublicKeyBytes,
      );

      final env = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Data Sensitif',
      );

      // Ubah satu byte di ciphertext
      final rawCipher = base64Decode(env.ciphertextB64);
      rawCipher[0] ^= 0xFF;
      final tamperedEnv = GroupMessageEnvelope(
        version: env.version,
        groupId: env.groupId,
        senderId: env.senderId,
        keyId: env.keyId,
        counter: env.counter,
        nonceB64: env.nonceB64,
        ciphertextB64: base64Encode(rawCipher),
        signatureB64: env.signatureB64,
      );

      expect(
        () => bobService.decryptGroupMessage(
          groupId: testGroupId,
          senderId: aliceId,
          envelope: tamperedEnv,
        ),
        throwsA(isA<GroupE2eeSignatureException>()),
      );
    });

    test('AAD tampering fails: attacker modifies metadata header', () async {
      final aliceKey = await aliceService.generateSenderKey(testGroupId, keyId: 1);

      await bobService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: aliceKey.keyId,
        chainKey: aliceKey.chainKey,
        signingPublicKeyBytes: aliceKey.signingPublicKeyBytes,
      );

      final env = await aliceService.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Data Sensitif',
      );

      // Penyerang memodifikasi counter pada envelope
      final tamperedEnv = GroupMessageEnvelope(
        version: env.version,
        groupId: env.groupId,
        senderId: env.senderId,
        keyId: env.keyId,
        counter: env.counter + 1, // Diubah!
        nonceB64: env.nonceB64,
        ciphertextB64: env.ciphertextB64,
        signatureB64: env.signatureB64,
      );

      expect(
        () => bobService.decryptGroupMessage(
          groupId: testGroupId,
          senderId: aliceId,
          envelope: tamperedEnv,
        ),
        throwsA(isA<GroupE2eeSignatureException>()),
      );
    });

    test('Lompatan counter > MAX_SKIPPED_KEYS ditolak dengan aman (anti-OOM)', () async {
      final aliceKey = await aliceService.generateSenderKey(testGroupId, keyId: 1);

      await bobService.registerSenderKeyState(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: aliceKey.keyId,
        chainKey: aliceKey.chainKey,
        signingPublicKeyBytes: aliceKey.signingPublicKeyBytes,
      );

      // Pasang envelope buatan yang menuntut counter melompat 1005 (di atas batas 1000)
      // Tanda tangan valid dengan pasangan kunci Alice
      final aad = GroupMessageEnvelope.buildCanonicalAad(
        groupId: testGroupId,
        senderId: aliceId,
        keyId: 1,
        counter: 1005,
        nonceB64: base64Encode(List.filled(24, 0)),
      );
      final dummyCipher = base64Encode(List.filled(32, 1));
      final sig = await Ed25519().sign(
        utf8.encode('$aad:$dummyCipher'),
        keyPair: aliceKey.signingKeyPair,
      );

      final maliciousEnv = GroupMessageEnvelope(
        version: 1,
        groupId: testGroupId,
        senderId: aliceId,
        keyId: 1,
        counter: 1005,
        nonceB64: base64Encode(List.filled(24, 0)),
        ciphertextB64: dummyCipher,
        signatureB64: base64Encode(sig.bytes),
      );

      expect(
        () => bobService.decryptGroupMessage(
          groupId: testGroupId,
          senderId: aliceId,
          envelope: maliciousEnv,
        ),
        throwsA(isA<GroupE2eeMaxSkippedKeysExceededException>()),
      );
    });

    test('Mendekripsi pesan dari pengirim tanpa state memicu GroupE2eeMissingSenderStateException', () async {
      const dummyEnv = GroupMessageEnvelope(
        version: 1,
        groupId: testGroupId,
        senderId: 'usr_charlie_stranger',
        keyId: 1,
        counter: 0,
        nonceB64: 'bm9uY2U=',
        ciphertextB64: 'Y2lwaGVy',
        signatureB64: 'c2ln',
      );

      expect(
        () => bobService.decryptGroupMessage(
          groupId: testGroupId,
          senderId: 'usr_charlie_stranger',
          envelope: dummyEnv,
        ),
        throwsA(isA<GroupE2eeMissingSenderStateException>()),
      );
    });
  });
}
