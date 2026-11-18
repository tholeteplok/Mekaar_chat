import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:logger/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/group_sender_key_models.dart';
import 'local_message_database.dart';

/// Kontrak penyimpanan state sender key kriptografi grup (Chain Key, Skipped Keys, Counter).
abstract class SenderKeyStore {
  /// Menyimpan atau memperbarui sender key milik kita sendiri untuk grup tertentu.
  Future<void> saveOurSenderKey(SenderKeyRecord record);

  /// Mengambil sender key aktif milik kita sendiri untuk grup tertentu.
  Future<SenderKeyRecord?> getOurSenderKey(String groupId);

  /// Menghapus sender key milik kita sendiri (misal saat keluar dari grup).
  Future<void> deleteOurSenderKey(String groupId);

  /// Menyimpan atau memperbarui state sender key milik anggota lain.
  Future<void> saveSenderState(SenderKeyState state);

  /// Mengambil state sender key milik anggota lain untuk grup, pengirim, dan keyId spesifik.
  Future<SenderKeyState?> getSenderState(
    String groupId,
    String senderId,
    int keyId,
  );

  /// Menghapus state sender key anggota lain untuk grup, pengirim, dan keyId spesifik.
  Future<void> deleteSenderState(
    String groupId,
    String senderId,
    int keyId,
  );

  /// Menghapus seluruh state sender key untuk seorang anggota dalam suatu grup (misal saat anggota di-kick/keluar).
  Future<void> deleteSenderStatesForSender(String groupId, String senderId);

  /// Menghapus seluruh state sender key untuk suatu grup (misal saat grup dihapus atau di-reset).
  Future<void> deleteSenderStatesForGroup(String groupId);

  /// Membersihkan seluruh kunci pengirim kita dan state anggota untuk suatu grup (misal saat keluar grup).
  Future<void> clearGroup(String groupId);

  /// Menyimpan message key yang terlewati saat pesan tiba di luar urutan (out-of-order).
  Future<void> saveSkippedKey(SkippedMessageKey skippedKey);

  /// Mengambil dan **seketika menghapus** message key terlewati dari penyimpanan (Zeroisasi/Forward Secrecy).
  /// Mengembalikan `null` jika kunci tidak ditemukan atau sudah pernah dipakai.
  Future<SkippedMessageKey?> takeSkippedKey(
    String groupId,
    String senderId,
    int keyId,
    int counter,
  );

  /// Menghitung jumlah skipped keys yang saat ini disimpan untuk pengirim tertentu.
  Future<int> getSkippedKeyCount(
    String groupId,
    String senderId,
    int keyId,
  );

  /// Membersihkan skipped keys yang sudah kedaluwarsa.
  Future<void> purgeExpiredSkippedKeys([DateTime? now]);

  /// Mengambil daftar ID anggota terakhir yang diketahui untuk suatu grup secara persisten.
  /// Digunakan untuk mendeteksi penyusutan keanggotaan (membership shrink) bahkan setelah aplikasi di-restart.
  Future<List<String>?> getLastKnownMemberIds(String groupId);

  /// Menyimpan daftar ID anggota terakhir yang diketahui untuk suatu grup secara persisten.
  Future<void> saveLastKnownMemberIds(String groupId, List<String> memberIds);

  /// Menghapus seluruh state sender key (misal saat logout atau wipe).
  Future<void> clearAll();
}

/// Implementasi penyimpanan SenderKeyStore berbasis memori (In-Memory).
/// Digunakan untuk unit testing, lingkungan headless, atau isolasi deterministik.
class InMemorySenderKeyStore implements SenderKeyStore {
  final Map<String, SenderKeyRecord> _ourKeys = {};
  final Map<String, SenderKeyState> _senderStates = {};
  final Map<String, SkippedMessageKey> _skippedKeys = {};
  final Map<String, List<String>> _persistedMemberIds = {};

  String _senderStateKey(String groupId, String senderId, int keyId) =>
      '$groupId:$senderId:$keyId';

  String _skippedKeyId(
    String groupId,
    String senderId,
    int keyId,
    int counter,
  ) =>
      '$groupId:$senderId:$keyId:$counter';

  @override
  Future<void> saveOurSenderKey(SenderKeyRecord record) async {
    _ourKeys[record.groupId] = record;
  }

  @override
  Future<SenderKeyRecord?> getOurSenderKey(String groupId) async {
    return _ourKeys[groupId];
  }

  @override
  Future<void> deleteOurSenderKey(String groupId) async {
    _ourKeys.remove(groupId);
  }

  @override
  Future<void> saveSenderState(SenderKeyState state) async {
    final key = _senderStateKey(state.groupId, state.senderId, state.keyId);
    _senderStates[key] = state;
  }

  @override
  Future<SenderKeyState?> getSenderState(
    String groupId,
    String senderId,
    int keyId,
  ) async {
    final key = _senderStateKey(groupId, senderId, keyId);
    return _senderStates[key];
  }

  @override
  Future<void> deleteSenderState(
    String groupId,
    String senderId,
    int keyId,
  ) async {
    final key = _senderStateKey(groupId, senderId, keyId);
    _senderStates.remove(key);
  }

  @override
  Future<void> deleteSenderStatesForSender(String groupId, String senderId) async {
    _senderStates.removeWhere((k, _) => k.startsWith('$groupId:$senderId:'));
    _skippedKeys.removeWhere((k, _) => k.startsWith('$groupId:$senderId:'));
  }

  @override
  Future<void> deleteSenderStatesForGroup(String groupId) async {
    _senderStates.removeWhere((k, _) => k.startsWith('$groupId:'));
    _skippedKeys.removeWhere((k, _) => k.startsWith('$groupId:'));
  }

  @override
  Future<void> clearGroup(String groupId) async {
    await deleteOurSenderKey(groupId);
    await deleteSenderStatesForGroup(groupId);
    _persistedMemberIds.remove(groupId);
  }

  @override
  Future<List<String>?> getLastKnownMemberIds(String groupId) async {
    final list = _persistedMemberIds[groupId];
    return list != null ? List<String>.from(list) : null;
  }

  @override
  Future<void> saveLastKnownMemberIds(String groupId, List<String> memberIds) async {
    final sorted = List<String>.from(memberIds)..sort();
    _persistedMemberIds[groupId] = sorted;
  }

  @override
  Future<void> saveSkippedKey(SkippedMessageKey skippedKey) async {
    final key = _skippedKeyId(
      skippedKey.groupId,
      skippedKey.senderId,
      skippedKey.keyId,
      skippedKey.counter,
    );
    _skippedKeys[key] = skippedKey;
  }

  @override
  Future<SkippedMessageKey?> takeSkippedKey(
    String groupId,
    String senderId,
    int keyId,
    int counter,
  ) async {
    final key = _skippedKeyId(groupId, senderId, keyId, counter);
    final found = _skippedKeys.remove(key);
    if (found != null && found.expiresAt.isBefore(DateTime.now())) {
      return null;
    }
    return found;
  }

  @override
  Future<int> getSkippedKeyCount(
    String groupId,
    String senderId,
    int keyId,
  ) async {
    final prefix = '$groupId:$senderId:$keyId:';
    return _skippedKeys.keys.where((k) => k.startsWith(prefix)).length;
  }

  @override
  Future<void> purgeExpiredSkippedKeys([DateTime? now]) async {
    final threshold = now ?? DateTime.now();
    _skippedKeys.removeWhere((_, v) => v.expiresAt.isBefore(threshold));
  }

  @override
  Future<void> clearAll() async {
    _ourKeys.clear();
    _senderStates.clear();
    _skippedKeys.clear();
    _persistedMemberIds.clear();
  }
}

/// Implementasi penyimpanan SenderKeyStore berbasis SQLCipher (AES-256 terenkripsi lokal).
/// Menggunakan tabel di LocalMessageDatabase untuk menjamin persistensi aman at-rest.
class SqlCipherSenderKeyStore implements SenderKeyStore {
  SqlCipherSenderKeyStore._();
  static final SqlCipherSenderKeyStore instance = SqlCipherSenderKeyStore._();

  static final Logger _logger = Logger();
  static const String tableOurKeys = 'group_sender_keys';
  static const String tableSenderStates = 'group_sender_states';
  static const String tableSkippedKeys = 'group_skipped_keys';
  static const String tableMembershipTracker = 'group_membership_tracker';

  static final Ed25519 _ed25519 = Ed25519();

  Future<Database> get _db async => await LocalMessageDatabase.instance.database;

  /// Inisialisasi skema tabel SQLCipher untuk sender keys (dipanggil pada open/upgrade DB).
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOurKeys (
        group_id TEXT PRIMARY KEY,
        key_id INTEGER NOT NULL,
        chain_key TEXT NOT NULL,
        signing_seed TEXT NOT NULL,
        signing_pub_key TEXT NOT NULL,
        counter INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSenderStates (
        group_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        key_id INTEGER NOT NULL,
        chain_key TEXT NOT NULL,
        signing_pub_key TEXT NOT NULL,
        counter INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (group_id, sender_id, key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSkippedKeys (
        group_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        key_id INTEGER NOT NULL,
        counter INTEGER NOT NULL,
        message_key TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        PRIMARY KEY (group_id, sender_id, key_id, counter)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMembershipTracker (
        group_id TEXT PRIMARY KEY,
        member_ids TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<void> saveOurSenderKey(SenderKeyRecord record) async {
    try {
      final db = await _db;
      final seed = await record.signingKeyPair.extractPrivateKeyBytes();
      await db.insert(
        tableOurKeys,
        {
          'group_id': record.groupId,
          'key_id': record.keyId,
          'chain_key': base64Encode(record.chainKey),
          'signing_seed': base64Encode(seed),
          'signing_pub_key': base64Encode(record.signingPublicKeyBytes),
          'counter': record.counter,
          'created_at': record.createdAt.toIso8601String(),
          'updated_at': record.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Gagal menyimpan our sender key: $e');
      rethrow;
    }
  }

  @override
  Future<SenderKeyRecord?> getOurSenderKey(String groupId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        tableOurKeys,
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;

      final seed = base64Decode(row['signing_seed'] as String);
      final keyPair = await _ed25519.newKeyPairFromSeed(seed);
      final pubKeyBytes = base64Decode(row['signing_pub_key'] as String);

      return SenderKeyRecord(
        groupId: row['group_id'] as String,
        keyId: row['key_id'] as int,
        chainKey: base64Decode(row['chain_key'] as String),
        signingKeyPair: keyPair,
        signingPublicKeyBytes: pubKeyBytes,
        counter: row['counter'] as int,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    } catch (e) {
      _logger.w('Gagal membaca our sender key untuk grup $groupId: $e');
      return null;
    }
  }

  @override
  Future<void> deleteOurSenderKey(String groupId) async {
    try {
      final db = await _db;
      await db.delete(
        tableOurKeys,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    } catch (e) {
      _logger.e('Gagal menghapus our sender key: $e');
    }
  }

  @override
  Future<void> saveSenderState(SenderKeyState state) async {
    try {
      final db = await _db;
      await db.insert(
        tableSenderStates,
        {
          'group_id': state.groupId,
          'sender_id': state.senderId,
          'key_id': state.keyId,
          'chain_key': base64Encode(state.chainKey),
          'signing_pub_key': base64Encode(state.signingPublicKeyBytes),
          'counter': state.counter,
          'updated_at': state.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Gagal menyimpan sender state: $e');
      rethrow;
    }
  }

  @override
  Future<SenderKeyState?> getSenderState(
    String groupId,
    String senderId,
    int keyId,
  ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        tableSenderStates,
        where: 'group_id = ? AND sender_id = ? AND key_id = ?',
        whereArgs: [groupId, senderId, keyId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;

      return SenderKeyState(
        groupId: row['group_id'] as String,
        senderId: row['sender_id'] as String,
        keyId: row['key_id'] as int,
        chainKey: base64Decode(row['chain_key'] as String),
        signingPublicKeyBytes:
            base64Decode(row['signing_pub_key'] as String),
        counter: row['counter'] as int,
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    } catch (e) {
      _logger.w('Gagal membaca sender state ($groupId, $senderId, $keyId): $e');
      return null;
    }
  }

  @override
  Future<void> deleteSenderState(
    String groupId,
    String senderId,
    int keyId,
  ) async {
    try {
      final db = await _db;
      await db.delete(
        tableSenderStates,
        where: 'group_id = ? AND sender_id = ? AND key_id = ?',
        whereArgs: [groupId, senderId, keyId],
      );
    } catch (e) {
      _logger.e('Gagal menghapus sender state: $e');
    }
  }

  @override
  Future<void> deleteSenderStatesForSender(String groupId, String senderId) async {
    try {
      final db = await _db;
      await db.delete(
        tableSenderStates,
        where: 'group_id = ? AND sender_id = ?',
        whereArgs: [groupId, senderId],
      );
      await db.delete(
        tableSkippedKeys,
        where: 'group_id = ? AND sender_id = ?',
        whereArgs: [groupId, senderId],
      );
    } catch (e) {
      _logger.e('Gagal menghapus sender states ($groupId, $senderId): $e');
    }
  }

  @override
  Future<void> deleteSenderStatesForGroup(String groupId) async {
    try {
      final db = await _db;
      await db.delete(
        tableSenderStates,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      await db.delete(
        tableSkippedKeys,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    } catch (e) {
      _logger.e('Gagal menghapus sender states grup $groupId: $e');
    }
  }

  @override
  Future<void> clearGroup(String groupId) async {
    try {
      final db = await _db;
      await deleteOurSenderKey(groupId);
      await deleteSenderStatesForGroup(groupId);
      await db.delete(
        tableMembershipTracker,
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    } catch (e) {
      _logger.e('Gagal clear group $groupId: $e');
    }
  }

  @override
  Future<List<String>?> getLastKnownMemberIds(String groupId) async {
    try {
      final db = await _db;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableMembershipTracker (
          group_id TEXT PRIMARY KEY,
          member_ids TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      final rows = await db.query(
        tableMembershipTracker,
        where: 'group_id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final raw = rows.first['member_ids'] as String;
      final list = (jsonDecode(raw) as List).cast<String>();
      return list;
    } catch (e) {
      _logger.w('Gagal membaca last known member IDs untuk grup $groupId: $e');
      return null;
    }
  }

  @override
  Future<void> saveLastKnownMemberIds(String groupId, List<String> memberIds) async {
    try {
      final db = await _db;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableMembershipTracker (
          group_id TEXT PRIMARY KEY,
          member_ids TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      final sorted = List<String>.from(memberIds)..sort();
      await db.insert(
        tableMembershipTracker,
        {
          'group_id': groupId,
          'member_ids': jsonEncode(sorted),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Gagal menyimpan last known member IDs untuk grup $groupId: $e');
      rethrow;
    }
  }

  @override
  Future<void> saveSkippedKey(SkippedMessageKey skippedKey) async {
    try {
      final db = await _db;
      await db.insert(
        tableSkippedKeys,
        {
          'group_id': skippedKey.groupId,
          'sender_id': skippedKey.senderId,
          'key_id': skippedKey.keyId,
          'counter': skippedKey.counter,
          'message_key': base64Encode(skippedKey.messageKey),
          'expires_at': skippedKey.expiresAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Gagal menyimpan skipped message key: $e');
      rethrow;
    }
  }

  @override
  Future<SkippedMessageKey?> takeSkippedKey(
    String groupId,
    String senderId,
    int keyId,
    int counter,
  ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        tableSkippedKeys,
        where:
            'group_id = ? AND sender_id = ? AND key_id = ? AND counter = ?',
        whereArgs: [groupId, senderId, keyId, counter],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;

      // Seketika hapus kunci dari DB (Zeroisasi Forward Secrecy)
      await db.delete(
        tableSkippedKeys,
        where:
            'group_id = ? AND sender_id = ? AND key_id = ? AND counter = ?',
        whereArgs: [groupId, senderId, keyId, counter],
      );

      final expiresAt = DateTime.parse(row['expires_at'] as String);
      if (expiresAt.isBefore(DateTime.now())) {
        return null;
      }

      return SkippedMessageKey(
        groupId: row['group_id'] as String,
        senderId: row['sender_id'] as String,
        keyId: row['key_id'] as int,
        counter: row['counter'] as int,
        messageKey: base64Decode(row['message_key'] as String),
        expiresAt: expiresAt,
      );
    } catch (e) {
      _logger.w('Gagal mengambil skipped key: $e');
      return null;
    }
  }

  @override
  Future<int> getSkippedKeyCount(
    String groupId,
    String senderId,
    int keyId,
  ) async {
    try {
      final db = await _db;
      final count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $tableSkippedKeys WHERE group_id = ? AND sender_id = ? AND key_id = ?',
        [groupId, senderId, keyId],
      ));
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> purgeExpiredSkippedKeys([DateTime? now]) async {
    try {
      final db = await _db;
      final threshold = (now ?? DateTime.now()).toIso8601String();
      await db.delete(
        tableSkippedKeys,
        where: 'expires_at < ?',
        whereArgs: [threshold],
      );
    } catch (e) {
      _logger.w('Gagal membersihkan skipped keys kedaluwarsa: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _db;
      await db.delete(tableOurKeys);
      await db.delete(tableSenderStates);
      await db.delete(tableSkippedKeys);
      await db.delete(tableMembershipTracker);
    } catch (e) {
      _logger.e('Gagal clear all sender keys: $e');
    }
  }
}
