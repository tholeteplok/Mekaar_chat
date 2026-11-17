import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/data/models/group_skdm_models.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/group_e2ee_service.dart';
import 'package:mekaar_chat/data/services/group_key_distribution_service.dart';
import 'package:mekaar_chat/data/services/group_sender_key_store.dart';

/// Fake ChatRepository untuk mensimulasikan transmisi pesan 1:1 antar-pengguna dalam unit test
class FakeDirectChatRepository implements ChatRepository {
  final Map<String, List<Map<String, dynamic>>> deliveredDirectMessages = {};

  // Memetakan (userA, userB) ke roomId 1:1
  String _directRoomId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return 'direct_${sorted[0]}_${sorted[1]}';
  }

  @override
  Future<String> createRoom(
    String otherUserId,
    String type, {
    bool screenshotProtectionEnabled = true,
  }) async {
    return _directRoomId('test_current_user', otherUserId);
  }

  @override
  Future<Message> sendMessage(
    String roomId,
    String content, {
    String? mediaUrl,
    MessageType type = MessageType.text,
    bool isViewOnce = false,
    String? replyToId,
    DateTime? autoDeleteAt,
    bool isGroup = false,
  }) async {
    final list = deliveredDirectMessages.putIfAbsent(roomId, () => []);
    list.add({
      'content': content,
      'type': type,
      'roomId': roomId,
    });

    final now = DateTime.now();
    return Message(
      id: 'msg_fake_${now.millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: 'test_current_user',
      content: content,
      type: type,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySenderKeyStore aliceStore;
  late InMemorySenderKeyStore bobStore;
  late InMemorySenderKeyStore charlieStore;

  late GroupE2eeService aliceE2ee;
  late GroupE2eeService bobE2ee;
  late GroupE2eeService charlieE2ee;

  late FakeDirectChatRepository fakeRepo;
  late GroupKeyDistributionService aliceDistributor;
  late GroupKeyDistributionService bobDistributor;
  late GroupKeyDistributionService charlieDistributor;

  const testGroupId = 'group_room_security_101';
  const aliceId = 'usr_alice';
  const bobId = 'usr_bob';
  const charlieId = 'usr_charlie';

  setUp(() {
    aliceStore = InMemorySenderKeyStore();
    bobStore = InMemorySenderKeyStore();
    charlieStore = InMemorySenderKeyStore();

    aliceE2ee = GroupE2eeService(store: aliceStore);
    bobE2ee = GroupE2eeService(store: bobStore);
    charlieE2ee = GroupE2eeService(store: charlieStore);

    fakeRepo = FakeDirectChatRepository();

    aliceDistributor = GroupKeyDistributionService(
      groupE2eeService: aliceE2ee,
      chatRepository: fakeRepo,
      senderKeyStore: aliceStore,
    );
    bobDistributor = GroupKeyDistributionService(
      groupE2eeService: bobE2ee,
      chatRepository: fakeRepo,
      senderKeyStore: bobStore,
    );
    charlieDistributor = GroupKeyDistributionService(
      groupE2eeService: charlieE2ee,
      chatRepository: fakeRepo,
      senderKeyStore: charlieStore,
    );
  });

  group('SKDM & Request Model Serialization Tests', () {
    test('SenderKeyDistributionMessage serialization & canonical payload', () {
      final now = DateTime.utc(2026, 11, 18, 12, 0, 0);
      final chainKey = List.filled(32, 7);
      final pubKey = List.filled(32, 9);

      final skdm = SenderKeyDistributionMessage(
        version: 1,
        groupId: 'grp_test',
        senderId: 'usr_alice',
        keyId: 1,
        chainKey: chainKey,
        signingPublicKeyBytes: pubKey,
        createdAt: now,
        signatureB64: 'c2lnbmF0dXJl',
      );

      final jsonStr = skdm.toJsonString();
      final parsed = SenderKeyDistributionMessage.tryParse(jsonStr);

      expect(parsed, isNotNull);
      expect(parsed!.groupId, equals('grp_test'));
      expect(parsed.senderId, equals('usr_alice'));
      expect(parsed.keyId, equals(1));
      expect(parsed.chainKey, equals(chainKey));
      expect(parsed.signingPublicKeyBytes, equals(pubKey));
      expect(parsed.signatureB64, equals('c2lnbmF0dXJl'));
      expect(
        parsed.canonicalPayload,
        equals(
          'MEKAAR_SKDM_V1:grp_test:usr_alice:1:${base64Encode(chainKey)}:${base64Encode(pubKey)}:${now.toIso8601String()}',
        ),
      );
    });

    test('SenderKeyRequest serialization & parsing', () {
      final now = DateTime.utc(2026, 11, 18, 12, 30, 0);
      final req = SenderKeyRequest(
        groupId: 'grp_test',
        requesterId: 'usr_bob',
        targetSenderId: 'usr_alice',
        keyId: 2,
        requestedAt: now,
      );

      final jsonStr = req.toJsonString();
      final parsed = SenderKeyRequest.tryParse(jsonStr);

      expect(parsed, isNotNull);
      expect(parsed!.groupId, equals('grp_test'));
      expect(parsed.requesterId, equals('usr_bob'));
      expect(parsed.targetSenderId, equals('usr_alice'));
      expect(parsed.keyId, equals(2));
      expect(parsed.requestedAt, equals(now));
    });
  });

  group('SKDM Signing & Distribution Tests', () {
    test('Alice signs SKDM and Bob verifies & registers state successfully', () async {
      final aliceRecord = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      final skdm = await aliceDistributor.buildSignedSkdm(aliceRecord, aliceId);

      // Bob memproses SKDM
      final success = await bobDistributor.verifyAndProcessSkdm(
        skdm,
        expectedSenderId: aliceId,
      );
      expect(success, isTrue);

      // Verifikasi state Alice telah terdaftar di Bob
      final stateInBob = await bobStore.getSenderState(testGroupId, aliceId, 1);
      expect(stateInBob, isNotNull);
      expect(stateInBob!.chainKey, equals(aliceRecord.chainKey));
      expect(stateInBob.signingPublicKeyBytes, equals(aliceRecord.signingPublicKeyBytes));

      // Alice mengirim pesan terenkripsi, Bob dapat mendekripsinya
      final env = await aliceE2ee.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Halo Bob dari Alice via SKDM!',
      );

      final decrypted = await bobE2ee.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env,
      );
      expect(decrypted, equals('Halo Bob dari Alice via SKDM!'));
    });

    test('Tampered SKDM signature is rejected by receiver', () async {
      final aliceRecord = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      final skdm = await aliceDistributor.buildSignedSkdm(aliceRecord, aliceId);

      // Rusak satu byte tanda tangan
      final rawSig = base64Decode(skdm.signatureB64);
      rawSig[0] ^= 0xFF;
      final tamperedSkdm = SenderKeyDistributionMessage(
        version: skdm.version,
        groupId: skdm.groupId,
        senderId: skdm.senderId,
        keyId: skdm.keyId,
        chainKey: skdm.chainKey,
        signingPublicKeyBytes: skdm.signingPublicKeyBytes,
        createdAt: skdm.createdAt,
        signatureB64: base64Encode(rawSig),
      );

      final success = await bobDistributor.verifyAndProcessSkdm(
        tamperedSkdm,
        expectedSenderId: aliceId,
      );
      expect(success, isFalse);

      final stateInBob = await bobStore.getSenderState(testGroupId, aliceId, 1);
      expect(stateInBob, isNull);
    });
  });

  group('Membership Rekeying & Kick Exclusion Tests (§4.2)', () {
    test('Rekeying upon kick: Kicked member cannot decrypt subsequent messages', () async {
      // 1. Setup awal: Alice, Bob, Charlie dalam grup (keyId = 1)
      final initialRecord = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      final initialSkdm = await aliceDistributor.buildSignedSkdm(initialRecord, aliceId);

      await bobDistributor.verifyAndProcessSkdm(initialSkdm, expectedSenderId: aliceId);
      await charlieDistributor.verifyAndProcessSkdm(initialSkdm, expectedSenderId: aliceId);

      // Pesan 1: Bob dan Charlie sama-sama bisa baca
      final env1 = await aliceE2ee.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan awal untuk semua anggota',
      );
      expect(
        await bobE2ee.decryptGroupMessage(groupId: testGroupId, senderId: aliceId, envelope: env1),
        equals('Pesan awal untuk semua anggota'),
      );
      expect(
        await charlieE2ee.decryptGroupMessage(groupId: testGroupId, senderId: aliceId, envelope: env1),
        equals('Pesan awal untuk semua anggota'),
      );

      // 2. Charlie di-kick dari grup!
      // Alice melakukan Rekeying wajib ke sisa anggota (Bob saja)
      await aliceDistributor.rekeyGroupOnMembershipChange(
        groupId: testGroupId,
        currentUserId: aliceId,
        remainingMemberIds: [aliceId, bobId],
        excludedMemberId: charlieId,
      );

      // Ambil kunci baru Alice (keyId: 2)
      final newAliceRecord = await aliceStore.getOurSenderKey(testGroupId);
      expect(newAliceRecord, isNotNull);
      expect(newAliceRecord!.keyId, equals(2));

      // Bob menerima SKDM baru (keyId: 2)
      final rekeySkdm = await aliceDistributor.buildSignedSkdm(newAliceRecord, aliceId);
      await bobDistributor.verifyAndProcessSkdm(rekeySkdm, expectedSenderId: aliceId);

      // Charlie TIDAK menerima SKDM baru ini!

      // 3. Alice mengirim pesan baru pasca-kick
      final envPostKick = await aliceE2ee.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan rahasia setelah Charlie dikeluarkan!',
      );
      expect(envPostKick.keyId, equals(2));

      // Bob berhasil membaca pesan baru
      final bobDecrypted = await bobE2ee.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: envPostKick,
      );
      expect(bobDecrypted, equals('Pesan rahasia setelah Charlie dikeluarkan!'));

      // Charlie GAGAL membaca pesan baru (tidak punya keyId 2)
      expect(
        () => charlieE2ee.decryptGroupMessage(
          groupId: testGroupId,
          senderId: aliceId,
          envelope: envPostKick,
        ),
        throwsA(isA<GroupE2eeMissingSenderStateException>()),
      );
    });
  });

  group('Self-Healing & Resync Protocol Tests (§5.3)', () {
    test('Receiver without state requests key and successfully decrypts queued message', () async {
      // Alice menghasilkan sender key dan pesan
      final aliceRecord = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      final env = await aliceE2ee.encryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        plaintext: 'Pesan sebelum Bob sinkron',
      );

      // Bob belum punya state Alice (baru ganti HP / offline)
      expect(
        () => bobE2ee.decryptGroupMessage(
          groupId: testGroupId,
          senderId: aliceId,
          envelope: env,
        ),
        throwsA(isA<GroupE2eeMissingSenderStateException>()),
      );

      // Bob mengirim pesan kontrol sender_key_request
      final requestPayload = jsonEncode({
        'type': GroupKeyDistributionService.controlTypeSkRequest,
        'payload': SenderKeyRequest(
          groupId: testGroupId,
          requesterId: bobId,
          targetSenderId: aliceId,
          keyId: 1,
          requestedAt: DateTime.now().toUtc(),
        ).toJson(),
      });
      expect(requestPayload.isNotEmpty, isTrue);

      // Alice menerima request tersebut dan otomatis membalas SKDM
      final skdmGenerated = await aliceDistributor.buildSignedSkdm(aliceRecord, aliceId);
      final replyPayload = jsonEncode({
        'type': GroupKeyDistributionService.controlTypeSkdm,
        'payload': skdmGenerated.toJson(),
      });

      // Bob memproses pesan balasan dari Alice
      final handled = await bobDistributor.handleIncomingSystemControlMessage(
        senderId: aliceId,
        currentUserId: bobId,
        rawContent: replyPayload,
      );
      expect(handled, isTrue);

      // Bob sekarang bisa mendekripsi pesan yang tadinya tertunda!
      final decrypted = await bobE2ee.decryptGroupMessage(
        groupId: testGroupId,
        senderId: aliceId,
        envelope: env,
      );
      expect(decrypted, equals('Pesan sebelum Bob sinkron'));
    });
  });
}
