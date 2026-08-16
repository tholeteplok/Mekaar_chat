import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final privateContactRepositoryProvider = Provider<PrivateContactRepository>((ref) {
  return PrivateContactRepository();
});

class PrivateContactRepository {
  final FlutterSecureStorage _secureStorage;

  static const String _passcodeKey = 'mekaar_private_vault_passcode_hash';
  static const String _hiddenRoomsKey = 'mekaar_private_vault_hidden_rooms';

  PrivateContactRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String _hashPasscode(String code) {
    return sha256.convert(utf8.encode(code.trim())).toString();
  }

  /// Periksa apakah pengguna sudah mengatur kode rahasia vault
  Future<bool> hasPasscode() async {
    try {
      final hash = await _secureStorage.read(key: _passcodeKey);
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Atur kode rahasia vault baru (disimpan dalam bentuk hash SHA-256)
  Future<void> setPasscode(String code) async {
    final hash = _hashPasscode(code);
    await _secureStorage.write(key: _passcodeKey, value: hash);
  }

  /// Verifikasi kecocokan kode rahasia input dengan yang tersimpan
  Future<bool> verifyPasscode(String code) async {
    if (code.trim().isEmpty) return false;
    try {
      final savedHash = await _secureStorage.read(key: _passcodeKey);
      if (savedHash == null || savedHash.isEmpty) return false;
      return savedHash == _hashPasscode(code);
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
