import '../models/message_model.dart';
import '../services/local_message_database.dart';

/// Abstraksi repositori pencarian pesan lintas-chat.
///
/// Memungkinkan pengujian widget/unit dengan fake repository tanpa membutuhkan database SQLite fisik.
abstract class MessageSearchRepository {
  Future<List<Message>> searchMessages({
    required String query,
    Set<String> excludedRoomIds = const {},
    int limit = 50,
    int offset = 0,
  });
}

/// Implementasi nyata MessageSearchRepository yang berjalan di atas [LocalMessageDatabase].
class LocalMessageSearchRepository implements MessageSearchRepository {
  final LocalMessageDatabase _db;

  const LocalMessageSearchRepository(this._db);

  @override
  Future<List<Message>> searchMessages({
    required String query,
    Set<String> excludedRoomIds = const {},
    int limit = 50,
    int offset = 0,
  }) {
    return _db.searchMessagesAcrossRooms(
      query: query,
      excludedRoomIds: excludedRoomIds,
      limit: limit,
      offset: offset,
    );
  }
}
