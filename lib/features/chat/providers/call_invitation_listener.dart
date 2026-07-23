import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../data/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'chat_provider.dart';
import '../screens/incoming_call_screen.dart';

/// Listener terpusat untuk mendeteksi undangan panggilan masuk secara realtime.
class CallInvitationListener {
  final Ref _ref;
  final Logger _log = Logger();
  RealtimeChannel? _channel;
  bool _disposed = false;

  CallInvitationListener(this._ref);

  void start() {
    final supabaseService = _ref.read(supabaseServiceProvider);
    final userId = supabaseService.currentUserId;
    if (userId == null) {
      _log.w('CallInvitationListener: user belum login, skip.');
      return;
    }

    _channel = supabaseService.client
        .channel('public:calls:incoming')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: _onInsertCall,
        )
        .subscribe();

    _log.i('CallInvitationListener: mulai berlangganan tabel calls.');
  }

  void _onInsertCall(PostgresChangePayload payload) async {
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
    _channel?.unsubscribe();
    _channel = null;
  }
}

final callInvitationListenerProvider = Provider<CallInvitationListener>((ref) {
  final listener = CallInvitationListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});
