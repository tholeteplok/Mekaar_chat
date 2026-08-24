import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/emoji_pack_model.dart';
import '../../../data/services/emoji_pack_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Service singleton untuk katalog & disk pack.
final emojiPackServiceProvider = Provider<EmojiPackService>((ref) {
  return EmojiPackService(ref.watch(supabaseServiceProvider).client);
});

/// Katalog pack aktif + indeks slug→url (untuk lazy-load render).
final emojiCatalogProvider =
    AsyncNotifierProvider<EmojiCatalogController, List<EmojiPack>>(
        EmojiCatalogController.new);

class EmojiCatalogController extends AsyncNotifier<List<EmojiPack>> {
  @override
  Future<List<EmojiPack>> build() {
    return ref.read(emojiPackServiceProvider).fetchCatalog();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(emojiPackServiceProvider).fetchCatalog());
    ref.read(installedPacksProvider.notifier).refreshFileStates();
  }

  /// URL aset untuk shortcode; null bila tidak dikenal katalog.
  String? urlFor(String shortcode) =>
      ref.read(emojiPackServiceProvider).urlIndex[shortcode];

  List<EmojiPackItem> itemsOf(String packSlug) =>
      ref.read(emojiPackServiceProvider).itemsOf(packSlug);
}

/// Daftar slug pack terpasang di perangkat ini (SharedPreferences),
/// plus status unduhan per-pack untuk UI toko.
class InstalledPacksState {
  final Set<String> slugs;

  /// Pack yang sedang dalam proses unduh: slug → progress (0..1).
  final Map<String, double> downloading;

  const InstalledPacksState({
    required this.slugs,
    this.downloading = const {},
  });

  bool isInstalled(String slug) => slugs.contains(slug);
  bool isDownloading(String slug) => downloading.containsKey(slug);

  InstalledPacksState copyWith({
    Set<String>? slugs,
    Map<String, double>? downloading,
  }) {
    return InstalledPacksState(
      slugs: slugs ?? this.slugs,
      downloading: downloading ?? this.downloading,
    );
  }
}

const String _kInstalledKey = 'installed_emoji_packs';

final installedPacksProvider =
    NotifierProvider<InstalledPacksController, InstalledPacksState>(
        InstalledPacksController.new);

class InstalledPacksController extends Notifier<InstalledPacksState> {
  @override
  InstalledPacksState build() {
    _loadFromPrefs();
    return const InstalledPacksState(slugs: {});
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kInstalledKey) ?? [];
    // Sinkronkan dengan kondisi disk nyata.
    final service = ref.read(emojiPackServiceProvider);
    final verified = <String>{};
    for (final slug in list) {
      if (await service.isInstalled(slug)) verified.add(slug);
    }
    if (verified.length != list.length) {
      await prefs.setStringList(_kInstalledKey, verified.toList());
    }
    state = state.copyWith(slugs: verified);
  }

  void refreshFileStates() => _loadFromPrefs();

  Future<void> install(String slug) async {
    final service = ref.read(emojiPackServiceProvider);
    final items = ref.read(emojiCatalogProvider.notifier).itemsOf(slug);
    if (items.isEmpty) return;

    final downloading = {...state.downloading, slug: 0.0};
    state = state.copyWith(downloading: downloading);
    try {
      await service.installPack(slug, items, onProgress: (done, total) {
        final map = {...state.downloading};
        map[slug] = total == 0 ? 1.0 : done / total;
        state = state.copyWith(downloading: map);
      });
      final slugs = {...state.slugs, slug};
      state = state.copyWith(slugs: slugs);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kInstalledKey, slugs.toList());
    } finally {
      final map = {...state.downloading}..remove(slug);
      state = state.copyWith(downloading: map);
    }
  }

  Future<void> uninstall(String slug) async {
    final service = ref.read(emojiPackServiceProvider);
    await service.uninstallPack(slug);
    final slugs = {...state.slugs}..remove(slug);
    state = state.copyWith(slugs: slugs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kInstalledKey, slugs.toList());
  }
}
