import 'package:shared_preferences/shared_preferences.dart';

/// Pelacakan pesan "Sekali Lihat" yang sudah dibuka (lokal, persisten).
class ViewOnceStore {
  static const String _key = 'viewed_once_message_ids';
  static final Set<String> _memory = {};
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key) ?? [];
      _memory.addAll(stored);
    } catch (_) {}
    _loaded = true;
  }

  static Future<bool> isViewed(String id) async {
    await _ensureLoaded();
    return _memory.contains(id);
  }

  static Future<void> markViewed(String id) async {
    await _ensureLoaded();
    if (_memory.contains(id)) return;
    _memory.add(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _memory.toList());
    } catch (_) {}
  }
}
