import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Service deduplikasi notifikasi terpusat.
///
/// Mencegah notifikasi ganda yang bisa terjadi saat pesan/call/SOS
/// diterima dari dua jalur sekaligus: Realtime listener dan FCM push.
///
/// Cara kerja:
/// - Setiap notifikasi didaftarkan dengan ID unik (misal: `msg_<id>`, `call_<id>`, `sos_<id>`, `missed_<id>`).
/// - `isDuplicate()` mengembalikan true jika ID sudah dinotifikasi dalam window deduplikasi (120 detik)
///   atau sudah tercatat dalam cache persisten.
/// - `isDuplicateAsync()` menjamin pengecekan persisten bahkan saat cold start / memori baru bersih.
/// - `markNotified()` mendaftarkan ID sebagai sudah dinotifikasi dan menyimpan ke disk secara asinkron.
/// - Auto-cleanup entries yang expired dan batasi maksimal 500 entries di RAM & 200 di disk.
class NotificationDedupService {
  static final Map<String, DateTime> _notifiedIds = {};
  static const Duration _dedupeWindow = Duration(seconds: 120);
  static const int _maxEntries = 500;
  static const String _prefKey = 'mekaar_notified_dedup_keys';
  static Set<String>? _persistedKeysCache;

  /// Inisialisasi awal membaca cache persisten dari SharedPreferences
  static Future<void> initPersisted([SharedPreferences? preferences]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      _persistedKeysCache = list.toSet();
    } catch (_) {}
  }

  /// Returns true jika ID ini sudah pernah dinotifikasi dalam dedup window atau cache persisten.
  static bool isDuplicate(String id) {
    _cleanup();
    if (_persistedKeysCache != null && _persistedKeysCache!.contains(id)) {
      return true;
    }
    final lastNotified = _notifiedIds[id];
    if (lastNotified == null) return false;
    return DateTime.now().difference(lastNotified) < _dedupeWindow;
  }

  /// Pengecekan asinkron dengan fallback ke disk jika cache memori belum diinisialisasi
  static Future<bool> isDuplicateAsync(String id, [SharedPreferences? preferences]) async {
    if (isDuplicate(id)) return true;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      _persistedKeysCache = list.toSet();
      return _persistedKeysCache!.contains(id);
    } catch (_) {
      return false;
    }
  }

  /// Tandai ID sebagai sudah dinotifikasi dan simpan ke disk.
  static Future<void> markNotifiedAsync(String id, [SharedPreferences? preferences]) async {
    _notifiedIds[id] = DateTime.now();
    _cleanup();
    _persistedKeysCache ??= {};
    _persistedKeysCache!.add(id);
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      if (!list.contains(id)) {
        list.add(id);
        if (list.length > 200) {
          list.removeRange(0, list.length - 200);
        }
        await prefs.setStringList(_prefKey, list);
        _persistedKeysCache = list.toSet();
      }
    } catch (_) {}
  }

  /// Tandai ID sebagai sudah dinotifikasi secara sinkron (penyimpanan disk berjalan di background).
  static void markNotified(String id) {
    unawaited(markNotifiedAsync(id));
  }

  /// Bersihkan entries yang sudah expired atau melebihi batas.
  static void _cleanup() {
    if (_notifiedIds.length <= _maxEntries) return;
    final now = DateTime.now();
    _notifiedIds.removeWhere(
      (_, time) => now.difference(time) > _dedupeWindow,
    );
  }

  /// Reset semua tracking (untuk testing atau logout).
  static void reset({bool clearDisk = false}) {
    _notifiedIds.clear();
    _persistedKeysCache = null;
    if (clearDisk) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_prefKey));
    }
  }
}
