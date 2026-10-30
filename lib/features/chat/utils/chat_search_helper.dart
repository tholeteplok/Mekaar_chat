import '../../../data/models/message_model.dart';

/// Representasi hasil temuan pencarian pesan.
class SearchHit {
  final String messageId;
  final DateTime createdAt;

  const SearchHit({required this.messageId, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchHit &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => messageId.hashCode ^ createdAt.hashCode;
}

/// Menghitung dan mengembalikan daftar temuan pesan yang cocok dengan [query] pencarian.
///
/// Logika:
/// 1. Menggunakan [Message.searchableText] yang aman dan privat (tanpa bocor kunci).
/// 2. Mengabaikan pesan yang terdaftar dalam [hiddenMessageIds] (misal: pending hide/delete).
/// 3. Mengurutkan hasil dari **terbaru ke terlama** (descending berdasarkan createdAt),
///    sesuai urutan indeks ListView feed pesan.
List<SearchHit> computeSearchHits({
  required List<Message> messages,
  required String query,
  Set<String> hiddenMessageIds = const {},
}) {
  final trimmedQuery = query.trim().toLowerCase();
  if (trimmedQuery.isEmpty) return const [];

  final hits = <SearchHit>[];

  for (final msg in messages) {
    if (hiddenMessageIds.contains(msg.id)) continue;

    final text = msg.searchableText;
    if (text == null) continue;

    if (text.toLowerCase().contains(trimmedQuery)) {
      hits.add(SearchHit(messageId: msg.id, createdAt: msg.createdAt));
    }
  }

  // Urutkan descending: terbaru ke terlama
  hits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return hits;
}
