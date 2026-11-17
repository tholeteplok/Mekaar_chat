import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Model untuk sender key aktif milik akun lokal di suatu grup obrolan.
class SenderKeyRecord {
  /// ID ruang obrolan grup
  final String groupId;

  /// Versi monoton naik dari sender key (bertambah setiap rekey/rotasi)
  final int keyId;

  /// Kunci rantai 32-byte saat ini (titik awal / state ratchet berikutnya)
  final List<int> chainKey;

  /// Pasangan kunci Ed25519 untuk menandatangani setiap pesan yang dikirim
  final SimpleKeyPair signingKeyPair;

  /// Kunci publik Ed25519 (32 bytes)
  final List<int> signingPublicKeyBytes;

  /// Counter pesan yang dikirim (mulai dari 0, monoton naik)
  final int counter;

  /// Waktu pembuatan sender key ini
  final DateTime createdAt;

  /// Waktu terakhir sender key ini diperbarui/digunakan
  final DateTime updatedAt;

  const SenderKeyRecord({
    required this.groupId,
    required this.keyId,
    required this.chainKey,
    required this.signingKeyPair,
    required this.signingPublicKeyBytes,
    required this.counter,
    required this.createdAt,
    required this.updatedAt,
  });

  SenderKeyRecord copyWith({
    int? keyId,
    List<int>? chainKey,
    SimpleKeyPair? signingKeyPair,
    List<int>? signingPublicKeyBytes,
    int? counter,
    DateTime? updatedAt,
  }) {
    return SenderKeyRecord(
      groupId: groupId,
      keyId: keyId ?? this.keyId,
      chainKey: chainKey ?? this.chainKey,
      signingKeyPair: signingKeyPair ?? this.signingKeyPair,
      signingPublicKeyBytes:
          signingPublicKeyBytes ?? this.signingPublicKeyBytes,
      counter: counter ?? this.counter,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model untuk state sender key milik anggota lain di dalam suatu grup obrolan.
class SenderKeyState {
  /// ID ruang obrolan grup
  final String groupId;

  /// ID anggota pengirim pesan
  final String senderId;

  /// ID sender key aktif pengirim
  final int keyId;

  /// Kunci rantai 32-byte saat ini untuk pengirim ini
  final List<int> chainKey;

  /// Kunci publik Ed25519 (32 bytes) milik pengirim untuk verifikasi tanda tangan
  final List<int> signingPublicKeyBytes;

  /// Counter pesan terakhir yang telah didekripsi dari pengirim ini
  final int counter;

  /// Waktu state ini diperbarui
  final DateTime updatedAt;

  const SenderKeyState({
    required this.groupId,
    required this.senderId,
    required this.keyId,
    required this.chainKey,
    required this.signingPublicKeyBytes,
    required this.counter,
    required this.updatedAt,
  });

  SenderKeyState copyWith({
    int? keyId,
    List<int>? chainKey,
    List<int>? signingPublicKeyBytes,
    int? counter,
    DateTime? updatedAt,
  }) {
    return SenderKeyState(
      groupId: groupId,
      senderId: senderId,
      keyId: keyId ?? this.keyId,
      chainKey: chainKey ?? this.chainKey,
      signingPublicKeyBytes:
          signingPublicKeyBytes ?? this.signingPublicKeyBytes,
      counter: counter ?? this.counter,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model untuk message key terlewati saat pesan tiba di luar urutan (out-of-order).
class SkippedMessageKey {
  final String groupId;
  final String senderId;
  final int keyId;
  final int counter;
  final List<int> messageKey;
  final DateTime expiresAt;

  const SkippedMessageKey({
    required this.groupId,
    required this.senderId,
    required this.keyId,
    required this.counter,
    required this.messageKey,
    required this.expiresAt,
  });
}

/// Struktur data kanonikal untuk envelope pesan grup E2EE terenkripsi.
class GroupMessageEnvelope {
  /// Versi protokol envelope (saat ini 1)
  final int version;

  /// ID ruang obrolan grup
  final String groupId;

  /// ID pengirim pesan
  final String senderId;

  /// ID sender key yang digunakan
  final int keyId;

  /// Urutan pesan dalam rantai sender key
  final int counter;

  /// Nonce 24-byte acak (Base64)
  final String nonceB64;

  /// Ciphertext XChaCha20-Poly1305 (Base64)
  final String ciphertextB64;

  /// Tanda tangan digital Ed25519 (Base64) di atas AAD kanonikal + Ciphertext
  final String signatureB64;

  const GroupMessageEnvelope({
    this.version = 1,
    required this.groupId,
    required this.senderId,
    required this.keyId,
    required this.counter,
    required this.nonceB64,
    required this.ciphertextB64,
    required this.signatureB64,
  });

  /// Format kanonikal string AAD (Additional Authenticated Data) untuk mengikat metadata.
  static String buildCanonicalAad({
    required String groupId,
    required String senderId,
    required int keyId,
    required int counter,
    required String nonceB64,
  }) {
    return 'MEKAAR_GRP_V1:$groupId:$senderId:$keyId:$counter:$nonceB64';
  }

  /// String kanonikal AAD dari envelope ini
  String get canonicalAad => buildCanonicalAad(
        groupId: groupId,
        senderId: senderId,
        keyId: keyId,
        counter: counter,
        nonceB64: nonceB64,
      );

  /// String data yang ditandatangani oleh Ed25519: `canonicalAad:ciphertextB64`
  String get signaturePayload => '$canonicalAad:$ciphertextB64';

  /// Serialisasi envelope ke JSON string untuk disimpan di kolom content pesan
  String toJsonString() {
    return jsonEncode({
      'v': version,
      'gid': groupId,
      'sid': senderId,
      'kid': keyId,
      'ctr': counter,
      'nonce': nonceB64,
      'ct': ciphertextB64,
      'sig': signatureB64,
    });
  }

  /// Deserialisasi envelope dari JSON string
  static GroupMessageEnvelope? tryParse(String rawJson) {
    try {
      final map = jsonDecode(rawJson);
      if (map is! Map<String, dynamic>) return null;
      if (map['v'] != 1) return null;

      final gid = map['gid'] as String?;
      final sid = map['sid'] as String?;
      final kid = map['kid'] as int?;
      final ctr = map['ctr'] as int?;
      final nonce = map['nonce'] as String?;
      final ct = map['ct'] as String?;
      final sig = map['sig'] as String?;

      if (gid == null ||
          sid == null ||
          kid == null ||
          ctr == null ||
          nonce == null ||
          ct == null ||
          sig == null) {
        return null;
      }

      return GroupMessageEnvelope(
        version: map['v'] as int? ?? 1,
        groupId: gid,
        senderId: sid,
        keyId: kid,
        counter: ctr,
        nonceB64: nonce,
        ciphertextB64: ct,
        signatureB64: sig,
      );
    } catch (_) {
      return null;
    }
  }
}
