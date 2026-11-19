import 'dart:async';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/vault_item.dart';
import 'aegis_memory_guard_service.dart';
import 'aegis_stream_cipher_service.dart';
import 'database_key_service.dart';

/// Database SQLite lokal terenkripsi (SQLCipher AES-256) untuk Brankas Berkas 3-Jalur.
///
/// Fitur Keamanan:
/// 1. Terkunci matematis menggunakan KDF (Argon2id / PBKDF2 legacy) per jalur masuk:
///    - Master (`mekaar_vault.db`)
///    - Guest (`mekaar_vault_guest.db`)
///    - Duress (`mekaar_vault_decoy.db`)
/// 2. Database antar ruang terisolasi fisik dan kriptografis secara total.
/// 3. Migrasi otomatis dari SQLite plaintext legacy khusus ruang Master disertai shredding.
class LocalVaultDatabase {
  LocalVaultDatabase._();
  static final LocalVaultDatabase instance = LocalVaultDatabase._();

  static final Logger _logger = Logger();
  static const String _tableName = 'vault_items';
  static const int _dbVersion = 1;

  Database? _db;
  Completer<Database>? _dbInitCompleter;
  VaultSpace _activeSpace = VaultSpace.master;

  /// Memeriksa apakah brankas sedang dalam status terbuka
  bool get isUnlocked => _db != null && _db!.isOpen;

  /// Ruang brankas yang sedang aktif saat ini.
  VaultSpace get activeSpace => _activeSpace;

  /// Memeriksa apakah database yang terbuka saat ini adalah Decoy (Duress)
  bool get isDuress => _activeSpace == VaultSpace.duress;

  /// Membuka brankas berkas menggunakan kunci enkripsi SQLCipher yang diturunkan dari PIN.
  Future<Database> openVault({
    required String key,
    bool isDuress = false,
    VaultSpace? space,
    String? pin,
  }) async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbInitCompleter = null;
    }

    final resolvedSpace = DatabaseKeyService.resolveVaultSpace(
      space: space,
      isDuress: isDuress,
    );
    _activeSpace = resolvedSpace;
    _dbInitCompleter = Completer<Database>();

    try {
      final dbPath = await getDatabasesPath();
      final fileName = resolvedSpace.dbFileName;
      final path = '$dbPath/$fileName';

      // Jika master vault, cek dan migrasikan jika file lokal masih berupa SQLite plaintext legacy
      if (resolvedSpace == VaultSpace.master) {
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
        var legacyKey = DatabaseKeyService.instance.activeLegacyVaultKey;
        if (legacyKey == null && pin != null && pin.isNotEmpty) {
          try {
            legacyKey = await DatabaseKeyService.instance.deriveLegacyVaultKey(
              pin,
              space: resolvedSpace,
            );
          } catch (_) {}
        }
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

  /// Melakukan re-keying database brankas dan berkas `.aegis` yang sedang terbuka
  /// ketika PIN pemilik jalur tersebut diubah (misalnya Honeypot Decoy Swap di Guest Mode).
  Future<bool> rekeyOpenVault({
    required VaultSpace space,
    required String newPin,
  }) async {
    if (_db == null || !_db!.isOpen || _activeSpace != space) {
      return false;
    }

    final oldSlotId = DatabaseKeyService.instance.activeVaultKeySlotId;
    final derived = await DatabaseKeyService.instance.deriveVaultKeyForRekey(
      newPin,
      space: space,
    );

    await _db!.execute("PRAGMA rekey = '${derived.key}';");

    if (oldSlotId != null && derived.slotId != null && oldSlotId != derived.slotId) {
      final rows = await _db!.query(_tableName);
      for (final row in rows) {
        final item = VaultItem.fromMap(row);
        if (!item.localPath.endsWith('.aegis')) continue;
        final encFile = File(item.localPath);
        if (!await encFile.exists()) continue;

        File? tempPlain;
        final rekeyPath = '${item.localPath}.rekey';
        try {
          tempPlain = await AegisStreamCipherService.instance.decryptToTempFile(
            encryptedPath: item.localPath,
            keySlotId: oldSlotId,
            fileExtension: item.fileName.split('.').last,
          );
          await AegisStreamCipherService.instance.encryptFileStream(
            srcPath: tempPlain.path,
            dstPath: rekeyPath,
            keySlotId: derived.slotId!,
          );
          await File(rekeyPath).rename(item.localPath);
        } catch (e) {
          _logger.w('Gagal re-enkripsi berkas brankas ${item.fileName}: $e');
          try {
            await DatabaseKeyService.instance.shredFile(File(rekeyPath));
          } catch (_) {}
        } finally {
          if (tempPlain != null) {
            try {
              await DatabaseKeyService.instance.shredFile(tempPlain);
            } catch (_) {}
          }
        }
      }
    }

    DatabaseKeyService.instance.setActiveVaultKey(
      derived.key,
      space: space,
      slotId: derived.slotId,
    );

    if (oldSlotId != null && derived.slotId != null && oldSlotId != derived.slotId) {
      try {
        await AegisMemoryGuardService.instance.zeroizeKey(oldSlotId);
      } catch (_) {}
    }

    return true;
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
      space: DatabaseKeyService.instance.activeVaultSpace,
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
    _activeSpace = VaultSpace.master;
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbInitCompleter = null;
    }
  }
}
