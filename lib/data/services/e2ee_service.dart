import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_service.dart';

/// Layanan E2EE untuk chat 1:1 (teks, lokasi, dan media).
///
/// Skema:
/// - Identitas akun: keypair X25519. Private key disimpan per-akun di
///   flutter_secure_storage; public key dipublikasi ke profiles.e2ee_public_key.
/// - Kunci room: ECDH(priv saya, pub lawan) -> HKDF-SHA256
///   (info 'mekaar-room:{roomId}') -> kunci XChaCha20-Poly1305.
///   Kedua pihak menurunkan kunci yang sama (model TOFU).
/// - Envelope pesan di kolom content (is_encrypted = true):
///   {"v":1,"a":"xchacha20poly1305","ct":base64(nonce||cipher||mac)}.
/// - Media: kunci file acak per lampiran; ciphertext yang di-upload; kunci file
///   dikirim di dalam envelope pesan (ikut terenkripsi E2EE).
/// - Backup: private key di-wrap dengan kunci PBKDF2-SHA256(PIN) dan disimpan di
///   profiles.e2ee_key_backup agar riwayat dapat dipulihkan di perangkat baru.
class E2eeService {
  E2eeService._();

  static final E2eeService instance = E2eeService._();

  static const String _privStorageKeyPrefix = 'e2ee_identity_private_v1_';
  static const int _pbkdf2Iterations = 100000;
  static const String algorithmName = 'xchacha20poly1305';

  /// Placeholder UI bila dekripsi gagal (mis. kunci belum ada di perangkat ini).
  static const String undecryptableText = '🔒 Pesan terenkripsi';

  final SupabaseService _supabase = SupabaseService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();
  final Xchacha20 _cipher = Xchacha20.poly1305Aead();

  SimpleKeyPair? _identity;
  String? _identityPublicB64;
  final Map<String, SecretKey> _roomKeys = {};

  String? get myPublicKeyB64 => _identityPublicB64;

  String _storageKeyFor(String userId) => '$_privStorageKeyPrefix$userId';

  // ── Identitas ──────────────────────────────────────────────

  /// Muat identitas dari secure storage, atau buat + publikasikan baru.
  /// Dipanggil lazy dari jalur enkripsi/dekripsi.
  Future<void> ensureIdentity() async {
    if (_identity != null) return;
    final userId = _supabase.currentUserId;
    if (userId == null) return;

    try {
      final storedPriv = await _secureStorage.read(
        key: _storageKeyFor(userId),
      );
      if (storedPriv != null) {
        await _loadIdentityFromBytes(base64Decode(storedPriv));
        await _publishPublicKeyIfNeeded();
        return;
      }
    } catch (_) {}

    await _generateAndPublishIdentity(userId);
  }

  Future<void> _loadIdentityFromBytes(List<int> privateBytes) async {
    _identity = await _x25519.newKeyPairFromSeed(privateBytes);
    final pub = await _identity!.extractPublicKey();
    _identityPublicB64 = base64Encode(pub.bytes);
  }

  Future<void> _generateAndPublishIdentity(String userId) async {
    try {
      _identity = await _x25519.newKeyPair();
      final privBytes = await _identity!.extractPrivateKeyBytes();
      await _secureStorage.write(
        key: _storageKeyFor(userId),
        value: base64Encode(privBytes),
      );
      final pub = await _identity!.extractPublicKey();
      _identityPublicB64 = base64Encode(pub.bytes);
      await _publishPublicKeyIfNeeded(force: true);
    } catch (_) {}
  }

  Future<void> _publishPublicKeyIfNeeded({bool force = false}) async {
    final userId = _supabase.currentUserId;
    final pubB64 = _identityPublicB64;
    if (userId == null || pubB64 == null) return;

    if (!force) {
      try {
        final row = await _supabase.client
            .from('profiles')
            .select('e2ee_public_key')
            .eq('id', userId)
            .maybeSingle();
        if (row != null && row['e2ee_public_key'] == pubB64) return;
      } catch (_) {
        return;
      }
    }

    try {
      await _supabase.client
          .from('profiles')
          .update({
            'e2ee_public_key': pubB64,
            'e2ee_key_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {}
  }

  /// Bersihkan cache sesi saat logout (identitas per-akun tetap di storage).
  void clearSession() {
    _identity = null;
    _identityPublicB64 = null;
    _roomKeys.clear();
  }

  // ── Kunci room (ECDH + HKDF) ───────────────────────────────

  Future<SecretKey?> _roomKey(String roomId) async {
    final cached = _roomKeys[roomId];
    if (cached != null) return cached;

    await ensureIdentity();
    final userId = _supabase.currentUserId;
    final identity = _identity;
    if (userId == null || identity == null) return null;

    // Room self_device tidak punya lawan — pakai kunci publik sendiri.
    String peerId = userId;
    try {
      final peer = await _supabase.client
          .from('room_participants')
          .select('profile_id')
          .eq('room_id', roomId)
          .neq('profile_id', userId)
          .maybeSingle();
      if (peer != null) peerId = peer['profile_id'] as String;
    } catch (_) {}

    String? peerPubB64;
    try {
      final row = await _supabase.client
          .from('public_profiles')
          .select('e2ee_public_key')
          .eq('id', peerId)
          .maybeSingle();
      peerPubB64 = row?['e2ee_public_key'] as String?;
    } catch (_) {}
    if (peerPubB64 == null || peerPubB64.isEmpty) return null;

    try {
      final shared = await _x25519.sharedSecretKey(
        keyPair: identity,
        remotePublicKey: SimplePublicKey(
          base64Decode(peerPubB64),
          type: KeyPairType.x25519,
        ),
      );

      final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
      final roomKey = await hkdf.deriveKey(
        secretKey: shared,
        info: utf8.encode('mekaar-room:$roomId'),
      );
      _roomKeys[roomId] = roomKey;
      return roomKey;
    } catch (_) {
      return null;
    }
  }

  // ── Envelope pesan ─────────────────────────────────────────

  /// Enkripsi plaintext untuk room. Return null bila lawan belum punya
  /// kunci publik (akun lama) — pemanggil mengirim plaintext sebagai fallback.
  Future<String?> encryptForRoom(String roomId, String plainText) async {
    try {
      final key = await _roomKey(roomId);
      if (key == null) return null;
      final box = await _cipher.encrypt(
        utf8.encode(plainText),
        secretKey: key,
      );
      return jsonEncode({
        'v': 1,
        'a': algorithmName,
        'ct': base64Encode(box.concatenation()),
      });
    } catch (_) {
      return null;
    }
  }

  /// Dekripsi envelope; passthrough bila konten bukan envelope;
  /// placeholder bila kunci tidak tersedia / MAC gagal.
  Future<String> decryptForRoom(String roomId, String content) async {
    Map<dynamic, dynamic> map;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map) return content;
      map = decoded;
    } catch (_) {
      return content;
    }

    if (map['a'] != algorithmName || map['ct'] is! String) return content;

    try {
      final key = await _roomKey(roomId);
      if (key == null) return undecryptableText;
      final box = SecretBox.fromConcatenation(
        base64Decode(map['ct'] as String),
        nonceLength: 24,
        macLength: 16,
      );
      final clear = await _cipher.decrypt(box, secretKey: key);
      return utf8.decode(clear);
    } catch (_) {
      return undecryptableText;
    }
  }

  // ── Media (kunci file acak per lampiran) ───────────────────

  Future<({List<int> bytes, String keyB64})> encryptMedia(
    List<int> bytes,
  ) async {
    final fileKey = await _cipher.newSecretKey();
    final box = await _cipher.encrypt(bytes, secretKey: fileKey);
    final keyBytes = await fileKey.extractBytes();
    return (bytes: box.concatenation(), keyB64: base64Encode(keyBytes));
  }

  Future<List<int>> decryptMedia(List<int> bytes, String keyB64) {
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: 24,
      macLength: 16,
    );
    return _cipher.decrypt(box, secretKey: SecretKey(base64Decode(keyB64)));
  }

  // ── Backup & restore via PIN ───────────────────────────────

  /// Wrap private key dengan kunci PBKDF2(PIN) lalu simpan ke profil.
  /// Dipanggil saat PIN dibuat/diubah. Best-effort.
  Future<void> backupWithPin(String pin) async {
    try {
      await ensureIdentity();
      final userId = _supabase.currentUserId;
      final identity = _identity;
      if (userId == null || identity == null) return;

      final privBytes = await identity.extractPrivateKeyBytes();
      final salt = _randomBytes(16);
      final wrapKey = await _pinKey(pin, salt);
      final box = await _cipher.encrypt(privBytes, secretKey: wrapKey);

      await _supabase.client
          .from('profiles')
          .update({
            'e2ee_key_backup': jsonEncode({
              'v': 1,
              'kdf': 'pbkdf2-sha256-$_pbkdf2Iterations',
              'salt': base64Encode(salt),
              'ct': base64Encode(box.concatenation()),
            }),
          })
          .eq('id', userId);
    } catch (_) {}
  }

  /// Pulihkan identitas dari backup bila perangkat ini belum punya kunci.
  /// Return true bila identitas lokal sudah/berhasil tersedia.
  Future<bool> restoreWithPin(String pin) async {
    try {
      final userId = _supabase.currentUserId;
      if (userId == null) return false;

      final hasLocal = await _secureStorage.read(key: _storageKeyFor(userId));
      if (hasLocal != null) return true;

      final row = await _supabase.client
          .from('profiles')
          .select('e2ee_key_backup, e2ee_public_key')
          .eq('id', userId)
          .maybeSingle();
      final backup = row?['e2ee_key_backup'] as String?;
      final expectedPub = row?['e2ee_public_key'] as String?;
      if (backup == null || backup.isEmpty) return false;

      final map = jsonDecode(backup) as Map;
      final salt = base64Decode(map['salt'] as String);
      final wrapKey = await _pinKey(pin, salt);
      final box = SecretBox.fromConcatenation(
        base64Decode(map['ct'] as String),
        nonceLength: 24,
        macLength: 16,
      );
      final privBytes = await _cipher.decrypt(box, secretKey: wrapKey);

      await _loadIdentityFromBytes(privBytes);

      // Verifikasi: public key hasil restore harus cocok dengan yang terpublikasi.
      if (expectedPub != null &&
          expectedPub.isNotEmpty &&
          expectedPub != _identityPublicB64) {
        clearSession();
        return false;
      }

      await _secureStorage.write(
        key: _storageKeyFor(userId),
        value: base64Encode(privBytes),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SecretKey> _pinKey(String pin, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac(Sha256()),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
