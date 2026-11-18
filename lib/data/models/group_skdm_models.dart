import 'dart:convert';

/// Model untuk paket Sender Key Distribution Message (SKDM).
///
/// Dikirimkan secara Store-and-Forward melalui kanal obrolan 1:1 terenkripsi E2EE
/// kepada setiap anggota grup. Memuat chain key awal dan kunci publik penandatangan Ed25519.
class SenderKeyDistributionMessage {
  final int version;
  final String groupId;
  final String senderId;
  final int keyId;
  final int counter;
  final List<int> chainKey;
  final List<int> signingPublicKeyBytes;
  final DateTime createdAt;
  final String signatureB64;

  const SenderKeyDistributionMessage({
    this.version = 1,
    required this.groupId,
    required this.senderId,
    required this.keyId,
    this.counter = 0,
    required this.chainKey,
    required this.signingPublicKeyBytes,
    required this.createdAt,
    required this.signatureB64,
  });

  /// Format kanonikal string untuk penandatanganan dan verifikasi Ed25519:
  /// `MEKAAR_SKDM_V1:{groupId}:{senderId}:{keyId}:{counter}:{chainKeyB64}:{pubKeyB64}:{isoTime}`
  static String buildCanonicalPayload({
    required String groupId,
    required String senderId,
    required int keyId,
    int counter = 0,
    required String chainKeyB64,
    required String signingPubKeyB64,
    required String isoTime,
  }) {
    return 'MEKAAR_SKDM_V1:$groupId:$senderId:$keyId:$counter:$chainKeyB64:$signingPubKeyB64:$isoTime';
  }

  /// String kanonikal data yang ditandatangani untuk SKDM ini
  String get canonicalPayload => buildCanonicalPayload(
        groupId: groupId,
        senderId: senderId,
        keyId: keyId,
        counter: counter,
        chainKeyB64: base64Encode(chainKey),
        signingPubKeyB64: base64Encode(signingPublicKeyBytes),
        isoTime: createdAt.toUtc().toIso8601String(),
      );

  Map<String, dynamic> toJson() {
    return {
      'v': version,
      'gid': groupId,
      'sid': senderId,
      'kid': keyId,
      'ctr': counter,
      'ck': base64Encode(chainKey),
      'spk': base64Encode(signingPublicKeyBytes),
      'cat': createdAt.toUtc().toIso8601String(),
      'sig': signatureB64,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SenderKeyDistributionMessage? tryParse(dynamic raw) {
    try {
      Map<String, dynamic> map;
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) return null;
        map = decoded;
      } else if (raw is Map<String, dynamic>) {
        map = raw;
      } else {
        return null;
      }

      if (map['v'] != 1) return null;

      final gid = map['gid'] as String?;
      final sid = map['sid'] as String?;
      final kid = (map['kid'] as num?)?.toInt();
      final ctr = (map['ctr'] as num?)?.toInt() ?? 0;
      final ck = map['ck'] as String?;
      final spk = map['spk'] as String?;
      final cat = map['cat'] as String?;
      final sig = map['sig'] as String?;

      if (gid == null ||
          sid == null ||
          kid == null ||
          kid <= 0 ||
          ctr < 0 ||
          ck == null ||
          spk == null ||
          cat == null ||
          sig == null) {
        return null;
      }

      return SenderKeyDistributionMessage(
        version: (map['v'] as num?)?.toInt() ?? 1,
        groupId: gid,
        senderId: sid,
        keyId: kid,
        counter: ctr,
        chainKey: base64Decode(ck),
        signingPublicKeyBytes: base64Decode(spk),
        createdAt: DateTime.parse(cat),
        signatureB64: sig,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Model untuk permintaan kunci ulang (resync / self-healing) saat state belum ada.
class SenderKeyRequest {
  final int version;
  final String groupId;
  final String requesterId;
  final String targetSenderId;
  final int keyId;
  final DateTime requestedAt;

  const SenderKeyRequest({
    this.version = 1,
    required this.groupId,
    required this.requesterId,
    required this.targetSenderId,
    required this.keyId,
    required this.requestedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'v': version,
      'type': 'sk_request',
      'gid': groupId,
      'req_id': requesterId,
      'target_id': targetSenderId,
      'kid': keyId,
      'rat': requestedAt.toUtc().toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static SenderKeyRequest? tryParse(dynamic raw) {
    try {
      Map<String, dynamic> map;
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) return null;
        map = decoded;
      } else if (raw is Map<String, dynamic>) {
        map = raw;
      } else {
        return null;
      }

      if (map['v'] != 1 || map['type'] != 'sk_request') return null;

      final gid = map['gid'] as String?;
      final reqId = map['req_id'] as String?;
      final targetId = map['target_id'] as String?;
      final kid = map['kid'] as int?;
      final rat = map['rat'] as String?;

      if (gid == null || reqId == null || targetId == null || kid == null || rat == null) {
        return null;
      }

      return SenderKeyRequest(
        version: map['v'] as int? ?? 1,
        groupId: gid,
        requesterId: reqId,
        targetSenderId: targetId,
        keyId: kid,
        requestedAt: DateTime.parse(rat),
      );
    } catch (_) {
      return null;
    }
  }
}
