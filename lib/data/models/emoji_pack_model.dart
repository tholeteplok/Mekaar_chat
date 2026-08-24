/// Model katalog Toko Emoji MEKAAR.
///
/// Pesan tidak pernah membawa URL — hanya shortcode `:slug:` di dalam
/// `content` terenkripsi. URL diselesaikan client dari katalog ini.
class EmojiPack {
  final String slug;
  final String name;
  final String? description;
  final String? coverUrl;
  final int itemCount;

  /// Total ukuran aset dalam byte (denormalisasi dari server) untuk UI toko.
  final int totalBytes;
  final int sortOrder;

  const EmojiPack({
    required this.slug,
    required this.name,
    this.description,
    this.coverUrl,
    required this.itemCount,
    required this.totalBytes,
    required this.sortOrder,
  });

  factory EmojiPack.fromJson(Map<String, dynamic> json) => EmojiPack(
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        coverUrl: json['cover_url'] as String?,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  /// "420 KB" / "1.2 MB" untuk kartu toko.
  String get formattedSize {
    if (totalBytes <= 0) return '—';
    const kb = 1024, mb = 1024 * 1024;
    if (totalBytes < kb) return '$totalBytes B';
    if (totalBytes < mb) return '${(totalBytes / kb).toStringAsFixed(0)} KB';
    return '${(totalBytes / mb).toStringAsFixed(1)} MB';
  }
}

class EmojiPackItem {
  final String packSlug;
  final String shortcode;
  final String fileUrl;
  final int bytes;
  final int sortOrder;

  const EmojiPackItem({
    required this.packSlug,
    required this.shortcode,
    required this.fileUrl,
    required this.bytes,
    required this.sortOrder,
  });

  factory EmojiPackItem.fromJson(Map<String, dynamic> json) => EmojiPackItem(
        packSlug: (json['emoji_packs'] as Map<String, dynamic>?)?['slug']
                as String? ??
            json['pack_slug'] as String? ??
            '',
        shortcode: json['shortcode'] as String,
        fileUrl: json['file_url'] as String,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}
