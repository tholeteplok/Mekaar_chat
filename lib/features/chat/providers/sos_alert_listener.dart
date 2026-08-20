import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_dedup_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'chat_provider.dart';

/// Listener Realtime untuk mendeteksi SOS baru dari user yang dijaga.
///
/// Layer redundansi kedua (selain FCM push via trigger DB).
/// Hanya menampilkan notifikasi jika FCM belum menanganinya (dedup).
///
/// Channel dikelola bersama oleh `AppRealtimeListener` (satu channel global
/// terpadu, bukan per-listener).
class SOSAlertListener {
  final Ref _ref;
  final Logger _log = Logger();
  bool _disposed = false;
  List<String>? _cachedOwnerIds;

  SOSAlertListener(this._ref);

  /// Prefetch owner IDs (user yang menjadikan kita guardian).
  /// Dipanggil oleh `AppRealtimeListener.start()`.
  void startPrefetch() {
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) {
      _log.w('SOSAlertListener: user belum login, skip.');
      return;
    }
    _loadOwnerIds(userId);
  }

  Future<void> _loadOwnerIds(String guardianId) async {
    try {
      final response = await _ref.read(supabaseServiceProvider).client
          .from('guardians')
          .select('owner_id')
          .eq('guardian_id', guardianId)
          .eq('status', 'active');

      _cachedOwnerIds = (response as List)
          .map((e) => e['owner_id'] as String)
          .toList();
    } catch (e) {
      _log.w('SOSAlertListener: gagal load owner IDs: $e');
      _cachedOwnerIds = [];
    }
  }

  /// Dipanggil oleh `AppRealtimeListener` saat ada INSERT di tabel sos_sessions.
  void handleInsertSOS(PostgresChangePayload payload) async {
    if (_disposed) return;

    final newRow = payload.newRecord;
    final sessionId = newRow['id'] as String?;
    final userId = newRow['user_id'] as String?;
    final status = newRow['status'] as String?;

    if (sessionId == null || userId == null || status != 'active') return;

    // Cek apakah user ini adalah orang yang kita jaga
    final currentUserId = _ref.read(supabaseServiceProvider).currentUserId;
    if (currentUserId == null || userId == currentUserId) return;

    if (_cachedOwnerIds != null && !_cachedOwnerIds!.contains(userId)) return;

    // Dedup: cek apakah sudah dinotifikasi dari jalur FCM
    if (NotificationDedupService.isDuplicate('sos_$sessionId')) return;
    NotificationDedupService.markNotified('sos_$sessionId');

    // Ambil nama korban
    String victimName = 'Seseorang';
    try {
      final profile =
          await _ref.read(chatRepositoryProvider).searchProfileById(userId);
      if (profile != null) {
        victimName = (profile['full_name'] as String?) ??
            (profile['username'] as String?) ??
            'Seseorang';
      }
    } catch (_) {
      // Fallback ke nama default.
    }

    await NotificationService.showLocalSOSNotification(
      title: '🆘 DARURAT — $victimName',
      body: 'Butuh bantuan segera! Tap untuk melihat lokasi.',
      data: {'role': 'guardian', 'sessionId': sessionId},
    );
  }

  void dispose() {
    _disposed = true;
  }
}

/// Provider untuk listener SOS agar lifecycle terikat ke widget root.
final sosAlertListenerProvider = Provider<SOSAlertListener>((ref) {
  final listener = SOSAlertListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});
