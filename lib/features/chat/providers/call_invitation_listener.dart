import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_dedup_service.dart';
import 'chat_provider.dart';
import 'call_state_provider.dart';
import '../screens/incoming_call_screen.dart';

/// Listener terpusat untuk mendeteksi undangan panggilan masuk secara realtime.
///
/// Handler untuk Realtime `postgres_changes` pada tabel `calls` —
/// channel dikelola bersama oleh `AppRealtimeListener` (satu channel global
/// terpadu, bukan per-listener).
class CallInvitationListener {
  final Ref _ref;
  final Logger _log = Logger();
  bool _disposed = false;

  CallInvitationListener(this._ref);

  /// Dipanggil oleh `AppRealtimeListener` saat ada INSERT di tabel calls.
  void handleInsertCall(PostgresChangePayload payload) async {
    if (_disposed) return;

    final newRow = payload.newRecord;
    final callId = newRow['id'] as String?;
    final roomId = newRow['room_id'] as String?;
    final callerId = newRow['caller_id'] as String?;
    final callType = newRow['call_type'] as String? ?? 'voice';
    final status = newRow['status'] as String?;

    if (callId == null || roomId == null || callerId == null || status != 'ringing') {
      return;
    }

    // Call Collision Guard: Jika user sedang aktif dalam panggilan lain, otomatis tolak dengan status 'busy'
    final activeCallId = _ref.read(activeCallIdProvider);
    if (activeCallId != null && activeCallId != callId) {
      _log.w('User sedang sibuk dalam panggilan $activeCallId. Menolak panggilan masuk $callId (busy).');
      try {
        await _ref.read(callRepositoryProvider).updateCallStatus(callId, 'busy');
      } catch (e) {
        _log.e('Gagal memperbarui status panggilan ke busy: $e');
      }
      return;
    }

    // Dedup: cek apakah sudah dinotifikasi dari jalur FCM
    if (NotificationDedupService.isDuplicate('call_$callId')) return;
    NotificationDedupService.markNotified('call_$callId');

    final repo = _ref.read(chatRepositoryProvider);
    String callerName = 'Panggilan Masuk';
    String? callerAvatarUrl;

    try {
      final profile = await repo.searchProfileById(callerId);
      if (profile != null) {
        callerName = (profile['display_name'] as String?)?.isNotEmpty == true
            ? profile['display_name'] as String
            : (profile['full_name'] as String?) ??
                (profile['username'] as String?) ??
                'Seseorang';
        callerAvatarUrl = profile['avatar_url'] as String?;
      }
    } catch (_) {}

    // Bunyikan ringtone
    await NotificationService.showIncomingCallNotification(
      callerName: callerName,
      callType: callType,
      payload: roomId,
    );

    // Buka layar panggilan masuk jika context tersedia
    final context = AppNavigator.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: callId,
            roomId: roomId,
            callerId: callerId,
            callerName: callerName,
            callerAvatarUrl: callerAvatarUrl,
            callType: callType,
          ),
        ),
      );
    }
  }

  void dispose() {
    _disposed = true;
  }
}

final callInvitationListenerProvider = Provider<CallInvitationListener>((ref) {
  final listener = CallInvitationListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});
