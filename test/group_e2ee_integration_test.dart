import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/group_skdm_models.dart';
import 'package:mekaar_chat/data/services/group_e2ee_service.dart';
import 'package:mekaar_chat/data/services/group_key_distribution_service.dart';
import 'package:mekaar_chat/data/services/group_sender_key_store.dart';

void main() {
  group('Fase 2 Sub-Fase 2C: Group E2EE Chat Integration Tests', () {
    late InMemorySenderKeyStore aliceStore;
    late InMemorySenderKeyStore bobStore;
    late GroupE2eeService aliceCrypto;
    late GroupE2eeService bobCrypto;

    const String roomId = 'room_safety_group_001';
    const String aliceId = 'usr_alice_001';
    const String bobId = 'usr_bob_002';

    setUp(() {
      aliceStore = InMemorySenderKeyStore();
      bobStore = InMemorySenderKeyStore();

      aliceCrypto = GroupE2eeService(store: aliceStore);
      bobCrypto = GroupE2eeService(store: bobStore);
    });

    test('Skenario 1: Enkripsi pesan grup menghasilkan ciphertext JSON valid (v1)', () async {
      const plaintext = 'Halo tim keselamatan MEKAAR!';

      // Alice mengenkripsi pesan grup
      final envelope = await aliceCrypto.encryptGroupMessage(
        groupId: roomId,
        senderId: aliceId,
        plaintext: plaintext,
      );

      expect(envelope.keyId, equals(1));
      expect(envelope.counter, equals(0));
      expect(envelope.ciphertextB64.isNotEmpty, isTrue);
      expect(envelope.signatureB64.isNotEmpty, isTrue);

      final envelopeJson = envelope.toJsonString();
      final decodedMap = jsonDecode(envelopeJson) as Map<String, dynamic>;
      expect(decodedMap['v'], equals(1));
      expect(decodedMap['kid'], equals(1));
    });

    test('Skenario 2: Bob gagal dekripsi jika belum punya SKDM (pendingKeySentinel)', () async {
      const plaintext = 'Pesan rahasia tim';
      final envelope = await aliceCrypto.encryptGroupMessage(
        groupId: roomId,
        senderId: aliceId,
        plaintext: plaintext,
      );

      // Bob belum menerima SKDM Alice
      expect(
        () async => await bobCrypto.decryptGroupMessage(
          groupId: roomId,
          senderId: aliceId,
          envelopeJson: envelope.toJsonString(),
        ),
        throwsA(isA<GroupE2eeMissingSenderStateException>()),
      );
    });

    test('Skenario 3: Alur SKDM Store-and-Forward memulihkan kemampuan dekripsi Bob', () async {
      const plaintext = 'Pesan rahasia tim';

      // 1. Alice buat sender key dan kirim pesan
      final aliceRecord = await aliceCrypto.getOrGenerateOurSenderKey(roomId);
      final envelope = await aliceCrypto.encryptGroupMessage(
        groupId: roomId,
        senderId: aliceId,
        plaintext: plaintext,
      );

      // 2. Alice memaketkan SKDM bertanda tangan Ed25519
      final distService = GroupKeyDistributionService(
        groupE2eeService: aliceCrypto,
        senderKeyStore: aliceStore,
      );
      final skdm = await distService.buildSignedSkdm(aliceRecord, aliceId);

      // 3. Bob menerima dan memverifikasi SKDM Alice
      final bobDistService = GroupKeyDistributionService(
        groupE2eeService: bobCrypto,
        senderKeyStore: bobStore,
      );
      final verified = await bobDistService.verifyAndProcessSkdm(
        skdm,
        expectedSenderId: aliceId,
      );
      expect(verified, isTrue);

      // 4. Bob mendekripsi pesan grup Alice
      final decrypted = await bobCrypto.decryptGroupMessage(
        groupId: roomId,
        senderId: aliceId,
        envelopeJson: envelope.toJsonString(),
      );

      expect(decrypted, equals(plaintext));

      // 5. Verifikasi Bob membalas obrolan balik ke grup
      final bobRecord = await bobCrypto.getOrGenerateOurSenderKey(roomId);
      final bobSkdm = await bobDistService.buildSignedSkdm(bobRecord, bobId);
      final aliceVerifiedBob = await distService.verifyAndProcessSkdm(
        bobSkdm,
        expectedSenderId: bobId,
      );
      expect(aliceVerifiedBob, isTrue);

      final bobEnvelope = await bobCrypto.encryptGroupMessage(
        groupId: roomId,
        senderId: bobId,
        plaintext: 'Siap diterima, aman!',
      );
      final aliceDecryptedBob = await aliceCrypto.decryptGroupMessage(
        groupId: roomId,
        senderId: bobId,
        envelopeJson: bobEnvelope.toJsonString(),
      );
      expect(aliceDecryptedBob, equals('Siap diterima, aman!'));
    });

    test('Skenario 4: Format payload pesan kontrol sistem SKDM dan SK Request', () {
      final sampleSkdm = SenderKeyDistributionMessage(
        version: 1,
        groupId: roomId,
        senderId: aliceId,
        keyId: 1,
        chainKey: List.filled(32, 1),
        signingPublicKeyBytes: List.filled(32, 2),
        createdAt: DateTime.now().toUtc(),
        signatureB64: base64Encode(List.filled(64, 3)),
      );

      final skdmJson = jsonEncode({
        'type': GroupKeyDistributionService.controlTypeSkdm,
        'payload': sampleSkdm.toJson(),
      });

      final parsed = jsonDecode(skdmJson) as Map<String, dynamic>;
      expect(parsed['type'], equals('group_skdm'));
      final skdm = SenderKeyDistributionMessage.tryParse(parsed['payload']);
      expect(skdm, isNotNull);
      expect(skdm!.groupId, equals(roomId));
      expect(skdm.senderId, equals(aliceId));

      final sampleReq = SenderKeyRequest(
        version: 1,
        groupId: roomId,
        requesterId: bobId,
        targetSenderId: aliceId,
        keyId: 1,
        requestedAt: DateTime.now().toUtc(),
      );

      final reqJson = jsonEncode({
        'type': GroupKeyDistributionService.controlTypeSkRequest,
        'payload': sampleReq.toJson(),
      });

      final parsedReq = jsonDecode(reqJson) as Map<String, dynamic>;
      expect(parsedReq['type'], equals('group_sk_request'));
      final req = SenderKeyRequest.tryParse(parsedReq['payload']);
      expect(req, isNotNull);
      expect(req!.targetSenderId, equals(aliceId));
      expect(req.requesterId, equals(bobId));
    });

    test('Skenario 5: Verifikasi sentinel helper pada GroupE2eeService', () {
      expect(
        GroupE2eeService.isPendingKey(GroupE2eeService.pendingKeySentinel),
        isTrue,
      );
      expect(
        GroupE2eeService.isPendingKey('Pesan biasa'),
        isFalse,
      );
      expect(
        GroupE2eeService.isUndecryptable(GroupE2eeService.undecryptableSentinel),
        isTrue,
      );
      expect(
        GroupE2eeService.isUndecryptable(GroupE2eeService.pendingKeySentinel),
        isTrue,
      );
      expect(
        GroupE2eeService.isUndecryptable('Pesan normal'),
        isFalse,
      );
    });
  });
}
