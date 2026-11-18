import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/data/models/group_skdm_models.dart';
import 'package:mekaar_chat/data/models/message_model.dart';
import 'package:mekaar_chat/data/repositories/chat_repository.dart';
import 'package:mekaar_chat/data/services/group_e2ee_service.dart';
import 'package:mekaar_chat/data/services/group_key_distribution_service.dart';
import 'package:mekaar_chat/data/services/group_sender_key_store.dart';

class _FakeDirectRepo implements ChatRepository {
  final List<Map<String, dynamic>> sentMessages = [];

  @override
  Future<String> createRoom(
    String otherUserId,
    String type, {
    bool screenshotProtectionEnabled = true,
  }) async => 'direct_$otherUserId';

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
    sentMessages.add({
      'roomId': roomId,
      'content': content,
      'type': type,
    });
    final now = DateTime.now().toUtc();
    return Message(
      id: 'msg_${sentMessages.length}',
      roomId: roomId,
      senderId: 'alice',
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
  late String aliceIdPubB64;
  late _FakeDirectRepo fakeRepo;

  const groupId = 'grp_audit_001';
  const aliceId = 'alice';
  const bobId = 'bob';
  const charlieId = 'charlie';

  setUp(() async {
    aliceStore = InMemorySenderKeyStore();
    bobStore = InMemorySenderKeyStore();
    charlieStore = InMemorySenderKeyStore();

    final ed = Ed25519();
    final aliceKp = await ed.newKeyPairFromSeed(List.filled(32, 11));
    final bobKp = await ed.newKeyPairFromSeed(List.filled(32, 12));
    final charlieKp = await ed.newKeyPairFromSeed(List.filled(32, 13));

    aliceIdPubB64 = base64Encode((await aliceKp.extractPublicKey()).bytes);

    aliceE2ee = GroupE2eeService(store: aliceStore, initialIdentityKeyPair: aliceKp);
    bobE2ee = GroupE2eeService(store: bobStore, initialIdentityKeyPair: bobKp);
    charlieE2ee = GroupE2eeService(store: charlieStore, initialIdentityKeyPair: charlieKp);
    fakeRepo = _FakeDirectRepo();
  });

  group('Audit Security & Concurrency Mitigations', () {
    test('K2: 20 enkripsi & 20 dekripsi paralel tidak merusak ratchet counter', () async {
      final aliceDist = GroupKeyDistributionService(
        groupE2eeService: aliceE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: aliceStore,
        identityKeyResolver: (id) async => id == aliceId ? aliceIdPubB64 : null,
      );
      final bobDist = GroupKeyDistributionService(
        groupE2eeService: bobE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: bobStore,
        identityKeyResolver: (id) async => id == aliceId ? aliceIdPubB64 : null,
      );

      final record = await aliceE2ee.generateSenderKey(groupId, keyId: 1);
      final skdm = await aliceDist.buildSignedSkdm(record, aliceId);
      expect(await bobDist.verifyAndProcessSkdm(skdm, expectedSenderId: aliceId), isTrue);

      final envelopes = await Future.wait(
        List.generate(
          20,
          (i) => aliceE2ee.encryptGroupMessage(
            groupId: groupId,
            senderId: aliceId,
            plaintext: 'Pesan paralel #$i',
          ),
        ),
      );

      final counters = envelopes.map((e) => e.counter).toSet();
      expect(counters.length, equals(20));

      final decrypted = await Future.wait(
        envelopes.map(
          (env) => bobE2ee.decryptGroupMessage(
            groupId: groupId,
            senderId: aliceId,
            envelope: env,
          ),
        ),
      );

      for (int i = 0; i < 20; i++) {
        expect(decrypted, contains('Pesan paralel #$i'));
      }
    });

    test('T1: group_sk_request dari mantan anggota (kicked) atau spoofed ditolak fail-closed (PCS)', () async {
      final activeMembers = <String>{aliceId, bobId};

      final aliceDist = GroupKeyDistributionService(
        groupE2eeService: aliceE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: aliceStore,
        membershipVerifier: (gid, senderId, currentUserId) async =>
            gid == groupId &&
            activeMembers.contains(senderId) &&
            activeMembers.contains(currentUserId),
      );

      await aliceE2ee.generateSenderKey(groupId, keyId: 1);

      // 1. Mantan anggota (charlie) mencoba mencuri SKDM via group_sk_request
      final kickedReq = SenderKeyRequest(
        groupId: groupId,
        requesterId: charlieId,
        targetSenderId: aliceId,
        keyId: 1,
        requestedAt: DateTime.now().toUtc(),
      );
      final handledKicked = await aliceDist.handleIncomingSystemControlMessage(
        senderId: charlieId,
        currentUserId: aliceId,
        rawContent: jsonEncode({
          'type': GroupKeyDistributionService.controlTypeSkRequest,
          'payload': kickedReq.toJson(),
        }),
      );
      expect(handledKicked, isTrue);
      expect(fakeRepo.sentMessages, isEmpty);

      // 2. Pengirim mencoba spoofing requesterId milik bob
      final spoofedReq = SenderKeyRequest(
        groupId: groupId,
        requesterId: bobId,
        targetSenderId: aliceId,
        keyId: 1,
        requestedAt: DateTime.now().toUtc(),
      );
      final handledSpoofed = await aliceDist.handleIncomingSystemControlMessage(
        senderId: charlieId,
        currentUserId: aliceId,
        rawContent: jsonEncode({
          'type': GroupKeyDistributionService.controlTypeSkRequest,
          'payload': spoofedReq.toJson(),
        }),
      );
      expect(handledSpoofed, isTrue);
      expect(fakeRepo.sentMessages, isEmpty);

      // 3. Anggota sah (bob) mengirim request -> diizinkan
      final validReq = SenderKeyRequest(
        groupId: groupId,
        requesterId: bobId,
        targetSenderId: aliceId,
        keyId: 1,
        requestedAt: DateTime.now().toUtc(),
      );
      final handledValid = await aliceDist.handleIncomingSystemControlMessage(
        senderId: bobId,
        currentUserId: aliceId,
        rawContent: jsonEncode({
          'type': GroupKeyDistributionService.controlTypeSkRequest,
          'payload': validReq.toJson(),
        }),
      );
      expect(handledValid, isTrue);
      expect(fakeRepo.sentMessages.length, equals(1));
    });

    test('T2: Anggota baru bergabung di tengah percakapan (counter > 0) & proteksi anti-rollback SKDM', () async {
      final aliceDist = GroupKeyDistributionService(
        groupE2eeService: aliceE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: aliceStore,
        identityKeyResolver: (id) async => id == aliceId ? aliceIdPubB64 : null,
      );
      final charlieDist = GroupKeyDistributionService(
        groupE2eeService: charlieE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: charlieStore,
        identityKeyResolver: (id) async => id == aliceId ? aliceIdPubB64 : null,
      );

      // Alice mengirim 10 pesan sebelum Charlie bergabung (counter maju ke 10)
      for (int i = 0; i < 10; i++) {
        await aliceE2ee.encryptGroupMessage(
          groupId: groupId,
          senderId: aliceId,
          plaintext: 'Lama #$i',
        );
      }

      final currentRecord = await aliceStore.getOurSenderKey(groupId);
      expect(currentRecord!.counter, equals(10));

      // Alice membuat SKDM untuk anggota baru Charlie -> membawa counter: 10
      final skdmForCharlie = await aliceDist.buildSignedSkdm(currentRecord, aliceId);
      expect(skdmForCharlie.counter, equals(10));

      // Uji anti-tampering counter pada SKDM: mengubah ctr menjadi 0 membatalkan signature
      final tamperedJson = skdmForCharlie.toJson()..['ctr'] = 0;
      final tamperedSkdm = SenderKeyDistributionMessage.tryParse(tamperedJson)!;
      expect(
        await charlieDist.verifyAndProcessSkdm(tamperedSkdm, expectedSenderId: aliceId),
        isFalse,
      );

      // SKDM sah diterima Charlie
      expect(
        await charlieDist.verifyAndProcessSkdm(skdmForCharlie, expectedSenderId: aliceId),
        isTrue,
      );

      // Alice mengirim pesan ke-11 (counter 10) -> Charlie langsung bisa mendekripsi
      final msg11 = await aliceE2ee.encryptGroupMessage(
        groupId: groupId,
        senderId: aliceId,
        plaintext: 'Selamat datang Charlie!',
      );
      expect(msg11.counter, equals(10));
      final plain11 = await charlieE2ee.decryptGroupMessage(
        groupId: groupId,
        senderId: aliceId,
        envelope: msg11,
      );
      expect(plain11, equals('Selamat datang Charlie!'));

      // Replay SKDM basi (counter 10) tidak boleh me-rollback Charlie (sudah di counter 11)
      expect(
        await charlieDist.verifyAndProcessSkdm(skdmForCharlie, expectedSenderId: aliceId),
        isTrue,
      );
      final charlieState = await charlieStore.getSenderState(groupId, aliceId, 1);
      expect(charlieState!.counter, equals(11));
    });

    test('T2/O(0): distributeSenderKeyToGroupMembers melacak anggota yang sudah menerima keyId aktif', () async {
      final aliceDist = GroupKeyDistributionService(
        groupE2eeService: aliceE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: aliceStore,
      );

      await aliceDist.distributeSenderKeyToGroupMembers(
        groupId: groupId,
        currentUserId: aliceId,
        memberUserIds: [aliceId, bobId],
      );
      expect(fakeRepo.sentMessages.length, equals(1));

      // Pemanggilan ulang pada keyId sama ke anggota sama tidak mengirim pesan lagi
      await aliceDist.distributeSenderKeyToGroupMembers(
        groupId: groupId,
        currentUserId: aliceId,
        memberUserIds: [aliceId, bobId],
      );
      expect(fakeRepo.sentMessages.length, equals(1));

      // Anggota baru (charlie) masuk -> hanya mengirim ke charlie
      await aliceDist.distributeSenderKeyToGroupMembers(
        groupId: groupId,
        currentUserId: aliceId,
        memberUserIds: [aliceId, bobId, charlieId],
      );
      expect(fakeRepo.sentMessages.length, equals(2));
      expect(fakeRepo.sentMessages.last['roomId'], equals('direct_$charlieId'));
    });

    test('T3: clearAll dan clearSession menghapus seluruh jejak store & distributor', () async {
      await aliceStore.saveLastKnownMemberIds(groupId, [aliceId, bobId]);
      await aliceStore.markMembersDistributed(groupId, 1, [bobId]);
      await aliceE2ee.generateSenderKey(groupId, keyId: 1);

      await aliceStore.clearAll();
      aliceE2ee.clearSession();

      expect(await aliceStore.getOurSenderKey(groupId), isNull);
      expect(await aliceStore.getLastKnownMemberIds(groupId), isNull);
      expect(await aliceStore.getDistributedMemberIds(groupId, 1), isEmpty);
    });
  });
}
