import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/chat_draft_model.dart';
import '../models/message_model.dart';
import 'database_key_service.dart';

/// Database lokal SQLite terenkripsi (SQLCipher AES-256) untuk persistensi pesan yang sudah didekripsi.
///
/// Menyediakan akses offline 0ms ke riwayat obrolan, mengeliminasi kebutuhan
/// untuk mendekripsi ulang setiap pesan dari cloud server saat aplikasi dibuka kembali,
/// dan mencegah kebocoran forensik fisik (at-rest) jika perangkat di-root atau di-ekstrak via ADB.
class LocalMessageDatabase {
  LocalMessageDatabase._();
  static final LocalMessageDatabase instance = LocalMessageDatabase._();

  static final Logger _logger = Logger();
  static const String _tableName = 'local_messages';
  static const String _roomsCacheTableName = 'local_rooms_cache';
  static const String _draftsTableName = 'chat_drafts';
  static const String _masterDbFileName = 'mekaar_local_messages.db';
  static const String _decoyDbFileName = 'mekaar_decoy.db';
  static const int _dbVersion = 3;

  Database? _db;
  Completer<Database>? _dbInitCompleter;
  bool _isDecoy = false;

  /// Status apakah database yang aktif saat ini adalah mode Decoy
  bool get isDecoy => _isDecoy;

  /// Beralih mode antara database master dan decoy.
  /// Menutup database yang sedang terbuka bila mode berubah.
  Future<void> switchMode({required bool isDecoy}) async {
    if (_isDecoy == isDecoy && _db != null && _db!.isOpen) return;

    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
      _dbInitCompleter = null;
    }
    _isDecoy = isDecoy;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    if (_dbInitCompleter != null) {
      return _dbInitCompleter!.future;
    }

    _dbInitCompleter = Completer<Database>();
    try {
      final dbPath = await getDatabasesPath();
      final fileName = _isDecoy ? _decoyDbFileName : _masterDbFileName;
      final path = '$dbPath/$fileName';
      final key = _isDecoy
          ? await DatabaseKeyService.instance.getDecoyMessageDatabaseKey()
          : await DatabaseKeyService.instance.getMessageDatabaseKey();

      if (!_isDecoy) {
        // Cek dan migrasikan jika file lokal masih berupa database SQLite plaintext legacy
        await _checkAndMigrateLegacyPlaintextDb(path, key);
      }

      _db = await openDatabase(
        path,
        password: key,
        version: _dbVersion,
        onCreate: (db, version) async {
          await _onCreate(db, version);
          await _createRoomsCacheTable(db);
          await _createDraftsTable(db);
          if (_isDecoy) {
            await _seedDecoyWelcomeMessage(db);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createRoomsCacheTable(db);
          }
          if (oldVersion < 3) {
            await _createDraftsTable(db);
          }
        },
      );

      _dbInitCompleter!.complete(_db!);
      return _db!;
    } catch (e, st) {
      _logger.e('Gagal menginisialisasi LocalMessageDatabase SQLCipher: $e', error: e, stackTrace: st);
      _dbInitCompleter?.completeError(e, st);
      rethrow;
    } finally {
      _dbInitCompleter = null;
    }
  }

  Future<void> _seedDecoyWelcomeMessage(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert(_tableName, {
      'id': 'msg_welcome_decoy',
      'room_id': 'room_welcome_mekaar',
      'sender_id': 'mekaar_official',
      'content': 'Selamat datang di Mekaar Chat! Pesan dan privasi Anda terlindungi dengan enkripsi end-to-end terstandar. Mulai percakapan aman Anda sekarang.',
      'media_url': null,
      'msg_type': 'text',
      'is_view_once': 0,
      'is_opened': 1,
      'opened_at': now,
      'reply_to_id': null,
      'is_deleted': 0,
      'is_silent_deleted': 0,
      'auto_delete_at': null,
      'edited_at': null,
      'reactions': '{}',
      'created_at': now,
      'updated_at': now,
      'is_encrypted': 0,
    });
  }

  /// Mengembalikan daftar kamar decoy alami untuk mode tamu / duress
  Future<List<Map<String, dynamic>>> getDecoyRooms() async {
    Message? lastMsg;
    if (_db != null && _db!.isOpen) {
      try {
        lastMsg = await getLastActiveMessageForRoom('room_welcome_mekaar');
      } catch (_) {}
    }
    final createdAt = lastMsg?.createdAt ?? DateTime.now();
    final content = lastMsg?.content ??
        'Selamat datang di Mekaar Chat! Pesan dan privasi Anda terlindungi dengan enkripsi end-to-end terstandar.';
    return [
      {
        'id': 'room_welcome_mekaar',
        'room_id': 'room_welcome_mekaar',
        'roomType': 'direct',
        'room_type': 'direct',
        'name': 'Mekaar Official',
        'chat_name': 'Mekaar Official',
        'avatar': 'M',
        'avatarUrl': null,
        'avatar_url': null,
        'otherUserId': 'mekaar_official',
        'other_user_id': 'mekaar_official',
        'isGuardian': false,
        'is_guardian': false,
        'isGroup': false,
        'is_group': false,
        'isMuted': false,
        'is_muted': false,
        'isArchived': false,
        'is_archived': false,
        'unreadCount': 0,
        'unread_count': 0,
        'memberCount': 2,
        'member_count': 2,
        'timestamp': createdAt,
        'lastMessage': content,
        'last_message': content,
      }
    ];
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        media_url TEXT,
        msg_type TEXT NOT NULL,
        is_view_once INTEGER NOT NULL DEFAULT 0,
        is_opened INTEGER NOT NULL DEFAULT 0,
        opened_at TEXT,
        reply_to_id TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_silent_deleted INTEGER NOT NULL DEFAULT 0,
        auto_delete_at TEXT,
        edited_at TEXT,
        reactions TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_encrypted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_messages_room_created
      ON $_tableName (room_id, created_at ASC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_messages_auto_delete
      ON $_tableName (auto_delete_at)
    ''');
  }

  Future<void> _createRoomsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_roomsCacheTableName (
        room_id TEXT PRIMARY KEY,
        room_type TEXT NOT NULL,
        chat_name TEXT NOT NULL,
        avatar_url TEXT,
        other_user_id TEXT,
        is_guardian INTEGER NOT NULL DEFAULT 0,
        is_muted INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        unread_count INTEGER NOT NULL DEFAULT 0,
        is_group INTEGER NOT NULL DEFAULT 0,
        member_count INTEGER NOT NULL DEFAULT 0,
        raw_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rooms_cache_updated
      ON $_roomsCacheTableName (updated_at DESC)
    ''');
  }

  Future<void> _createDraftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_draftsTableName (
        room_id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        reply_to_id TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_drafts_updated
      ON $_draftsTableName (updated_at DESC)
    ''');
  }

  /// Menyimpan snapshot daftar chat rooms ke cache SQLCipher lokal secara terisolasi (Master / Decoy)
  Future<void> saveRoomsCache(List<Map<String, dynamic>> rooms) async {
    if (rooms.isEmpty) return;
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().toUtc().toIso8601String();

      for (final r in rooms) {
        final roomId = r['id'] as String? ?? r['room_id'] as String?;
        if (roomId == null || roomId.isEmpty) continue;

        // Siapkan map JSON yang serializable
        final serializableMap = Map<String, dynamic>.from(r);
        final lastMsg = r['lastMessage'];
        if (lastMsg is Message) {
          serializableMap['lastMessage'] = lastMsg.toJson();
        }

        final rawJson = jsonEncode(serializableMap);
        final timestampStr = r['timestamp']?.toString() ?? now;

        batch.insert(
          _roomsCacheTableName,
          {
            'room_id': roomId,
            'room_type': r['roomType'] as String? ?? r['room_type'] as String? ?? 'direct',
            'chat_name': r['name'] as String? ?? r['chat_name'] as String? ?? '',
            'avatar_url': r['avatarUrl'] as String? ?? r['avatar_url'] as String?,
            'other_user_id': r['otherUserId'] as String? ?? r['other_user_id'] as String?,
            'is_guardian': (r['isGuardian'] == true || r['is_guardian'] == true) ? 1 : 0,
            'is_muted': (r['isMuted'] == true || r['is_muted'] == true) ? 1 : 0,
            'is_archived': (r['isArchived'] == true || r['is_archived'] == true) ? 1 : 0,
            'unread_count': r['unreadCount'] as int? ?? r['unread_count'] as int? ?? 0,
            'is_group': (r['isGroup'] == true || r['is_group'] == true) ? 1 : 0,
            'member_count': r['memberCount'] as int? ?? r['member_count'] as int? ?? 0,
            'raw_json': rawJson,
            'updated_at': timestampStr,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      _logger.w('Gagal menyimpan local rooms cache: $e');
    }
  }

  /// Mengambil snapshot daftar chat rooms dari SQLite lokal secara instan (0-5 ms, zero network)
  Future<List<Map<String, dynamic>>> getCachedRooms() async {
    // Mode Decoy: kembalikan decoy rooms terisolasi
    if (_isDecoy) {
      return getDecoyRooms();
    }

    try {
      final db = await database;
      final rows = await db.query(
        _roomsCacheTableName,
        orderBy: 'updated_at DESC',
      );

      final List<Map<String, dynamic>> result = [];
      for (final row in rows) {
        final rawJsonStr = row['raw_json'] as String?;
        if (rawJsonStr == null || rawJsonStr.isEmpty) continue;

        final decoded = jsonDecode(rawJsonStr) as Map<String, dynamic>;
        // Rekonstruksi Message object jika ada
        if (decoded['lastMessage'] != null && decoded['lastMessage'] is Map) {
          try {
            decoded['lastMessage'] = Message.fromJson(
              (decoded['lastMessage'] as Map).cast<String, dynamic>(),
            );
          } catch (_) {}
        }
        result.add(decoded);
      }
      return result;
    } catch (e) {
      _logger.w('Gagal memuat local rooms cache: $e');
      return [];
    }
  }

  /// Menyimpan atau memperbarui draf pesan untuk room tertentu di database SQLCipher lokal
  Future<void> saveDraft(String roomId, String content, {String? replyToId}) async {
    if (roomId.trim().isEmpty) return;
    try {
      final db = await database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        _draftsTableName,
        {
          'room_id': roomId,
          'content': content,
          'reply_to_id': replyToId,
          'updated_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.w('Gagal menyimpan draf pesan lokal: $e');
    }
  }

  /// Mengambil draf pesan untuk room tertentu dari database SQLCipher lokal
  Future<ChatDraft?> getDraft(String roomId) async {
    if (roomId.trim().isEmpty) return null;
    try {
      final db = await database;
      final rows = await db.query(
        _draftsTableName,
        where: 'room_id = ?',
        whereArgs: [roomId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return ChatDraft.fromMap(rows.first);
      }
      return null;
    } catch (e) {
      _logger.w('Gagal membaca draf pesan lokal: $e');
      return null;
    }
  }

  /// Menghapus draf pesan untuk room tertentu dari database SQLCipher lokal
  Future<void> deleteDraft(String roomId) async {
    if (roomId.trim().isEmpty) return;
    try {
      final db = await database;
      await db.delete(
        _draftsTableName,
        where: 'room_id = ?',
        whereArgs: [roomId],
      );
    } catch (e) {
      _logger.w('Gagal menghapus draf pesan lokal: $e');
    }
  }

  /// Mengambil seluruh draf aktif untuk dipetakan ke state RAM saat aplikasi dimulai
  Future<Map<String, ChatDraft>> getAllDrafts() async {
    try {
      final db = await database;
      final rows = await db.query(
        _draftsTableName,
        orderBy: 'updated_at DESC',
      );
      final Map<String, ChatDraft> drafts = {};
      for (final row in rows) {
        final draft = ChatDraft.fromMap(row);
        drafts[draft.roomId] = draft;
      }
      return drafts;
    } catch (e) {
      _logger.w('Gagal membaca seluruh draf pesan lokal: $e');
      return {};
    }
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

      // SQLite plaintext magic header adalah "SQLite format 3\x00"
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

      _logger.w('⚠️ Terdeteksi database pesan lama (plaintext). Memulai auto-migrasi ke SQLCipher...');
      final legacyPath = '$path.legacy_plaintext';
      await file.rename(legacyPath);

      // Buka legacy DB tanpa password
      final legacyDb = await openDatabase(legacyPath);
      List<Map<String, dynamic>> rows = [];
      try {
        rows = await legacyDb.query(_tableName);
      } catch (_) {}
      await legacyDb.close();

      // Buat database terenkripsi baru
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

      // Musnahkan file legacy secara forensik
      await DatabaseKeyService.instance.shredFile(File(legacyPath));
      _logger.i('✅ Auto-migrasi ke SQLCipher selesai. File plaintext lama telah dimusnahkan secara forensik.');
    } catch (e, st) {
      _logger.e('Gagal melakukan migrasi database pesan legacy: $e', error: e, stackTrace: st);
    }
  }

  /// Simpan satu pesan bersih (terdekripsi) ke SQLite
  Future<void> saveMessage(Message message) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        _messageToMap(message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _logger.w('Gagal menyimpan pesan ke SQLite (${message.id}): $e');
    }
  }

  /// Simpan batch pesan bersih ke SQLite secara atomic
  Future<void> saveMessagesBatch(List<Message> messages) async {
    if (messages.isEmpty) return;
    try {
      final db = await database;
      final batch = db.batch();
      for (final msg in messages) {
        batch.insert(
          _tableName,
          _messageToMap(msg),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      _logger.w('Gagal menyimpan batch pesan ke SQLite: $e');
    }
  }

  /// Ambil seluruh riwayat pesan untuk ruang tertentu, diurutkan kronologis (ASC)
  Future<List<Message>> getMessagesForRoom(String roomId) async {
    try {
      final db = await database;
      final rows = await db.query(
        _tableName,
        where: 'room_id = ? AND is_silent_deleted = 0',
        whereArgs: [roomId],
        orderBy: 'created_at ASC',
      );

      return rows.map(_mapToMessage).toList();
    } catch (e) {
      _logger.w('Gagal memuat pesan dari SQLite (room: $roomId): $e');
      return [];
    }
  }

  /// Ambil satu pesan aktif paling mutakhir untuk preview di inbox/chat list (0ms, direct indexed query)
  Future<Message?> getLastActiveMessageForRoom(
    String roomId, {
    Set<String> hiddenIds = const {},
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        _tableName,
        where: 'room_id = ? AND is_deleted = 0 AND is_silent_deleted = 0',
        whereArgs: [roomId],
        orderBy: 'created_at DESC',
        limit: 10,
      );

      for (final row in rows) {
        final id = row['id'] as String?;
        if (id != null && !hiddenIds.contains(id)) {
          return _mapToMessage(row);
        }
      }
      return null;
    } catch (e) {
      _logger.w('Gagal memuat pesan terakhir dari SQLite (room: $roomId): $e');
      return null;
    }
  }

  /// Ambil satu pesan berdasarkan ID
  Future<Message?> getMessage(String messageId) async {
    try {
      final db = await database;
      final rows = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapToMessage(rows.first);
    } catch (e) {
      _logger.w('Gagal memuat pesan dari SQLite ($messageId): $e');
      return null;
    }
  }

  /// Hapus satu pesan dari database lokal
  Future<void> deleteMessage(String messageId) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      _logger.w('Gagal menghapus pesan dari SQLite ($messageId): $e');
    }
  }

  /// Tandai pesan sebagai disembunyikan untuk user ini
  Future<void> markSilentDeleted(String messageId) async {
    try {
      final db = await database;
      await db.update(
        _tableName,
        {'is_silent_deleted': 1},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      _logger.w('Gagal menyembunyikan pesan di SQLite ($messageId): $e');
    }
  }

  /// Hapus seluruh pesan di suatu room (mis. Burn on Exit atau bersihkan chat)
  Future<void> deleteRoomMessages(String roomId) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'room_id = ?',
        whereArgs: [roomId],
      );
    } catch (e) {
      _logger.w('Gagal membersihkan riwayat room dari SQLite ($roomId): $e');
    }
  }

  /// Hapus pesan-pesan yang waktu autoDeleteAt sudah kedaluwarsa
  Future<void> purgeExpiredMessages() async {
    try {
      final db = await database;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.delete(
        _tableName,
        where: 'auto_delete_at IS NOT NULL AND auto_delete_at <= ?',
        whereArgs: [nowIso],
      );
    } catch (e) {
      _logger.w('Gagal membersihkan pesan kedaluwarsa di SQLite: $e');
    }
  }

  /// Bersihkan seluruh database lokal (saat logout)
  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete(_tableName);
    } catch (e) {
      _logger.w('Gagal mengosongkan LocalMessageDatabase: $e');
    }
  }

  // ── Helper Pemetaan Model ↔ SQLite ─────────────────────────

  Map<String, dynamic> _messageToMap(Message m) {
    return {
      'id': m.id,
      'room_id': m.roomId,
      'sender_id': m.senderId,
      'content': m.content,
      'media_url': m.mediaUrl,
      'msg_type': m.type.name,
      'is_view_once': m.isViewOnce ? 1 : 0,
      'is_opened': m.isOpened ? 1 : 0,
      'opened_at': m.openedAt?.toIso8601String(),
      'reply_to_id': m.replyToId,
      'is_deleted': m.isDeleted ? 1 : 0,
      'is_silent_deleted': m.isSilentDeleted ? 1 : 0,
      'auto_delete_at': m.autoDeleteAt?.toIso8601String(),
      'edited_at': m.editedAt?.toIso8601String(),
      'reactions': jsonEncode(m.reactions),
      'created_at': m.createdAt.toIso8601String(),
      'updated_at': m.updatedAt.toIso8601String(),
      'is_encrypted': m.isEncrypted ? 1 : 0,
    };
  }

  Message _mapToMessage(Map<String, dynamic> row) {
    MessageType mType = MessageType.text;
    final typeStr = row['msg_type'] as String?;
    if (typeStr != null) {
      mType = MessageType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => MessageType.text,
      );
    }

    Map<String, List<String>> parsedReactions = {};
    final rawReactions = row['reactions'];
    if (rawReactions is String && rawReactions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawReactions);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is List) {
              parsedReactions[key.toString()] =
                  value.map((e) => e.toString()).toList();
            }
          });
        }
      } catch (_) {}
    }

    return Message(
      id: row['id'] as String,
      roomId: row['room_id'] as String,
      senderId: row['sender_id'] as String,
      content: row['content'] as String? ?? '',
      mediaUrl: row['media_url'] as String?,
      type: mType,
      isViewOnce: (row['is_view_once'] as int? ?? 0) == 1,
      isOpened: (row['is_opened'] as int? ?? 0) == 1,
      openedAt: row['opened_at'] != null
          ? DateTime.tryParse(row['opened_at'] as String)
          : null,
      replyToId: row['reply_to_id'] as String?,
      isDeleted: (row['is_deleted'] as int? ?? 0) == 1,
      isSilentDeleted: (row['is_silent_deleted'] as int? ?? 0) == 1,
      autoDeleteAt: row['auto_delete_at'] != null
          ? DateTime.tryParse(row['auto_delete_at'] as String)
          : null,
      editedAt: row['edited_at'] != null
          ? DateTime.tryParse(row['edited_at'] as String)
          : null,
      reactions: parsedReactions,
      createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String) ?? DateTime.now(),
      isEncrypted: (row['is_encrypted'] as int? ?? 0) == 1,
      isSending: false,
    );
  }
}
