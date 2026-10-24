import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/vault_item.dart';
import 'database_key_service.dart';

/// Database SQLite lokal terenkripsi (SQLCipher AES-256) untuk Brankas Berkas.
///
/// Fitur Keamanan:
/// 1. Terkunci matematis menggunakan KDF (PBKDF2) dari Master PIN pengguna.
/// 2. Isolasi Decoy Vault: Saat Duress PIN dimasukkan, membuka `mekaar_vault_decoy.db`
///    terpisah; database master tidak disentuh atau dimuat ke memori sama sekali.
/// 3. Migrasi otomatis dari SQLite plaintext legacy disertai pemusnahan forensik (*shredding*).
class LocalVaultDatabase {
  LocalVaultDatabase._();
  static final LocalVaultDatabase instance = LocalVaultDatabase._();

  static final Logger _logger = Logger();
  static const String _tableName = 'vault_items';
  static const String _masterDbFileName = 'mekaar_vault.db';
  static const String _decoyDbFileName = 'mekaar_vault_decoy.db';
  static const int _dbVersion = 1;

  Database? _db;
  Completer<Database>? _dbInitCompleter;
  bool _isDuressActive = false;

  /// Memeriksa apakah brankas sedang dalam status terbuka
  bool get isUnlocked => _db != null && _db!.isOpen;

  /// Memeriksa apakah database yang terbuka saat ini adalah Decoy (Duress)
  bool get isDuress => _isDuressActive;

  /// Membuka brankas berkas menggunakan kunci enkripsi SQLCipher yang diturunkan dari PIN.
  Future<Database> openVault({required String key, required bool isDuress}) async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbInitCompleter = null;
    }

    _isDuressActive = isDuress;
    _dbInitCompleter = Completer<Database>();

    try {
      final dbPath = await getDatabasesPath();
      final fileName = isDuress ? _decoyDbFileName : _masterDbFileName;
      final path = '$dbPath/$fileName';

      // Jika master vault, cek dan migrasikan jika file lokal masih berupa SQLite plaintext legacy
      if (!isDuress) {
        await _checkAndMigrateLegacyPlaintextDb(path, key);
      }

      try {
        _db = await openDatabase(
          path,
          password: key,
          version: _dbVersion,
          onCreate: _onCreate,
        );
      } catch (openErr) {
        // Coba auto-migrasi dari legacy SQLCipher key jika db sudah ada tapi belum di-rekey ke Argon2id v2
        final legacyKey = DatabaseKeyService.instance.activeLegacyVaultKey;
        if (legacyKey != null && await File(path).exists()) {
          _logger.w('Mencoba membuka brankas dengan legacy PBKDF2 key dan re-key ke Argon2id v2...');
          _db = await openDatabase(
            path,
            password: legacyKey,
            version: _dbVersion,
            onCreate: _onCreate,
          );
          // Rekey SQLCipher database ke key Argon2id v2 yang baru
          await _db!.execute("PRAGMA rekey = '$key';");
          _logger.i('✅ Rekey database brankas ke Argon2id v2 berhasil!');
        } else {
          rethrow;
        }
      }

      _dbInitCompleter!.complete(_db!);
      return _db!;
    } catch (e, stack) {
      _logger.e('Gagal menginisialisasi database brankas SQLCipher: $e', error: e, stackTrace: stack);
      _dbInitCompleter?.completeError(e, stack);
      _dbInitCompleter = null;
      rethrow;
    }
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    if (_dbInitCompleter != null) {
      return _dbInitCompleter!.future;
    }

    final activeKey = DatabaseKeyService.instance.activeVaultKey;
    if (activeKey == null) {
      throw StateError('Brankas berkas terkunci. Verifikasi PIN diperlukan untuk membuka database.');
    }

    return openVault(
      key: activeKey,
      isDuress: DatabaseKeyService.instance.isVaultDuress,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        original_message_id TEXT,
        file_name TEXT NOT NULL,
        file_type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        mime_type TEXT,
        sender_name TEXT,
        sender_id TEXT,
        room_id TEXT,
        saved_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_vault_file_type ON $_tableName(file_type)',
    );
    await db.execute(
      'CREATE INDEX idx_vault_saved_at ON $_tableName(saved_at DESC)',
    );
  }

  /// Memeriksa apakah file lokal masih berformat SQLite teks polos (legacy).
  /// Jika ya, migrasikan datanya ke database SQLCipher terenkripsi, lalu musnahkan file lama.
  Future<void> _checkAndMigrateLegacyPlaintextDb(String path, String key) async {
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final raf = await file.open(mode: FileMode.read);
      final headerBytes = await raf.read(16);
      await raf.close();

      const sqliteMagic = [
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
        0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
      ];

      bool isLegacyPlaintext = true;
      if (headerBytes.length >= 16) {
        for (int i = 0; i < 16; i++) {
          if (headerBytes[i] != sqliteMagic[i]) {
            isLegacyPlaintext = false;
            break;
          }
        }
      } else {
        isLegacyPlaintext = false;
      }

      if (!isLegacyPlaintext) return;

      _logger.w('⚠️ Terdeteksi database brankas lama (plaintext). Memulai auto-migrasi ke SQLCipher...');
      final legacyPath = '$path.legacy_plaintext';
      await file.rename(legacyPath);

      final legacyDb = await openDatabase(legacyPath);
      List<Map<String, dynamic>> rows = [];
      try {
        rows = await legacyDb.query(_tableName);
      } catch (_) {}
      await legacyDb.close();

      final encryptedDb = await openDatabase(
        path,
        password: key,
        version: _dbVersion,
        onCreate: _onCreate,
      );

      if (rows.isNotEmpty) {
        final batch = encryptedDb.batch();
        for (final row in rows) {
          batch.insert(_tableName, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
      await encryptedDb.close();

      await DatabaseKeyService.instance.shredFile(File(legacyPath));
      _logger.i('✅ Auto-migrasi brankas ke SQLCipher selesai. File plaintext lama telah dimusnahkan secara forensik.');
    } catch (e, st) {
      _logger.e('Gagal melakukan migrasi database brankas legacy: $e', error: e, stackTrace: st);
    }
  }

  /// Memasukkan item berkas baru ke brankas.
  Future<void> insertItem(VaultItem item) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.e('Gagal menyimpan item ke brankas: $e');
      rethrow;
    }
  }

  /// Mengambil daftar item brankas dengan filter tipe dan query pencarian opsional.
  Future<List<VaultItem>> getItems({
    VaultFileType? filter,
    String? query,
  }) async {
    try {
      final db = await database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (filter != null) {
        whereClauses.add('file_type = ?');
        whereArgs.add(filter.name);
      }

      if (query != null && query.trim().isNotEmpty) {
        whereClauses.add('(file_name LIKE ? OR sender_name LIKE ?)');
        final escaped = '%${query.trim()}%';
        whereArgs.add(escaped);
        whereArgs.add(escaped);
      }

      final whereString =
          whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final results = await db.query(
        _tableName,
        where: whereString,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'saved_at DESC',
      );

      return results.map((map) => VaultItem.fromMap(map)).toList();
    } catch (e) {
      _logger.e('Gagal memuat item brankas: $e');
      return [];
    }
  }

  /// Mengambil satu item berdasarkan ID.
  Future<VaultItem?> getItemById(String id) async {
    try {
      final db = await database;
      final results = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return VaultItem.fromMap(results.first);
    } catch (e) {
      _logger.e('Gagal mengambil item brankas by ID: $e');
      return null;
    }
  }

  /// Menghapus catatan item dari database brankas.
  Future<int> deleteItem(String id) async {
    try {
      final db = await database;
      return await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logger.e('Gagal menghapus item dari brankas: $e');
      return 0;
    }
  }

  /// Menghitung jumlah berkas di brankas berdasarkan tipe.
  Future<int> countItems({VaultFileType? filter}) async {
    try {
      final db = await database;
      String? whereString;
      List<dynamic>? whereArgs;

      if (filter != null) {
        whereString = 'file_type = ?';
        whereArgs = [filter.name];
      }

      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName${whereString != null ? " WHERE $whereString" : ""}',
        whereArgs,
      );

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      _logger.e('Gagal menghitung item brankas: $e');
      return 0;
    }
  }

  /// Menutup koneksi database (untuk testing atau saat reset akun).
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbInitCompleter = null;
    }
  }
}
