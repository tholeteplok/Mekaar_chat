import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../core/storage/mekaar_secure_storage.dart';
import '../models/group_sender_key_models.dart';
import 'group_sender_key_store.dart';
import 'supabase_service.dart';

/// Pengecualian dasar untuk kesalahan kriptografi obrolan grup E2EE.
class GroupE2eeException implements Exception {
  final String message;
  final Object? cause;

  const GroupE2eeException(this.message, [this.cause]);

  @override
  String toString() => 'GroupE2eeException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Dilempar saat tanda tangan digital Ed25519 pengirim gagal diverifikasi.
class GroupE2eeSignatureException extends GroupE2eeException {
  const GroupE2eeSignatureException(super.message, [super.cause]);
}

/// Dilempar saat counter pesan melompat melebihi batas keras MAX_SKIPPED_KEYS (1.000).
class GroupE2eeMaxSkippedKeysExceededException extends GroupE2eeException {
  const GroupE2eeMaxSkippedKeysExceededException(super.message);
}

/// Dilempar saat pesan terdeteksi sebagai replay attack atau kuncinya sudah dihapus/hilang.
class GroupE2eeReplayOrMissingKeyException extends GroupE2eeException {
  const GroupE2eeReplayOrMissingKeyException(super.message);
}

/// Dilempar saat state sender key dari pengirim belum ada di perangkat lokal (perlu SKDM).
class GroupE2eeMissingSenderStateException extends GroupE2eeException {
  final String groupId;
  final String senderId;
  final int keyId;

  const GroupE2eeMissingSenderStateException({
    required this.groupId,
    required this.senderId,
    required this.keyId,
    required String message,
  }) : super(message);
}

/// Engine Kriptografi E2EE Obrolan Grup berbasis Signal Sender Keys (Dart Murni).
///
/// Spesifikasi:
/// - Cipher: XChaCha20-Poly1305 (24-byte nonce, 16-byte Poly1305 MAC).
/// - Ratchet: HKDF-SHA256 untuk message key (`mekaar-sk-msg`) dan chain key berikutnya (`mekaar-sk-next`).
/// - Signing: Ed25519 digital signature terikat pada canonical AAD + Ciphertext.
/// - Hard Limit: `maxSkippedKeys = 1000` per rantai pengirim.
class GroupE2eeService {
  GroupE2eeService({
    SenderKeyStore? store,
    FlutterSecureStorage? secureStorage,
    SupabaseService? supabaseService,
    SimpleKeyPair? initialIdentityKeyPair,
  })  : _store = store ?? SqlCipherSenderKeyStore.instance,
        _secureStorage = secureStorage ?? MekaarSecureStorage.instance,
        _supabase = supabaseService ?? SupabaseService(),
        _identityKeyPair = initialIdentityKeyPair;

  static final GroupE2eeService instance = GroupE2eeService();

  /// Sentinel penanda bahwa pesan grup terenkripsi sedang menunggu distribusi Sender Key (SKDM).
  static const String pendingKeySentinel = '[mekaar_group_pending_key]';

  /// Sentinel penanda bahwa pesan grup terenkripsi gagal didekripsi (rusak/kunci musnah).
  static const String undecryptableSentinel = '[mekaar_group_undecryptable]';

  /// Memeriksa apakah teks pesan merupakan penanda sedang menunggu kunci.
  static bool isPendingKey(String? text) => text == pendingKeySentinel;

  /// Memeriksa apakah teks pesan gagal didekripsi secara permanen.
  static bool isUndecryptable(String? text) =>
      text == undecryptableSentinel || text == pendingKeySentinel;
  static final Logger _logger = Logger();

  final SenderKeyStore _store;
  final FlutterSecureStorage _secureStorage;
  final SupabaseService _supabase;

  /// Batas maksimal penyimpanan skipped message keys per pengirim (anti-OOM).
  static const int maxSkippedKeys = 1000;

  /// Batas maksimal pesan dalam satu rantai sender key sebelum dirotasi (Brief §4.4, D3).
  static const int rotationMaxMessages = 5000;

  /// Batas maksimal usia rantai sender key dalam hari sebelum dirotasi (Brief §4.4, D3).
  static const int rotationMaxDays = 30;

  /// Prefix kunci penyimpanan seed Ed25519 identitas di secure storage.
  static const String _storageKeyPrefix = 'e2ee_ed25519_identity_seed_v1_';

  /// Info HKDF untuk menurunkan kunci pesan per counter.
  static const String infoMessageKey = 'mekaar-sk-msg';

  /// Info HKDF untuk meratchet kunci rantai ke depan.
  static const String infoChainNext = 'mekaar-sk-next';

  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Xchacha20 _cipher = Xchacha20.poly1305Aead();
  final Ed25519 _ed25519 = Ed25519();
  final Random _secureRandom = Random.secure();

  SimpleKeyPair? _identityKeyPair;
  final Map<String, Future<void>> _chainLocks = {};

  /// Serialisasi akses baca-ubah-tulis pada rantai kunci agar tidak korup akibat konkurensi async.
  Future<T> _withChainLock<T>(String lockKey, Future<T> Function() action) async {
    final prev = _chainLocks[lockKey] ?? Future<void>.value();
    final completer = Completer<void>();
    _chainLocks[lockKey] = completer.future;
    try {
      await prev;
      return await action();
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_chainLocks[lockKey], completer.future)) {
        _chainLocks.remove(lockKey);
      }
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _getStorageKey(String? userId) {
    final effectiveId = userId ?? _supabase.currentUserId ?? 'default_user';
    return '$_storageKeyPrefix$effectiveId';
  }

  /// Memeriksa apakah sebuah sender key record telah melampaui ambang batas rotasi berkala.
  static bool needsKeyRotation(SenderKeyRecord record, {DateTime? now}) {
    final currentTime = now ?? DateTime.now().toUtc();
    if (record.counter >= rotationMaxMessages) return true;
    if (currentTime.difference(record.createdAt).inDays >= rotationMaxDays) return true;
    return false;
  }

  /// Mengambil atau memuat pasangan kunci identitas Ed25519 persisten dari secure storage.
  /// Jika belum ada, membuat seed 32-byte acak baru dan menyimpannya secara aman.
  Future<SimpleKeyPair> getOrGenerateIdentityKeyPair({String? userId}) async {
    if (_identityKeyPair != null) return _identityKeyPair!;

    final storageKey = _getStorageKey(userId);
    try {
      final raw = await _secureStorage.read(key: storageKey);
      if (raw != null && raw.isNotEmpty) {
        final seed = base64Decode(raw);
        if (seed.length == 32) {
          _identityKeyPair = await _ed25519.newKeyPairFromSeed(seed);
          return _identityKeyPair!;
        }
      }
    } catch (e) {
      _logger.w('Gagal membaca ed25519 identity key dari secure storage: $e');
    }

    // Buat seed 32-byte acak baru
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = _secureRandom.nextInt(256);
    }

    try {
      await _secureStorage.write(
        key: storageKey,
        value: base64Encode(seed),
      );
    } catch (e) {
      _logger.e('Gagal menyimpan ed25519 identity seed ke secure storage: $e');
    }

    _identityKeyPair = await _ed25519.newKeyPairFromSeed(seed);
    return _identityKeyPair!;
  }

  /// Mengambil byte kunci publik Ed25519 untuk verifikasi tanda tangan identitas.
  Future<List<int>> getIdentityPublicKey({String? userId}) async {
    final pair = await getOrGenerateIdentityKeyPair(userId: userId);
    final pub = await pair.extractPublicKey();
    return pub.bytes;
  }

  /// Mengekstrak seed 32-byte Ed25519 identitas untuk disertakan dalam backup PIN.
  Future<List<int>> exportIdentitySeed({String? userId}) async {
    final pair = await getOrGenerateIdentityKeyPair(userId: userId);
    return await pair.extractPrivateKeyBytes();
  }

  /// Memulihkan pasangan kunci identitas Ed25519 dari seed backup dan menyimpannya ke secure storage.
  Future<void> importIdentitySeed(List<int> seed, {String? userId}) async {
    if (seed.length != 32) {
      throw const GroupE2eeException('Panjang seed identitas Ed25519 tidak valid');
    }
    final storageKey = _getStorageKey(userId);
    await _secureStorage.write(key: storageKey, value: base64Encode(seed));
    _identityKeyPair = await _ed25519.newKeyPairFromSeed(seed);
  }

  /// Membersihkan cache kunci identitas Ed25519 dari RAM saat logout.
  void clearSession() {
    _identityKeyPair = null;
  }

  /// Menghapus & membuat ulang kunci identitas Ed25519 (saat reset PIN / reset paksa E2EE).
  Future<void> resetIdentity({String? userId}) async {
    _identityKeyPair = null;
    final storageKey = _getStorageKey(userId);
    try {
      await _secureStorage.delete(key: storageKey);
    } catch (_) {}
    await getOrGenerateIdentityKeyPair(userId: userId);
  }

  Future<SenderKeyRecord> _generateSenderKeyUnlocked(
    String groupId, {
    int keyId = 1,
  }) async {
    final chainKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      chainKey[i] = _secureRandom.nextInt(256);
    }

    final keyPair = await _ed25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();

    final now = DateTime.now().toUtc();
    final record = SenderKeyRecord(
      groupId: groupId,
      keyId: keyId,
      chainKey: chainKey,
      signingKeyPair: keyPair,
      signingPublicKeyBytes: pubKey.bytes,
      counter: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _store.saveOurSenderKey(record);
    _logger.d('Sender key baru digenerate untuk grup $groupId (keyId: $keyId)');
    return record;
  }

  Future<SenderKeyRecord> _getOrGenerateOurSenderKeyUnlocked(
    String groupId,
  ) async {
    final existing = await _store.getOurSenderKey(groupId);
    if (existing != null) return existing;
    return await _generateSenderKeyUnlocked(groupId, keyId: 1);
  }

  /// Menghasilkan pasangan sender key aktif baru untuk akun kita di suatu grup.
  /// Dipanggil saat membuat grup, saat pertama kali mengirim pesan, atau saat rotasi/rekey.
  Future<SenderKeyRecord> generateSenderKey(
    String groupId, {
    int keyId = 1,
  }) {
    return _withChainLock(
      'enc:$groupId',
      () => _generateSenderKeyUnlocked(groupId, keyId: keyId),
    );
  }

  /// Membaca atau menginisialisasi sender key aktif kita untuk suatu grup.
  Future<SenderKeyRecord> getOrGenerateOurSenderKey(String groupId) {
    return _withChainLock(
      'enc:$groupId',
      () => _getOrGenerateOurSenderKeyUnlocked(groupId),
    );
  }

  /// Mendaftarkan atau memperbarui state sender key anggota lain (misal dari SKDM yang diterima).
  Future<void> registerSenderKeyState({
    required String groupId,
    required String senderId,
    required int keyId,
    required List<int> chainKey,
    required List<int> signingPublicKeyBytes,
    int counter = 0,
  }) {
    if (keyId <= 0 || counter < 0) {
      throw const GroupE2eeException('keyId atau counter SKDM tidak valid');
    }
    if (chainKey.length != 32 || signingPublicKeyBytes.length != 32) {
      throw const GroupE2eeException('Panjang chainKey atau signingPublicKey SKDM tidak valid');
    }

    return _withChainLock('dec:$groupId:$senderId:$keyId', () async {
      // Anti-Rollback Guard: jangan timpa state dengan counter lebih tua jika signing key sama
      final existing = await _store.getSenderState(groupId, senderId, keyId);
      if (existing != null &&
          _bytesEqual(existing.signingPublicKeyBytes, signingPublicKeyBytes) &&
          existing.counter >= counter) {
        _logger.d(
          'Melewati registrasi SKDM basi/duplikat untuk $senderId (keyId: $keyId, '
          'existingCounter: ${existing.counter}, incomingCounter: $counter)',
        );
        return;
      }

      final state = SenderKeyState(
        groupId: groupId,
        senderId: senderId,
        keyId: keyId,
        chainKey: chainKey,
        signingPublicKeyBytes: signingPublicKeyBytes,
        counter: counter,
        updatedAt: DateTime.now().toUtc(),
      );

      await _store.saveSenderState(state);
      if (keyId > 2) {
        await _store.purgeOldSenderStates(groupId, senderId, keyId - 2);
      }
      _logger.d('Sender state disimpan untuk $senderId di grup $groupId (keyId: $keyId, counter: $counter)');
    });
  }

  /// Mengenkripsi teks pesan grup menggunakan Sender Key aktif kita.
  Future<GroupMessageEnvelope> encryptGroupMessage({
    required String groupId,
    String senderId = 'me',
    required String plaintext,
    Uint8List? fixedNonce,
  }) {
    return _withChainLock('enc:$groupId', () async {
      final currentKey = await _getOrGenerateOurSenderKeyUnlocked(groupId);

    // 1. Derivasi Message Key (32 bytes) dari Chain Key saat ini
    final msgSecretKey = await _hkdf.deriveKey(
      secretKey: SecretKey(currentKey.chainKey),
      info: utf8.encode(infoMessageKey),
    );
    final msgKeyBytes = await msgSecretKey.extractBytes();

    // 2. Ratchet Chain Key ke depan untuk pesan berikutnya
    final nextChainSecretKey = await _hkdf.deriveKey(
      secretKey: SecretKey(currentKey.chainKey),
      info: utf8.encode(infoChainNext),
    );
    final nextChainKeyBytes = await nextChainSecretKey.extractBytes();

    // 3. Buat Nonce 24-byte acak untuk XChaCha20-Poly1305 (atau fixedNonce untuk uji deterministik)
    final nonce = fixedNonce ?? Uint8List(24);
    if (fixedNonce == null) {
      for (int i = 0; i < 24; i++) {
        nonce[i] = _secureRandom.nextInt(256);
      }
    }
    final nonceB64 = base64Encode(nonce);

    // 4. Bangun AAD Kanonikal yang mengikat metadata envelope
    final aad = GroupMessageEnvelope.buildCanonicalAad(
      groupId: groupId,
      senderId: senderId,
      keyId: currentKey.keyId,
      counter: currentKey.counter,
      nonceB64: nonceB64,
    );

    // 5. Enkripsi plaintext dengan XChaCha20-Poly1305 + AAD
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(msgKeyBytes),
      nonce: nonce,
      aad: utf8.encode(aad),
    );

    // Ciphertext menggabungkan cipher bytes + 16 bytes Poly1305 MAC
    final combinedCipher = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    combinedCipher.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    combinedCipher.setRange(
      secretBox.cipherText.length,
      combinedCipher.length,
      secretBox.mac.bytes,
    );
    final ciphertextB64 = base64Encode(combinedCipher);

    // 6. Tandatangani payload kanonikal `AAD:ciphertextB64` dengan Ed25519
    final signaturePayload = '$aad:$ciphertextB64';
    final signature = await _ed25519.sign(
      utf8.encode(signaturePayload),
      keyPair: currentKey.signingKeyPair,
    );
    final signatureB64 = base64Encode(signature.bytes);

    // 7. Simpan state ter-ratchet milik kita (counter bertambah 1, chainKey diperbarui)
    final updatedRecord = currentKey.copyWith(
      chainKey: nextChainKeyBytes,
      counter: currentKey.counter + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    await _store.saveOurSenderKey(updatedRecord);

    return GroupMessageEnvelope(
      version: 1,
      groupId: groupId,
      senderId: senderId,
      keyId: currentKey.keyId,
      counter: currentKey.counter,
      nonceB64: nonceB64,
      ciphertextB64: ciphertextB64,
      signatureB64: signatureB64,
    );
    });
  }

  /// Mendekripsi pesan grup menggunakan state sender key milik pengirim.
  Future<String> decryptGroupMessage({
    required String groupId,
    required String senderId,
    GroupMessageEnvelope? envelope,
    String? envelopeJson,
  }) async {
    final effectiveEnvelope = envelope ??
        (envelopeJson != null
            ? GroupMessageEnvelope.tryParse(envelopeJson)
            : null);
    if (effectiveEnvelope == null) {
      throw const GroupE2eeException(
        'Metadata envelope tidak valid atau payload corrupt',
      );
    }

    // 0. Validasi identitas envelope & batas dasar
    if (effectiveEnvelope.groupId != groupId ||
        effectiveEnvelope.senderId != senderId) {
      throw const GroupE2eeException('Metadata envelope tidak cocok dengan grup atau pengirim');
    }
    if (effectiveEnvelope.keyId <= 0 || effectiveEnvelope.counter < 0) {
      throw const GroupE2eeException('Nilai keyId atau counter envelope tidak valid');
    }

    return _withChainLock('dec:$groupId:$senderId:${effectiveEnvelope.keyId}', () async {

    // 1. Ambil state pengirim untuk (groupId, senderId, keyId)
    final state = await _store.getSenderState(groupId, senderId, effectiveEnvelope.keyId);
    if (state == null) {
      throw GroupE2eeMissingSenderStateException(
        groupId: groupId,
        senderId: senderId,
        keyId: effectiveEnvelope.keyId,
        message: 'Sender state belum terdaftar untuk pengirim $senderId (keyId: ${effectiveEnvelope.keyId})',
      );
    }

    // 2. Verifikasi tanda tangan digital Ed25519 SEBELUM menyentuh dekripsi
    final pubKey = SimplePublicKey(state.signingPublicKeyBytes, type: KeyPairType.ed25519);
    final sigBytes = base64Decode(effectiveEnvelope.signatureB64);
    if (sigBytes.length != 64) {
      throw const GroupE2eeSignatureException('Panjang tanda tangan Ed25519 tidak valid');
    }

    final isValidSig = await _ed25519.verify(
      utf8.encode(effectiveEnvelope.signaturePayload),
      signature: Signature(sigBytes, publicKey: pubKey),
    );

    if (!isValidSig) {
      throw const GroupE2eeSignatureException(
        'Verifikasi tanda tangan digital Ed25519 gagal. Pesan telah dimodifikasi atau dipalsukan!',
      );
    }

    // 3. Resolusi Message Key berdasarkan counter pengirim
    List<int> targetMessageKeyBytes;

    if (effectiveEnvelope.counter == state.counter) {
      // Skenario A: Pesan tiba berurutan (in-order)
      final msgSecretKey = await _hkdf.deriveKey(
        secretKey: SecretKey(state.chainKey),
        info: utf8.encode(infoMessageKey),
      );
      targetMessageKeyBytes = await msgSecretKey.extractBytes();

      // Ratchet chain key ke depan
      final nextChainSecretKey = await _hkdf.deriveKey(
        secretKey: SecretKey(state.chainKey),
        info: utf8.encode(infoChainNext),
      );
      final nextChainKeyBytes = await nextChainSecretKey.extractBytes();

      // Perbarui state pengirim
      final updatedState = state.copyWith(
        chainKey: nextChainKeyBytes,
        counter: state.counter + 1,
        updatedAt: DateTime.now().toUtc(),
      );
      await _store.saveSenderState(updatedState);
    } else if (effectiveEnvelope.counter < state.counter) {
      // Skenario B: Pesan tiba terlambat (counter lebih kecil)
      // Ambil dan SEKETIKA HAPUS dari skipped message keys
      final skipped = await _store.takeSkippedKey(
        groupId,
        senderId,
        effectiveEnvelope.keyId,
        effectiveEnvelope.counter,
      );

      if (skipped == null) {
        throw const GroupE2eeReplayOrMissingKeyException(
          'Pesan tidak dapat didekripsi: Kunci telah dihapus atau pesan terdeteksi sebagai replay!',
        );
      }
      targetMessageKeyBytes = skipped.messageKey;
    } else {
      // Skenario C: Pesan tiba melompat ke depan (out-of-order)
      final skippedDelta = effectiveEnvelope.counter - state.counter;
      final currentSkippedTotal = await _store.getSkippedKeyCount(
        groupId,
        senderId,
        effectiveEnvelope.keyId,
      );

      if (currentSkippedTotal + skippedDelta > maxSkippedKeys) {
        throw GroupE2eeMaxSkippedKeysExceededException(
          'Lompatan counter ($skippedDelta) melebihi batas keras MAX_SKIPPED_KEYS ($maxSkippedKeys)',
        );
      }

      var tempChainKey = state.chainKey;
      final expiresAt = DateTime.now().toUtc().add(const Duration(days: 30));

      // Simpan seluruh kunci yang terlewati dari state.counter sampai (effectiveEnvelope.counter - 1)
      for (int c = state.counter; c < effectiveEnvelope.counter; c++) {
        final skippedMsgKey = await _hkdf.deriveKey(
          secretKey: SecretKey(tempChainKey),
          info: utf8.encode(infoMessageKey),
        );
        final skippedMsgKeyBytes = await skippedMsgKey.extractBytes();

        await _store.saveSkippedKey(SkippedMessageKey(
          groupId: groupId,
          senderId: senderId,
          keyId: effectiveEnvelope.keyId,
          counter: c,
          messageKey: skippedMsgKeyBytes,
          expiresAt: expiresAt,
        ));

        final nextChain = await _hkdf.deriveKey(
          secretKey: SecretKey(tempChainKey),
          info: utf8.encode(infoChainNext),
        );
        tempChainKey = await nextChain.extractBytes();
      }

      // Kunci untuk counter target
      final targetMsgKey = await _hkdf.deriveKey(
        secretKey: SecretKey(tempChainKey),
        info: utf8.encode(infoMessageKey),
      );
      targetMessageKeyBytes = await targetMsgKey.extractBytes();

      // Ratchet ke setelah target
      final finalChainKey = await _hkdf.deriveKey(
        secretKey: SecretKey(tempChainKey),
        info: utf8.encode(infoChainNext),
      );
      final finalChainKeyBytes = await finalChainKey.extractBytes();

      final updatedState = state.copyWith(
        chainKey: finalChainKeyBytes,
        counter: effectiveEnvelope.counter + 1,
        updatedAt: DateTime.now().toUtc(),
      );
      await _store.saveSenderState(updatedState);
    }

    // 4. Dekripsi Ciphertext menggunakan XChaCha20-Poly1305 + AAD
    try {
      final combinedCipher = base64Decode(effectiveEnvelope.ciphertextB64);
      if (combinedCipher.length < 16) {
        throw const GroupE2eeException('Panjang ciphertext tidak valid (kurang dari MAC Poly1305)');
      }

      final cipherText = combinedCipher.sublist(0, combinedCipher.length - 16);
      final macBytes = combinedCipher.sublist(combinedCipher.length - 16);
      final nonceBytes = base64Decode(effectiveEnvelope.nonceB64);
      if (nonceBytes.length != 24) {
        throw const GroupE2eeException('Panjang nonce XChaCha20 tidak valid (harus 24 byte)');
      }

      final secretBox = SecretBox(
        cipherText,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );

      final decryptedBytes = await _cipher.decrypt(
        secretBox,
        secretKey: SecretKey(targetMessageKeyBytes),
        aad: utf8.encode(effectiveEnvelope.canonicalAad),
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      if (e is GroupE2eeException) rethrow;
      throw GroupE2eeException('Gagal mendekripsi ciphertext: $e', e);
    }
    });
  }
}
