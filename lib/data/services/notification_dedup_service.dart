/// Service deduplikasi notifikasi terpusat.
///
/// Mencegah notifikasi ganda yang bisa terjadi saat pesan/call/SOS
/// diterima dari dua jalur sekaligus: Realtime listener dan FCM push.
///
/// Cara kerja:
/// - Setiap notifikasi didaftarkan dengan ID unik (misal: `msg_<id>`, `call_<id>`, `sos_<id>`).
/// - `isDuplicate()` mengembalikan true jika ID sudah dinotifikasi dalam 5 detik terakhir.
/// - `markNotified()` mendaftarkan ID sebagai sudah dinotifikasi.
/// - Auto-cleanup entries yang expired dan batasi maksimal 200 entries.
class NotificationDedupService {
  static final Map<String, DateTime> _notifiedIds = {};
  static const Duration _dedupeWindow = Duration(seconds: 5);
  static const int _maxEntries = 200;

  /// Returns true jika ID ini sudah pernah dinotifikasi dalam dedup window.
  static bool isDuplicate(String id) {
    _cleanup();
    final lastNotified = _notifiedIds[id];
    if (lastNotified == null) return false;
    return DateTime.now().difference(lastNotified) < _dedupeWindow;
  }

  /// Tandai ID sebagai sudah dinotifikasi.
  static void markNotified(String id) {
    _notifiedIds[id] = DateTime.now();
    _cleanup();
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
  static void reset() => _notifiedIds.clear();
}
