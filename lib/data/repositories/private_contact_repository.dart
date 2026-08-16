import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final privateContactRepositoryProvider =
    Provider<PrivateContactRepository>((ref) {
  return PrivateContactRepository();
});

class PrivateContactRepository {
  final FlutterSecureStorage _secureStorage;

  static const String _passcodeKey = 'mekaar_private_vault_passcode_hash';
  static const String _saltKey = 'mekaar_private_vault_salt';
  static const String _hiddenRoomsKey = 'mekaar_private_vault_hidden_rooms';

  String? _cachedSalt;
  String? _cachedHash;

  PrivateContactRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<String> _getOrCreateSalt() async {
    if (_cachedSalt != null && _cachedSalt!.isNotEmpty) {
      return _cachedSalt!;
    }
    try {
      var salt = await _secureStorage.read(key: _saltKey);
      if (salt == null || salt.isEmpty) {
        salt = _generateSalt();
        await _secureStorage.write(key: _saltKey, value: salt);
      }
      _cachedSalt = salt;
      return salt;
    } catch (_) {
      return 'fallback_device_vault_salt';
    }
  }

  String _hashWithSalt(String code, String salt) {
    return sha256.convert(utf8.encode('$salt:${code.trim()}')).toString();
  }

  /// Memuat cache hash & salt ke memori untuk verifikasi instan O(1)
  Future<void> preloadCache() async {
    try {
      final salt = await _getOrCreateSalt();
      final hash = await _secureStorage.read(key: _passcodeKey);
      _cachedSalt = salt;
      _cachedHash = hash;
    } catch (_) {}
  }

  /// Periksa apakah pengguna sudah mengatur kode rahasia vault
  Future<bool> hasPasscode() async {
    if (_cachedHash != null && _cachedHash!.isNotEmpty) {
      return true;
    }
    try {
      final hash = await _secureStorage.read(key: _passcodeKey);
      _cachedHash = hash;
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Atur kode rahasia vault baru dengan salt kriptografi unik per perangkat
  Future<void> setPasscode(String code) async {
    final salt = await _getOrCreateSalt();
    final hash = _hashWithSalt(code, salt);
    _cachedHash = hash;
    await _secureStorage.write(key: _passcodeKey, value: hash);
  }

  /// Verifikasi kecocokan kode rahasia input secara aman dan cepat
  Future<bool> verifyPasscode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    // Gunakan in-memory cache jika tersedia untuk menghindari disk I/O blocking
    if (_cachedHash != null && _cachedSalt != null) {
      if (_cachedHash!.isEmpty) return false;
      return _cachedHash == _hashWithSalt(trimmed, _cachedSalt!);
    }

    try {
      final salt = await _getOrCreateSalt();
      final savedHash = await _secureStorage.read(key: _passcodeKey);
      _cachedSalt = salt;
      _cachedHash = savedHash;

      if (savedHash == null || savedHash.isEmpty) return false;
      return savedHash == _hashWithSalt(trimmed, salt);
    } catch (_) {
      return false;
    }
  }

  /// Dapatkan daftar seluruh ID ruang obrolan yang disembunyikan
  Future<Set<String>> getHiddenRoomIds() async {
    try {
      final jsonStr = await _secureStorage.read(key: _hiddenRoomsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  /// Sembunyikan atau batalkan penyembunyian suatu room
  /// Mengembalikan true jika room sekarang tersembunyi, false jika ditampilkan.
  Future<bool> toggleHideRoom(String roomId) async {
    final currentSet = await getHiddenRoomIds();
    final isHidden = currentSet.contains(roomId);

    if (isHidden) {
      currentSet.remove(roomId);
    } else {
      currentSet.add(roomId);
    }

    try {
      final jsonStr = jsonEncode(currentSet.toList());
      await _secureStorage.write(key: _hiddenRoomsKey, value: jsonStr);
    } catch (_) {}

    return !isHidden;
  }

  /// Periksa apakah sebuah room disembunyikan
  Future<bool> isRoomHidden(String roomId) async {
    final currentSet = await getHiddenRoomIds();
    return currentSet.contains(roomId);
  }
}
