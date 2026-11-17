import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';

import '../models/group_sender_key_models.dart';
import '../models/group_skdm_models.dart';
import '../models/message_model.dart';
import '../repositories/chat_repository.dart';
import 'group_e2ee_service.dart';
import 'group_sender_key_store.dart';
import 'supabase_service.dart';

/// Service untuk orkestrasi distribusi Sender Key Distribution Message (SKDM),
/// penanganan rekeying otomatis saat perubahan keanggotaan grup, serta mekanisme
/// self-healing request key antar-anggota grup.
class GroupKeyDistributionService {
  GroupKeyDistributionService({
    GroupE2eeService? groupE2eeService,
    ChatRepository? chatRepository,
    SenderKeyStore? senderKeyStore,
  })  : _groupE2eeService = groupE2eeService ?? GroupE2eeService.instance,
        _chatRepository = chatRepository ?? ChatRepository(SupabaseService()),
        _senderKeyStore = senderKeyStore ?? SqlCipherSenderKeyStore.instance;

  static final GroupKeyDistributionService instance =
      GroupKeyDistributionService();

  static final Logger _logger = Logger();
  static final Ed25519 _ed25519 = Ed25519();

  final GroupE2eeService _groupE2eeService;
  final ChatRepository _chatRepository;
  final SenderKeyStore _senderKeyStore;

  /// Tipe payload kontrol sistem untuk distribusi sender key
  static const String controlTypeSkdm = 'group_skdm';

  /// Tipe payload kontrol sistem untuk permintaan kunci ulang (resync)
  static const String controlTypeSkRequest = 'group_sk_request';

  /// Membangun dan menandatangani paket SKDM dari sebuah SenderKeyRecord milik kita.
  Future<SenderKeyDistributionMessage> buildSignedSkdm(
    SenderKeyRecord record,
    String senderId,
  ) async {
    final now = DateTime.now().toUtc();
    final canonical = SenderKeyDistributionMessage.buildCanonicalPayload(
      groupId: record.groupId,
      senderId: senderId,
      keyId: record.keyId,
      chainKeyB64: base64Encode(record.chainKey),
      signingPubKeyB64: base64Encode(record.signingPublicKeyBytes),
      isoTime: now.toIso8601String(),
    );

    final signature = await _ed25519.sign(
      utf8.encode(canonical),
      keyPair: record.signingKeyPair,
    );

    return SenderKeyDistributionMessage(
      version: 1,
      groupId: record.groupId,
      senderId: senderId,
      keyId: record.keyId,
      chainKey: record.chainKey,
      signingPublicKeyBytes: record.signingPublicKeyBytes,
      createdAt: now,
      signatureB64: base64Encode(signature.bytes),
    );
  }

  /// Memverifikasi tanda tangan digital Ed25519 dan mendaftarkan state pengirim ke GroupE2eeService.
  /// Mengembalikan `true` jika valid dan berhasil didaftarkan.
  Future<bool> verifyAndProcessSkdm(
    SenderKeyDistributionMessage skdm, {
    required String expectedSenderId,
  }) async {
    if (skdm.senderId != expectedSenderId) {
      _logger.w('SKDM senderId (${skdm.senderId}) tidak cocok dengan pengirim 1:1 ($expectedSenderId)');
      return false;
    }

    try {
      final pubKey = SimplePublicKey(
        skdm.signingPublicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final sigBytes = base64Decode(skdm.signatureB64);
      if (sigBytes.length != 64) {
        _logger.w('Panjang tanda tangan SKDM tidak valid');
        return false;
      }

      final isValid = await _ed25519.verify(
        utf8.encode(skdm.canonicalPayload),
        signature: Signature(sigBytes, publicKey: pubKey),
      );

      if (!isValid) {
        _logger.w('Tanda tangan digital SKDM dari ${skdm.senderId} tidak valid!');
        return false;
      }

      // Daftarkan ke engine GroupE2eeService
      await _groupE2eeService.registerSenderKeyState(
        groupId: skdm.groupId,
        senderId: skdm.senderId,
        keyId: skdm.keyId,
        chainKey: skdm.chainKey,
        signingPublicKeyBytes: skdm.signingPublicKeyBytes,
        counter: 0,
      );

      _logger.i('SKDM dari ${skdm.senderId} berhasil diverifikasi & didaftarkan untuk grup ${skdm.groupId}');
      return true;
    } catch (e) {
      _logger.e('Gagal memproses SKDM: $e');
      return false;
    }
  }

  /// Mendistribusikan sender key aktif kita ke seluruh anggota grup via kanal 1:1 E2EE.
  /// Anggota yang sedang offline akan menerima pesan ini saat kembali online (Store-and-Forward).
  Future<void> distributeSenderKeyToGroupMembers({
    required String groupId,
    required String currentUserId,
    required List<String> memberUserIds,
  }) async {
    final ourRecord = await _groupE2eeService.getOrGenerateOurSenderKey(groupId);
    final skdm = await buildSignedSkdm(ourRecord, currentUserId);
    final controlPayload = jsonEncode({
      'type': controlTypeSkdm,
      'payload': skdm.toJson(),
    });

    for (final memberId in memberUserIds) {
      if (memberId == currentUserId) continue;

      try {
        // Dapatkan atau buat kanal obrolan 1:1 langsung
        final directRoomId = await _chatRepository.createRoom(memberId, 'normal');

        // Kirim sebagai pesan sistem terenkripsi E2EE 1:1
        await _chatRepository.sendMessage(
          directRoomId,
          controlPayload,
          type: MessageType.system,
          isGroup: false,
        );
        _logger.d('SKDM terkirim ke anggota $memberId untuk grup $groupId');
      } catch (e) {
        _logger.w('Gagal mendistribusikan SKDM ke anggota $memberId: $e');
      }
    }
  }

  /// Meminta kunci ulang (resync / self-healing) ke pengirim spesifik saat dekripsi pesan tertunda.
  Future<void> requestSenderKeyFromMember({
    required String groupId,
    required String currentUserId,
    required String targetSenderId,
    required int keyId,
  }) async {
    final request = SenderKeyRequest(
      groupId: groupId,
      requesterId: currentUserId,
      targetSenderId: targetSenderId,
      keyId: keyId,
      requestedAt: DateTime.now().toUtc(),
    );

    final controlPayload = jsonEncode({
      'type': controlTypeSkRequest,
      'payload': request.toJson(),
    });

    try {
      final directRoomId = await _chatRepository.createRoom(targetSenderId, 'normal');
      await _chatRepository.sendMessage(
        directRoomId,
        controlPayload,
        type: MessageType.system,
        isGroup: false,
      );
      _logger.i('sender_key_request dikirim ke $targetSenderId untuk grup $groupId (keyId: $keyId)');
    } catch (e) {
      _logger.e('Gagal mengirim sender_key_request ke $targetSenderId: $e');
    }
  }

  /// Menangani pesan sistem kontrol 1:1 masuk (SKDM atau sender_key_request) secara otomatis.
  /// Mengembalikan `true` jika pesan berhasil diidentifikasi dan ditangani sebagai kontrol E2EE grup.
  Future<bool> handleIncomingSystemControlMessage({
    required String senderId,
    required String currentUserId,
    required String rawContent,
  }) async {
    try {
      final map = jsonDecode(rawContent);
      if (map is! Map<String, dynamic>) return false;

      final type = map['type'] as String?;
      final payload = map['payload'];

      if (type == controlTypeSkdm) {
        final skdm = SenderKeyDistributionMessage.tryParse(payload);
        if (skdm == null) return false;
        return await verifyAndProcessSkdm(skdm, expectedSenderId: senderId);
      } else if (type == controlTypeSkRequest) {
        final req = SenderKeyRequest.tryParse(payload);
        if (req == null) return false;
        if (req.targetSenderId != currentUserId) return false;

        // Requester meminta kunci aktif kita untuk grup tersebut
        final ourRecord = await _groupE2eeService.getOrGenerateOurSenderKey(req.groupId);
        final skdmReply = await buildSignedSkdm(ourRecord, currentUserId);
        final replyPayload = jsonEncode({
          'type': controlTypeSkdm,
          'payload': skdmReply.toJson(),
        });

        final directRoomId = await _chatRepository.createRoom(senderId, 'normal');
        await _chatRepository.sendMessage(
          directRoomId,
          replyPayload,
          type: MessageType.system,
          isGroup: false,
        );
        _logger.i('Auto-reply SKDM dikirimkan balik ke $senderId untuk grup ${req.groupId}');
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Menjalankan Rekeying Wajib saat ada anggota yang keluar atau dikeluarkan (Kick) dari grup.
  /// Sesuai §4.2:
  /// - Sender key lama dimusnahkan.
  /// - Kunci baru (keyId + 1) dibuat.
  /// - State anggota yang dikeluarkan dibersihkan dari DB lokal.
  /// - Sender key baru didistribusikan HANYA kepada anggota yang tersisa.
  Future<void> rekeyGroupOnMembershipChange({
    required String groupId,
    required String currentUserId,
    required List<String> remainingMemberIds,
    String? excludedMemberId,
  }) async {
    _logger.i('Memulai Rekeying grup $groupId akibat perubahan keanggotaan...');

    // 1. Ambil keyId terakhir
    final existingKey = await _senderKeyStore.getOurSenderKey(groupId);
    final nextKeyId = (existingKey?.keyId ?? 0) + 1;

    // 2. Generate sender key baru dengan keyId bertambah
    final newRecord = await _groupE2eeService.generateSenderKey(
      groupId,
      keyId: nextKeyId,
    );

    // 3. Jika ada anggota yang dikeluarkan, hapus seluruh state pengirim miliknya
    if (excludedMemberId != null && excludedMemberId.isNotEmpty) {
      // Hapus state pengirim yang di-kick agar tidak ada relasi kripto lama
      for (int k = 1; k <= nextKeyId; k++) {
        await _senderKeyStore.deleteSenderState(groupId, excludedMemberId, k);
      }
      _logger.d('State sender key untuk anggota tereksklusi $excludedMemberId dihapus');
    }

    // 4. Distribusikan kunci baru HANYA ke sisa anggota yang sah
    final skdm = await buildSignedSkdm(newRecord, currentUserId);
    final controlPayload = jsonEncode({
      'type': controlTypeSkdm,
      'payload': skdm.toJson(),
    });

    for (final memberId in remainingMemberIds) {
      if (memberId == currentUserId || memberId == excludedMemberId) continue;

      try {
        final directRoomId = await _chatRepository.createRoom(memberId, 'normal');
        await _chatRepository.sendMessage(
          directRoomId,
          controlPayload,
          type: MessageType.system,
          isGroup: false,
        );
      } catch (e) {
        _logger.w('Gagal mengirim rekey SKDM ke $memberId: $e');
      }
    }

    _logger.i('Rekeying grup $groupId selesai (KeyId baru: $nextKeyId)');
  }
}
