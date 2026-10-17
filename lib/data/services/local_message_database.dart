import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import '../models/message_model.dart';

/// Database lokal SQLite untuk persistensi pesan yang sudah didekripsi.
///
/// Menyediakan akses offline 0ms ke riwayat obrolan, mengeliminasi kebutuhan
/// untuk mendekripsi ulang setiap pesan dari cloud server saat aplikasi dibuka kembali,
/// dan mencegah pesan berubah menjadi 'Pesan terenkripsi' jika proses dimatikan.
class LocalMessageDatabase {
  LocalMessageDatabase._();
  static final LocalMessageDatabase instance = LocalMessageDatabase._();

  static final Logger _logger = Logger();
  static const String _tableName = 'local_messages';
  static const String _dbFileName = 'mekaar_local_messages.db';
  static const int _dbVersion = 1;

  Database? _db;
  Completer<Database>? _dbInitCompleter;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    if (_dbInitCompleter != null) {
      return _dbInitCompleter!.future;
    }

    _dbInitCompleter = Completer<Database>();
    try {
      final dbPath = await getDatabasesPath();
      final path = '$dbPath/$_dbFileName';

      _db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
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
        },
      );

      _dbInitCompleter!.complete(_db!);
      return _db!;
    } catch (e, st) {
      _logger.e('Gagal menginisialisasi LocalMessageDatabase: $e', error: e, stackTrace: st);
      _dbInitCompleter?.completeError(e, st);
      rethrow;
    } finally {
      _dbInitCompleter = null;
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
