import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mekaar_chat/data/models/group_sender_key_models.dart';
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

  late String aliceIdentityKeyB64;
  late String bobIdentityKeyB64;
  late String charlieIdentityKeyB64;

  const testGroupId = 'group_room_security_101';
  const aliceId = 'usr_alice';
  const bobId = 'usr_bob';
  const charlieId = 'usr_charlie';

  setUp(() async {
    aliceStore = InMemorySenderKeyStore();
    bobStore = InMemorySenderKeyStore();
    charlieStore = InMemorySenderKeyStore();

    final ed25519 = Ed25519();
    final aliceIdentityKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 1));
    final bobIdentityKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 2));
    final charlieIdentityKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 3));

    aliceIdentityKeyB64 = base64Encode((await aliceIdentityKeyPair.extractPublicKey()).bytes);
    bobIdentityKeyB64 = base64Encode((await bobIdentityKeyPair.extractPublicKey()).bytes);
    charlieIdentityKeyB64 = base64Encode((await charlieIdentityKeyPair.extractPublicKey()).bytes);

    aliceE2ee = GroupE2eeService(store: aliceStore, initialIdentityKeyPair: aliceIdentityKeyPair);
    bobE2ee = GroupE2eeService(store: bobStore, initialIdentityKeyPair: bobIdentityKeyPair);
    charlieE2ee = GroupE2eeService(store: charlieStore, initialIdentityKeyPair: charlieIdentityKeyPair);

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

    aliceDistributor.cacheUserIdentityKey(aliceId, aliceIdentityKeyB64);
    aliceDistributor.cacheUserIdentityKey(bobId, bobIdentityKeyB64);
    aliceDistributor.cacheUserIdentityKey(charlieId, charlieIdentityKeyB64);

    bobDistributor.cacheUserIdentityKey(aliceId, aliceIdentityKeyB64);
    bobDistributor.cacheUserIdentityKey(bobId, bobIdentityKeyB64);
    bobDistributor.cacheUserIdentityKey(charlieId, charlieIdentityKeyB64);

    charlieDistributor.cacheUserIdentityKey(aliceId, aliceIdentityKeyB64);
    charlieDistributor.cacheUserIdentityKey(bobId, bobIdentityKeyB64);
    charlieDistributor.cacheUserIdentityKey(charlieId, charlieIdentityKeyB64);
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
          'MEKAAR_SKDM_V1:grp_test:usr_alice:1:0:${base64Encode(chainKey)}:${base64Encode(pubKey)}:${now.toIso8601String()}',
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

  group('Temuan 1: SKDM Signing & Identity Verification Tests (Brief §3.2, D1)', () {
    test('Alice signs SKDM with Identity Key and Bob verifies & registers state successfully', () async {
      final aliceRecord = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      final skdm = await aliceDistributor.buildSignedSkdm(aliceRecord, aliceId);

      // Bob memproses SKDM menggunakan identity key Alice yang terpercaya
      final success = await bobDistributor.verifyAndProcessSkdm(
        skdm,
        expectedSenderId: aliceId,
        expectedSenderIdentityKeyB64: aliceIdentityKeyB64,
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

    test('Uji Negatif 1: SKDM dengan senderId Alice tetapi ditandatangani kunci identitas penyerang DITOLAK', () async {
      final aliceRecord = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);

      // Penyerang (Mallory) menandatangani SKDM dengan kunci identitas penyerang
      final attackerKey = await Ed25519().newKeyPair();
      final attackerSkdm = await aliceDistributor.buildSignedSkdm(
        aliceRecord,
        aliceId,
        identityKeyPair: attackerKey,
      );

      // Bob memverifikasi terhadap identity key Alice yang asli
      final success = await bobDistributor.verifyAndProcessSkdm(
        attackerSkdm,
        expectedSenderId: aliceId,
        expectedSenderIdentityKeyB64: aliceIdentityKeyB64,
      );

      // Wajib ditolak!
      expect(success, isFalse);
      final stateInBob = await bobStore.getSenderState(testGroupId, aliceId, 1);
      expect(stateInBob, isNull);
    });

    test('Uji Negatif 2: SKDM dengan tanda tangan rusak / tampered DITOLAK', () async {
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
        expectedSenderIdentityKeyB64: aliceIdentityKeyB64,
      );
      expect(success, isFalse);

      final stateInBob = await bobStore.getSenderState(testGroupId, aliceId, 1);
      expect(stateInBob, isNull);
    });

    test('Uji Persistensi: Ed25519 Identity Key identik sebelum dan sesudah reload proses', () async {
      // Mock storage lokal
      FlutterSecureStorage.setMockInitialValues({});

      final service1 = GroupE2eeService();
      final pubKey1 = await service1.getIdentityPublicKey(userId: 'test_persist_user');
      expect(pubKey1.length, equals(32));

      // Simulasikan restart proses: buat instance baru tanpa in-memory cache
      final service2 = GroupE2eeService();
      final pubKey2 = await service2.getIdentityPublicKey(userId: 'test_persist_user');

      // Kunci publik sebelum dan sesudah restart harus IDENTIK
      expect(base64Encode(pubKey1), equals(base64Encode(pubKey2)));
    });
  });

  group('Temuan 2: Rekeying Pengamat Pasif saat Membership Shrink (Brief §4.2)', () {
    test('Pengamat pasif (Bob) otomatis rekeying saat Charlie di-kick oleh Alice', () async {
      // 1. Inisialisasi awal: Alice, Bob, Charlie saling bertukar kunci
      final aliceRec1 = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      final bobRec1 = await bobE2ee.generateSenderKey(testGroupId, keyId: 1);

      await bobDistributor.verifyAndProcessSkdm(
        await aliceDistributor.buildSignedSkdm(aliceRec1, aliceId),
        expectedSenderId: aliceId,
        expectedSenderIdentityKeyB64: aliceIdentityKeyB64,
      );
      await charlieDistributor.verifyAndProcessSkdm(
        await bobDistributor.buildSignedSkdm(bobRec1, bobId),
        expectedSenderId: bobId,
        expectedSenderIdentityKeyB64: bobIdentityKeyB64,
      );

      // Pesan awal dari Bob: Charlie bisa baca
      final msg1 = await bobE2ee.encryptGroupMessage(
        groupId: testGroupId,
        senderId: bobId,
        plaintext: 'Pesan awal Bob untuk semua',
      );
      expect(
        await charlieE2ee.decryptGroupMessage(groupId: testGroupId, senderId: bobId, envelope: msg1),
        equals('Pesan awal Bob untuk semua'),
      );

      // Inisialisasi keanggotaan awal untuk Bob: [Alice, Bob, Charlie]
      await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId, charlieId],
      );

      // 2. Alice mengeluarkan Charlie (Kick).
      // Bob sebagai pengamat pasif mendeteksi anggota berkurang menjadi [Alice, Bob]
      final rekeyed = await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId],
      );
      expect(rekeyed, isTrue);

      // Kunci Bob sekarang harus naik ke keyId = 2
      final newBobRecord = await bobStore.getOurSenderKey(testGroupId);
      expect(newBobRecord, isNotNull);
      expect(newBobRecord!.keyId, equals(2));

      // Bob mengirim pesan baru setelah kick
      final msgPostKick = await bobE2ee.encryptGroupMessage(
        groupId: testGroupId,
        senderId: bobId,
        plaintext: 'Pesan rahasia Bob setelah Charlie di-kick!',
      );
      expect(msgPostKick.keyId, equals(2));

      // Charlie TIDAK memiliki keyId = 2 milik Bob, gagal mendekripsi!
      expect(
        () => charlieE2ee.decryptGroupMessage(
          groupId: testGroupId,
          senderId: bobId,
          envelope: msgPostKick,
        ),
        throwsA(isA<GroupE2eeMissingSenderStateException>()),
      );
    });

    test('Pengamat pasif (Bob & Alice) otomatis rekeying saat Charlie keluar sukarela (Leave)', () async {
      await aliceDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: aliceId,
        currentMemberIds: [aliceId, bobId, charlieId],
      );
      await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId, charlieId],
      );

      // Charlie keluar sukarela -> sisa [aliceId, bobId]
      final aliceRekeyed = await aliceDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: aliceId,
        currentMemberIds: [aliceId, bobId],
      );
      final bobRekeyed = await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId],
      );

      expect(aliceRekeyed, isTrue);
      expect(bobRekeyed, isTrue);
    });

    test('Uji Idempotensi: Penyegaran daftar anggota berulang tanpa perubahan tidak memicu rekey tambahan', () async {
      await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId],
      );

      // Panggilan kedua dengan anggota yang sama persis
      final secondCall = await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId],
      );
      expect(secondCall, isFalse);

      // Panggilan ketiga
      final thirdCall = await bobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: [aliceId, bobId],
      );
      expect(thirdCall, isFalse);
    });
  });

  group('Temuan 3: Pemicu Rotasi Berkala Sender Key (Brief §4.4, D3)', () {
    test('needsKeyRotation returns true when counter >= 5000', () {
      final now = DateTime.now().toUtc();
      final freshRecord = SenderKeyRecord(
        groupId: 'grp_1',
        keyId: 1,
        chainKey: List.filled(32, 1),
        signingKeyPair: SimpleKeyPairData([], publicKey: SimplePublicKey([], type: KeyPairType.ed25519), type: KeyPairType.ed25519),
        signingPublicKeyBytes: List.filled(32, 2),
        counter: 4999,
        createdAt: now,
        updatedAt: now,
      );

      expect(GroupE2eeService.needsKeyRotation(freshRecord), isFalse);

      final expiredCounterRecord = freshRecord.copyWith(counter: 5000);
      expect(GroupE2eeService.needsKeyRotation(expiredCounterRecord), isTrue);
    });

    test('needsKeyRotation returns true when key age >= 30 days', () {
      final thirtyOneDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 31));
      final oldRecord = SenderKeyRecord(
        groupId: 'grp_1',
        keyId: 1,
        chainKey: List.filled(32, 1),
        signingKeyPair: SimpleKeyPairData([], publicKey: SimplePublicKey([], type: KeyPairType.ed25519), type: KeyPairType.ed25519),
        signingPublicKeyBytes: List.filled(32, 2),
        counter: 10,
        createdAt: thirtyOneDaysAgo,
        updatedAt: thirtyOneDaysAgo,
      );

      expect(GroupE2eeService.needsKeyRotation(oldRecord), isTrue);
    });

    test('rotateAndDistributeSenderKey advances keyId and resets counter', () async {
      final initialRec = await aliceE2ee.generateSenderKey(testGroupId, keyId: 1);
      expect(initialRec.keyId, equals(1));

      // Picu rotasi
      final rotated = await aliceDistributor.rotateAndDistributeSenderKey(
        groupId: testGroupId,
        currentUserId: aliceId,
        memberUserIds: [aliceId, bobId],
      );

      expect(rotated.keyId, equals(2));
      expect(rotated.counter, equals(0));
    });
  });

  group('Self-Healing & Resync Protocol Tests (§5.3)', () {
    test('Receiver without state requests key and successfully decrypts queued message', () async {
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

      // Bob menerima SKDM melalui pesan balasan self-healing
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

  group('Fase 2 Sisa A & B: Identity Re-fetch & Persistent Membership Tracker', () {
    test('Sisa A: Auto re-fetch kunci identitas dari profil saat pengirim berganti perangkat (cache invalidated & reverified)', () async {
      final ed25519 = Ed25519();
      final aliceOldKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 1));
      final aliceOldPubB64 = base64Encode((await aliceOldKeyPair.extractPublicKey()).bytes);

      final aliceNewKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 77));
      final aliceNewPubB64 = base64Encode((await aliceNewKeyPair.extractPublicKey()).bytes);

      // Database mock profil di server
      final mockProfiles = <String, String>{
        aliceId: aliceNewPubB64, // Profil di server sudah diperbarui ke kunci baru
      };

      final customBobStore = InMemorySenderKeyStore();
      final customBobE2ee = GroupE2eeService(
        store: customBobStore,
        initialIdentityKeyPair: await ed25519.newKeyPairFromSeed(List.filled(32, 2)),
      );

      final customBobDistributor = GroupKeyDistributionService(
        groupE2eeService: customBobE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: customBobStore,
        identityKeyResolver: (userId) async => mockProfiles[userId],
      );

      // Simulasikan Bob masih menyimpan cache kunci LAMA Alice dari sesi sebelumnya
      customBobDistributor.cacheUserIdentityKey(aliceId, aliceOldPubB64);

      // Alice (di HP baru) membuat sender key dan menandatangani SKDM dengan kunci identitas baru
      final aliceNewE2ee = GroupE2eeService(
        store: InMemorySenderKeyStore(),
        initialIdentityKeyPair: aliceNewKeyPair,
      );
      final aliceNewDistributor = GroupKeyDistributionService(
        groupE2eeService: aliceNewE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: InMemorySenderKeyStore(),
      );

      final newRecord = await aliceNewE2ee.generateSenderKey(testGroupId, keyId: 5);
      final newSkdm = await aliceNewDistributor.buildSignedSkdm(newRecord, aliceId);

      // Bob memproses SKDM dari Alice HP baru
      // Langkah: Verifikasi cache K1 gagal -> auto invalidate -> fetch K2 dari mockProfiles -> reverify sukses!
      final success = await customBobDistributor.verifyAndProcessSkdm(
        newSkdm,
        expectedSenderId: aliceId,
      );

      expect(success, isTrue);

      final registeredState = await customBobStore.getSenderState(testGroupId, aliceId, 5);
      expect(registeredState, isNotNull);
      expect(registeredState!.keyId, equals(5));
    });

    test('Sisa A (Negatif): Penyerang dengan kunci liar tetap ditolak setelah re-fetch (fail-closed)', () async {
      final ed25519 = Ed25519();
      final aliceValidKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 1));
      final aliceValidPubB64 = base64Encode((await aliceValidKeyPair.extractPublicKey()).bytes);

      final attackerKeyPair = await ed25519.newKeyPairFromSeed(List.filled(32, 99));

      final mockProfiles = <String, String>{
        aliceId: aliceValidPubB64,
      };

      final customBobStore = InMemorySenderKeyStore();
      final customBobE2ee = GroupE2eeService(
        store: customBobStore,
        initialIdentityKeyPair: await ed25519.newKeyPairFromSeed(List.filled(32, 2)),
      );

      final customBobDistributor = GroupKeyDistributionService(
        groupE2eeService: customBobE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: customBobStore,
        identityKeyResolver: (userId) async => mockProfiles[userId],
      );

      // Mallory mencoba menandatangani SKDM Alice dengan kuncinya sendiri
      final attackerE2ee = GroupE2eeService(
        store: InMemorySenderKeyStore(),
        initialIdentityKeyPair: attackerKeyPair,
      );
      final attackerDistributor = GroupKeyDistributionService(
        groupE2eeService: attackerE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: InMemorySenderKeyStore(),
      );

      final forgedRecord = await attackerE2ee.generateSenderKey(testGroupId, keyId: 1);
      final forgedSkdm = await attackerDistributor.buildSignedSkdm(forgedRecord, aliceId);

      final success = await customBobDistributor.verifyAndProcessSkdm(
        forgedSkdm,
        expectedSenderId: aliceId,
      );

      // Verifikasi awal & re-fetch terhadap profil Alice tetap gagal
      expect(success, isFalse);
      final registered = await customBobStore.getSenderState(testGroupId, aliceId, 1);
      expect(registered, isNull);
    });

    test('Sisa B: Penanda persisten di SenderKeyStore mendeteksi penyusutan anggota saat aplikasi offline/tertutup', () async {
      final customBobStore = InMemorySenderKeyStore();
      final ed25519 = Ed25519();
      final customBobE2ee = GroupE2eeService(
        store: customBobStore,
        initialIdentityKeyPair: await ed25519.newKeyPairFromSeed(List.filled(32, 2)),
      );

      // Simulasikan state sebelum aplikasi ditutup: Bob punya sender key dan penanda persisten {Alice, Bob, Charlie}
      await customBobE2ee.generateSenderKey(testGroupId, keyId: 1);
      await customBobStore.saveLastKnownMemberIds(testGroupId, [aliceId, bobId, charlieId]);

      // Buat state dummy untuk Charlie di storage Bob
      await customBobStore.saveSenderState(
        SenderKeyState(
          groupId: testGroupId,
          senderId: charlieId,
          keyId: 1,
          chainKey: List.filled(32, 3),
          signingPublicKeyBytes: List.filled(32, 3),
          counter: 0,
          updatedAt: DateTime.now(),
        ),
      );

      expect(await customBobStore.getSenderState(testGroupId, charlieId, 1), isNotNull);

      // Aplikasi Bob dibuka kembali (instans baru dengan in-memory cache KOSONG)
      final newBobDistributor = GroupKeyDistributionService(
        groupE2eeService: customBobE2ee,
        chatRepository: fakeRepo,
        senderKeyStore: customBobStore,
      );

      // Pengambilan daftar anggota saat ini dari server: Charlie sudah tidak ada (dikeluarkan saat Bob offline)
      final currentMembers = [aliceId, bobId];

      final rekeyed = await newBobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: currentMembers,
      );

      // Harus terdeteksi menyusut dan melakukan rekeying!
      expect(rekeyed, isTrue);

      // State Charlie harus terhapus dari storage Bob
      final charlieStateAfter = await customBobStore.getSenderState(testGroupId, charlieId, 1);
      expect(charlieStateAfter, isNull);

      // Sender key Bob harus naik ke keyId 2
      final newOurKey = await customBobStore.getOurSenderKey(testGroupId);
      expect(newOurKey!.keyId, equals(2));

      // Penanda persisten di database lokal harus terupdate ke {Alice, Bob}
      final persistedMembers = await customBobStore.getLastKnownMemberIds(testGroupId);
      expect(persistedMembers, equals([aliceId, bobId]));

      // Pemanggilan kedua dengan daftar yang sama bersifat idempoten (tidak rekey lagi)
      final secondCheck = await newBobDistributor.checkAndRekeyIfMembershipShrunk(
        groupId: testGroupId,
        currentUserId: bobId,
        currentMemberIds: currentMembers,
      );
      expect(secondCheck, isFalse);
    });
  });
}
