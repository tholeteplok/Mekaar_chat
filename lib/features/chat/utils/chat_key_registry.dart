import 'package:flutter/widgets.dart';

/// Registry terpusat untuk menyimpan GlobalKey setiap pesan pada layar obrolan.
/// Menjamin identitas referensi key (pointer memori) identik 100% antara
/// saat bubble dirender (KeyedSubtree) dan saat pengguna mengetuk kutipan balas (jump to message).
class ChatKeyRegistry {
  static final Map<String, GlobalKey> _keys = {};

  /// Mendapatkan atau membuat GlobalKey unik untuk ID pesan tertentu
  static GlobalKey getKey(String messageId) {
    return _keys.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'msg_$messageId'),
    );
  }

  /// Membersihkan registry saat room ditutup/berpindah untuk mencegah kebocoran memori
  static void clear() {
    _keys.clear();
  }
}
