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
  static Map<String, DateTime>? _persistedCache;

  /// Inisialisasi awal membaca cache persisten dari SharedPreferences dengan TTL
  static Future<void> initPersisted([SharedPreferences? preferences]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      final now = DateTime.now();
      final map = <String, DateTime>{};

      for (final item in list) {
        final parts = item.split('|');
        final key = parts[0];
        final millis = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (millis != null) {
          final time = DateTime.fromMillisecondsSinceEpoch(millis);
          if (now.difference(time) < _dedupeWindow) {
            map[key] = time;
          }
        }
      }
      _persistedCache = map;
    } catch (_) {}
  }

  /// Returns true jika ID ini sudah pernah dinotifikasi dalam dedup window (RAM atau disk cache valid).
  static bool isDuplicate(String id) {
    _cleanup();
    final now = DateTime.now();

    final persistedTime = _persistedCache?[id];
    if (persistedTime != null && now.difference(persistedTime) < _dedupeWindow) {
      return true;
    }

    final lastNotified = _notifiedIds[id];
    if (lastNotified != null && now.difference(lastNotified) < _dedupeWindow) {
      return true;
    }

    return false;
  }

  /// Pengecekan asinkron dengan fallback ke disk jika cache memori belum diinisialisasi
  static Future<bool> isDuplicateAsync(String id, [SharedPreferences? preferences]) async {
    if (isDuplicate(id)) return true;
    try {
      await initPersisted(preferences);
      return isDuplicate(id);
    } catch (_) {
      return false;
    }
  }

  /// Tandai ID sebagai sudah dinotifikasi dan simpan ke disk beserta timestamp (TTL).
  static Future<void> markNotifiedAsync(String id, [SharedPreferences? preferences]) async {
    final now = DateTime.now();
    _notifiedIds[id] = now;
    _cleanup();

    _persistedCache ??= {};
    _persistedCache![id] = now;

    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefKey) ?? [];
      final updatedList = <String>[];

      for (final item in list) {
        final parts = item.split('|');
        final key = parts[0];
        if (key == id) continue; // Timpa dengan entri baru
        final millis = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (millis != null) {
          final time = DateTime.fromMillisecondsSinceEpoch(millis);
          if (now.difference(time) < _dedupeWindow) {
            updatedList.add(item);
          }
        }
      }

      updatedList.add('$id|${now.millisecondsSinceEpoch}');
      if (updatedList.length > 200) {
        updatedList.removeRange(0, updatedList.length - 200);
      }
      await prefs.setStringList(_prefKey, updatedList);
    } catch (_) {}
  }

  /// Tandai ID sebagai sudah dinotifikasi secara sinkron (penyimpanan disk berjalan di background).
  static void markNotified(String id) {
    unawaited(markNotifiedAsync(id));
  }

  /// Bersihkan entries yang sudah expired atau melebihi batas.
  static void _cleanup() {
    final now = DateTime.now();
    _notifiedIds.removeWhere(
      (_, time) => now.difference(time) > _dedupeWindow,
    );
    _persistedCache?.removeWhere(
      (_, time) => now.difference(time) > _dedupeWindow,
    );
    if (_notifiedIds.length > _maxEntries) {
      final excess = _notifiedIds.length - _maxEntries;
      final keysToRemove = _notifiedIds.keys.take(excess).toList();
      for (final k in keysToRemove) {
        _notifiedIds.remove(k);
      }
    }
  }

  /// Reset semua tracking (untuk testing atau logout).
  static void reset({bool clearDisk = false}) {
    _notifiedIds.clear();
    _persistedCache = null;
    if (clearDisk) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_prefKey));
    }
  }
}
