import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/mekaar_secure_storage.dart';

final privateContactRepositoryProvider =
    Provider<PrivateContactRepository>((ref) {
  return PrivateContactRepository();
});

class PrivateContactRepository {
  final FlutterSecureStorage _secureStorage;

  static const String _passcodeKey = 'mekaar_private_vault_passcode_hash';
  static const String _saltKey = 'mekaar_private_vault_salt';
  static const String _hiddenRoomsKey = 'mekaar_private_vault_hidden_rooms';
  static const String _hiddenContactsKey = 'mekaar_private_vault_hidden_contacts';
  static const String _slotNamePrefix = 'mekaar_vault_slot_name_';
  static const String _failedAttemptsKey = 'mekaar_vault_failed_attempts';
  static const String _lockedUntilKey = 'mekaar_vault_locked_until';
  static const int _maxAttemptsBeforeLockout = 5;

  String? _cachedSalt;
  String? _cachedHash;
  Set<String>? _cachedHiddenContactUserIds;
  Set<String>? _cachedHiddenRoomIds;
  int? _cachedFailedAttempts;
  DateTime? _cachedLockedUntil;

  PrivateContactRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? MekaarSecureStorage.instance;

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
      final fallbackSalt = _generateSalt();
      _cachedSalt = fallbackSalt;
      return fallbackSalt;
    }
  }

  String _hashWithSalt(String code, String salt) {
    return sha256.convert(utf8.encode('$salt:${code.trim()}')).toString();
  }

  /// Memuat cache hash, salt, & set tersembunyi ke memori untuk verifikasi instan O(1)
  Future<void> preloadCache() async {
    try {
      final salt = await _getOrCreateSalt();
      final hash = await _secureStorage.read(key: _passcodeKey);
      _cachedSalt = salt;
      _cachedHash = hash;
      _cachedHiddenContactUserIds = await getHiddenContactUserIds();
      _cachedHiddenRoomIds = await getHiddenRoomIds();
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Anti-Brute Force Lockout & Rate Limiting (P2-2)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Memeriksa apakah autentikasi vault saat ini sedang di-lockout
  Future<bool> isVaultLockedOut() async {
    final now = DateTime.now().toUtc();
    if (_cachedLockedUntil != null) {
      if (now.isBefore(_cachedLockedUntil!)) {
        return true;
      } else {
        await resetFailedVaultAttempts();
        return false;
      }
    }

    try {
      final lockedUntilStr = await _secureStorage.read(key: _lockedUntilKey);
      if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
        final lockedUntil = DateTime.tryParse(lockedUntilStr)?.toUtc();
        if (lockedUntil != null && now.isBefore(lockedUntil)) {
          _cachedLockedUntil = lockedUntil;
          return true;
        } else {
          await resetFailedVaultAttempts();
          return false;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Sisa waktu lockout dalam detik (0 jika tidak terkunci)
  Future<int> getVaultLockoutRemainingSeconds() async {
    final now = DateTime.now().toUtc();
    DateTime? lockedUntil = _cachedLockedUntil;
    if (lockedUntil == null) {
      try {
        final lockedUntilStr = await _secureStorage.read(key: _lockedUntilKey);
        if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
          lockedUntil = DateTime.tryParse(lockedUntilStr)?.toUtc();
          _cachedLockedUntil = lockedUntil;
        }
      } catch (_) {}
    }

    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      return lockedUntil.difference(now).inSeconds + 1;
    }
    return 0;
  }

  /// Catat percobaan PIN yang gagal dan aktifkan lockout jika mencapai ambang batas
  Future<int> recordFailedVaultAttempt() async {
    int attempts = _cachedFailedAttempts ?? 0;
    if (_cachedFailedAttempts == null) {
      try {
        final val = await _secureStorage.read(key: _failedAttemptsKey);
        attempts = int.tryParse(val ?? '0') ?? 0;
      } catch (_) {
        attempts = 0;
      }
    }

    attempts++;
    _cachedFailedAttempts = attempts;

    try {
      await _secureStorage.write(key: _failedAttemptsKey, value: attempts.toString());
      if (attempts >= _maxAttemptsBeforeLockout) {
        // Jeda 30 detik untuk 5 percobaan pertama, 120 detik jika terus mencoba
        final lockoutDuration = attempts >= 10
            ? const Duration(seconds: 120)
            : const Duration(seconds: 30);
        final lockedUntil = DateTime.now().toUtc().add(lockoutDuration);
        _cachedLockedUntil = lockedUntil;
        await _secureStorage.write(
          key: _lockedUntilKey,
          value: lockedUntil.toIso8601String(),
        );
      }
    } catch (_) {}

    return attempts;
  }

  /// Reset counter percobaan gagal saat verifikasi berhasil
  Future<void> resetFailedVaultAttempts() async {
    _cachedFailedAttempts = 0;
    _cachedLockedUntil = null;
    try {
      await _secureStorage.delete(key: _failedAttemptsKey);
      await _secureStorage.delete(key: _lockedUntilKey);
    } catch (_) {}
  }

  /// Verifikasi kecocokan kode rahasia input internal tanpa pencatatan failed attempt
  Future<bool> _verifyPasscodeInternal(String trimmed) async {
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

  /// Verifikasi kecocokan kode rahasia input secara aman dan cepat
  Future<bool> verifyPasscode(String code) async {
    if (await isVaultLockedOut()) return false;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    final isMatch = await _verifyPasscodeInternal(trimmed);
    if (isMatch) {
      await resetFailedVaultAttempts();
      return true;
    } else {
      await recordFailedVaultAttempt();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Multi-Slot (Slot 1, 2, 3) Support
  // ─────────────────────────────────────────────────────────────────────────────

  String _slotPasscodeKey(int slot) {
    if (slot == 1) return _passcodeKey;
    return '${_passcodeKey}_$slot';
  }

  String _slotSaltKey(int slot) {
    if (slot == 1) return _saltKey;
    return '${_saltKey}_$slot';
  }

  Future<String> _getOrCreateSlotSalt(int slot) async {
    if (slot == 1) return _getOrCreateSalt();
    final key = _slotSaltKey(slot);
    try {
      var salt = await _secureStorage.read(key: key);
      if (salt == null || salt.isEmpty) {
        salt = _generateSalt();
        await _secureStorage.write(key: key, value: salt);
      }
      return salt;
    } catch (_) {
      return _generateSalt();
    }
  }

  /// Memeriksa apakah slot memiliki kode akses terdaftar
  Future<bool> hasSlotPasscode(int slot) async {
    if (slot == 1) return hasPasscode();
    try {
      final hash = await _secureStorage.read(key: _slotPasscodeKey(slot));
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Mengatur kode akses baru untuk slot tertentu
  Future<void> setSlotPasscode(int slot, String code) async {
    if (slot == 1) {
      await setPasscode(code);
      return;
    }
    final salt = await _getOrCreateSlotSalt(slot);
    final hash = _hashWithSalt(code, salt);
    await _secureStorage.write(key: _slotPasscodeKey(slot), value: hash);
  }

  /// Verifikasi kecocokan passcode slot tanpa trigger pencatatan percobaan gagal
  Future<bool> _checkSlotPasscodeNoAttempt(int slot, String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    if (slot == 1) return _verifyPasscodeInternal(trimmed);

    try {
      final salt = await _getOrCreateSlotSalt(slot);
      final savedHash = await _secureStorage.read(key: _slotPasscodeKey(slot));
      if (savedHash == null || savedHash.isEmpty) return false;
      return savedHash == _hashWithSalt(trimmed, salt);
    } catch (_) {
      return false;
    }
  }

  /// Verifikasi kode akses slot tertentu (dengan rate limiting & anti brute force)
  Future<bool> verifySlotPasscode(int slot, String code) async {
    if (await isVaultLockedOut()) return false;
    if (slot == 1) return verifyPasscode(code);

    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;

    final isMatch = await _checkSlotPasscodeNoAttempt(slot, trimmed);
    if (isMatch) {
      await resetFailedVaultAttempts();
      return true;
    } else {
      await recordFailedVaultAttempt();
      return false;
    }
  }

  /// Memeriksa apakah input teks cocok dengan salah satu kode akses slot (1..3).
  /// Mengembalikan nomor slot yang cocok, atau null jika tidak cocok satupun.
  Future<int?> checkAnySlotPasscode(String code) async {
    if (await isVaultLockedOut()) return null;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    for (int slot = 1; slot <= 3; slot++) {
      if (await hasSlotPasscode(slot)) {
        if (await _checkSlotPasscodeNoAttempt(slot, trimmed)) {
          await resetFailedVaultAttempts();
          return slot;
        }
      }
    }
    return null;
  }

  /// Menghapus kode akses slot (khusus slot 2 atau 3 saat slot dihapus)
  /// dan membersihkan nama kustom profil di SharedPreferences (P3-1)
  Future<void> deleteSlotPasscode(int slot) async {
    try {
      await _secureStorage.delete(key: _slotPasscodeKey(slot));
      await _secureStorage.delete(key: _slotSaltKey(slot));
      if (slot == 1) {
        _cachedHash = null;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_slotNamePrefix$slot');
    } catch (_) {}
  }

  /// Mendapatkan nama profil slot dari preferensi lokal
  Future<String> getSlotName(int slot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('$_slotNamePrefix$slot');
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    } catch (_) {}
    return 'Profil $slot';
  }

  /// Mengubah nama profil slot
  Future<void> setSlotName(int slot, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_slotNamePrefix$slot', name.trim());
    } catch (_) {}
  }

  /// Mengembalikan daftar nomor slot yang aktif (memiliki passcode)
  Future<List<int>> getActiveSlots() async {
    final active = <int>[];
    for (int slot = 1; slot <= 3; slot++) {
      if (await hasSlotPasscode(slot)) {
        active.add(slot);
      }
    }
    // Jika belum ada satupun, kembalikan slot 1 sebagai default placeholder
    if (active.isEmpty) {
      active.add(1);
    }
    return active;
  }

  /// Getter sinkron untuk cache memori roomId yang disembunyikan (0ms latency, anti-flash)
  Set<String> get cachedHiddenRoomIds =>
      _cachedHiddenRoomIds != null
          ? Set<String>.from(_cachedHiddenRoomIds!)
          : <String>{};

  /// Dapatkan daftar seluruh ID ruang obrolan yang disembunyikan
  Future<Set<String>> getHiddenRoomIds() async {
    if (_cachedHiddenRoomIds != null) {
      return Set<String>.from(_cachedHiddenRoomIds!);
    }
    try {
      final jsonStr = await _secureStorage.read(key: _hiddenRoomsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        final result = list.map((e) => e.toString()).toSet();
        _cachedHiddenRoomIds = result;
        return result;
      }
    } catch (_) {}
    _cachedHiddenRoomIds = <String>{};
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

    _cachedHiddenRoomIds = Set<String>.from(currentSet);

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

  /// Getter sinkron untuk cache memori contactUserId yang disembunyikan (0ms latency, anti-flash)
  Set<String> get cachedHiddenContactUserIds =>
      _cachedHiddenContactUserIds != null
          ? Set<String>.from(_cachedHiddenContactUserIds!)
          : <String>{};

  /// Dapatkan daftar seluruh contactUserId yang disembunyikan ke Private Vault
  Future<Set<String>> getHiddenContactUserIds() async {
    if (_cachedHiddenContactUserIds != null) {
      return Set<String>.from(_cachedHiddenContactUserIds!);
    }
    try {
      final jsonStr = await _secureStorage.read(key: _hiddenContactsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        final result = list.map((e) => e.toString()).toSet();
        _cachedHiddenContactUserIds = result;
        return result;
      }
    } catch (_) {}
    _cachedHiddenContactUserIds = <String>{};
    return <String>{};
  }

  /// Sembunyikan atau batalkan penyembunyian suatu kontak (berbasis contactUserId)
  /// Mengembalikan true jika kontak sekarang tersembunyi, false jika ditampilkan.
  Future<bool> toggleHideContact(String contactUserId) async {
    final currentSet = await getHiddenContactUserIds();
    final isHidden = currentSet.contains(contactUserId);

    if (isHidden) {
      currentSet.remove(contactUserId);
    } else {
      currentSet.add(contactUserId);
    }

    _cachedHiddenContactUserIds = Set<String>.from(currentSet);

    try {
      final jsonStr = jsonEncode(currentSet.toList());
      await _secureStorage.write(key: _hiddenContactsKey, value: jsonStr);
    } catch (_) {}

    return !isHidden;
  }

  /// Memastikan contactUserId tersimpan ke daftar tersembunyi
  Future<void> hideContact(String contactUserId) async {
    final currentSet = await getHiddenContactUserIds();
    if (!currentSet.contains(contactUserId)) {
      currentSet.add(contactUserId);
      _cachedHiddenContactUserIds = Set<String>.from(currentSet);
      try {
        final jsonStr = jsonEncode(currentSet.toList());
        await _secureStorage.write(key: _hiddenContactsKey, value: jsonStr);
      } catch (_) {}
    }
  }

  /// Hapus contactUserId dari daftar tersembunyi (misal saat kontak dihapus permanen)
  Future<void> removeHiddenContact(String contactUserId) async {
    final currentSet = await getHiddenContactUserIds();
    if (currentSet.remove(contactUserId)) {
      _cachedHiddenContactUserIds = Set<String>.from(currentSet);
      try {
        final jsonStr = jsonEncode(currentSet.toList());
        await _secureStorage.write(key: _hiddenContactsKey, value: jsonStr);
      } catch (_) {}
    }
  }

  /// Periksa apakah seorang kontak disembunyikan
  Future<bool> isContactHidden(String contactUserId) async {
    final currentSet = await getHiddenContactUserIds();
    return currentSet.contains(contactUserId);
  }

  /// Migrasi transparan data legacy: jika ada roomId lama yang disembunyikan,
  /// petakan roomId ke contactUserId dan simpan ke hidden_contacts.
  Future<void> migrateLegacyHiddenRoomsToContacts(
    Map<String, String> roomToUserIdMap,
  ) async {
    if (roomToUserIdMap.isEmpty) return;
    try {
      final hiddenRooms = await getHiddenRoomIds();
      if (hiddenRooms.isEmpty) return;

      final hiddenContacts = await getHiddenContactUserIds();
      bool changed = false;

      for (final entry in roomToUserIdMap.entries) {
        if (hiddenRooms.contains(entry.key)) {
          if (!hiddenContacts.contains(entry.value)) {
            hiddenContacts.add(entry.value);
            changed = true;
          }
        }
      }

      if (changed) {
        _cachedHiddenContactUserIds = Set<String>.from(hiddenContacts);
        final jsonStr = jsonEncode(hiddenContacts.toList());
        await _secureStorage.write(key: _hiddenContactsKey, value: jsonStr);
      }
    } catch (_) {}
  }
}
