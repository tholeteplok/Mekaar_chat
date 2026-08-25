import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/emoji_shortcode_parser.dart';
import '../models/emoji_pack_model.dart';

/// Layanan Toko Emoji MEKAAR.
///
/// - [fetchCatalog]: katalog pack aktif + indeks `slug → url` untuk
///   lazy-load pesan masuk dari pack yang belum dipasang.
/// - [installPack]/[uninstallPack]: unduh/hapus file aset per-pack di
///   `{docs}/emoji_packs/{slug}/` — "hemat penyimpanan" yang nyata.
///
/// Pesan TIDAK PERNAH membawa URL; hanya shortcode `:slug:` di dalam
/// content terenkripsi E2EE.
class EmojiPackService {
  final SupabaseClient _client;

  EmojiPackService(this._client);

  static const String bucket = 'emoji-packs';

  /// Indeks shortcode → url hasil fetch terakhir (untuk lazy-load render).
  Map<String, String> _urlIndex = {};
  Map<String, String> get urlIndex => Map.unmodifiable(_urlIndex);

  /// Ambil katalog pack aktif beserta seluruh itemnya.
  Future<List<EmojiPack>> fetchCatalog() async {
    final packsRows = await _client
        .from('emoji_packs')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    final packs =
        (packsRows as List).map((r) => EmojiPack.fromJson(r)).toList();
    if (packs.isEmpty) {
      _urlIndex = {};
      return packs;
    }

    // Join manual via filter in_ pada slug pack (RLS items terbuka).
    final slugs = packs.map((p) => p.slug).toList();
    final itemRows = await _client
        .from('emoji_pack_items')
        .select('shortcode, file_url, bytes, sort_order, emoji_packs(slug)')
        .inFilter('emoji_packs.slug', slugs)
        .order('sort_order');

    final items = (itemRows as List)
        .map((r) => EmojiPackItem.fromJson(Map<String, dynamic>.from(r)))
        .toList();

    _urlIndex = {
      for (final it in items) it.shortcode: it.fileUrl,
    };

    // Lampirkan item ke pack masing-masing (untuk detail/preview toko).
    _itemsByPack = {
      for (final p in packs)
        p.slug: items.where((i) => i.packSlug == p.slug).toList(),
    };
    return packs;
  }

  Map<String, List<EmojiPackItem>> _itemsByPack = {};

  /// Item per pack slug dari fetch katalog terakhir.
  List<EmojiPackItem> itemsOf(String packSlug) =>
      _itemsByPack[packSlug] ?? const [];

  Directory? _baseDir;

  /// Direktori dasar penyimpanan pack terpasang.
  Future<Directory> baseDir() async {
    if (_baseDir != null) return _baseDir!;
    final docs = await getApplicationDocumentsDirectory();
    _baseDir = Directory('${docs.path}${Platform.pathSeparator}emoji_packs');
    return _baseDir!;
  }

  Future<Directory> packDir(String slug) async {
    final base = await baseDir();
    return Directory('${base.path}${Platform.pathSeparator}$slug');
  }

  final Map<String, bool> _installedMemo = {};
  final Map<String, File?> _localFileCache = {};

  /// Cek cepat apakah direktori pack ada di disk.
  Future<bool> isInstalled(String slug) async {
    if (_installedMemo.containsKey(slug)) return _installedMemo[slug]!;
    final dir = await packDir(slug);
    final exists = await dir.exists();
    _installedMemo[slug] = exists;
    return exists;
  }

  void _markInstalled(String slug, bool installed) {
    _installedMemo[slug] = installed;
    _localFileCache.clear();
  }

  /// Unduh seluruh file item pack ke disk. Idempoten — file yang sudah
  /// ada dengan ukuran sama dilewati.
  ///
  /// [onProgress] dipanggil per item selesai (done / total).
  Future<void> installPack(
    String slug,
    List<EmojiPackItem> items, {
    void Function(int done, int total)? onProgress,
  }) async {
    final dir = await packDir(slug);
    await dir.create(recursive: true);
    var done = 0;
    for (final item in items) {
      final ext = item.fileUrl.contains('.')
          ? item.fileUrl.substring(item.fileUrl.lastIndexOf('.'))
          : '.webp';
      final file = File('${dir.path}${Platform.pathSeparator}'
          '${item.shortcode}$ext');
      final needDownload = !await file.exists() || await file.length() == 0;
      if (needDownload) {
        final resp = await http.get(Uri.parse(item.fileUrl)).timeout(
              const Duration(seconds: 15),
            );
        if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
          throw Exception('Gagal mengunduh emoji ${item.shortcode}');
        }
        await file.writeAsBytes(resp.bodyBytes, flush: true);
      }
      _localFileCache[item.shortcode] = file;
      done++;
      onProgress?.call(done, items.length);
    }
    _markInstalled(slug, true);
  }

  /// Hapus direktori pack — membebaskan penyimpanan nyata.
  Future<void> uninstallPack(String slug) async {
    final dir = await packDir(slug);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _markInstalled(slug, false);
  }

  /// Ukuran terpakai pack di disk (byte), 0 bila tidak terpasang.
  Future<int> installedSizeOnDisk(String slug) async {
    final dir = await packDir(slug);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final f in dir.list()) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  /// Path lokal file emoji bila pack terpasang; null bila tidak.
  /// Berfungsi 100% offline-first meskipun katalog belum sempat di-fetch.
  Future<File?> resolveLocalFile(String shortcode) async {
    if (_localFileCache.containsKey(shortcode)) {
      final cached = _localFileCache[shortcode];
      if (cached == null) return null;
      if (await cached.exists()) return cached;
      _localFileCache.remove(shortcode);
    }

    final base = await baseDir();
    if (!await base.exists()) {
      _localFileCache[shortcode] = null;
      return null;
    }

    final url = _urlIndex[shortcode];
    final expectedName = url?.substring(url.lastIndexOf('/') + 1);

    await for (final d in base.list()) {
      if (d is! Directory) continue;
      // 1. Pencocokan presisi jika nama file diketahui dari URL katalog
      if (expectedName != null) {
        final candidate =
            File('${d.path}${Platform.pathSeparator}$expectedName');
        if (await candidate.exists() && await candidate.length() > 0) {
          _localFileCache[shortcode] = candidate;
          return candidate;
        }
      }
      // 2. Fallback offline-first: cari ekstensi standar berbasis shortcode murni
      for (final ext in const ['.webp', '.png', '.jpg', '.jpeg', '.gif']) {
        final candidate =
            File('${d.path}${Platform.pathSeparator}$shortcode$ext');
        if (await candidate.exists() && await candidate.length() > 0) {
          _localFileCache[shortcode] = candidate;
          return candidate;
        }
      }
    }
    _localFileCache[shortcode] = null;
    return null;
  }

  /// Pratinjau teks aman untuk notifikasi/reply: ganti token dikenal
  /// menjadi '[emoji]', token tak dikenal dibiarkan apa adanya.
  String previewSafe(String content) =>
      replaceCustomEmojiTokens(content, (_) => '[emoji]');
}
