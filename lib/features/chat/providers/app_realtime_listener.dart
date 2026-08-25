import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/password_change_alert_listener.dart';
import 'call_invitation_listener.dart';
import 'message_notification_listener.dart';
import 'sos_alert_listener.dart';

/// Channel Realtime global terpadu untuk seluruh listener notifikasi berbasis
/// database (`messages`, `calls`, `sos_sessions`, `profiles`).
///
/// Sebelumnya keempat listener punya channel masing-masing yang subscribe
/// bersamaan saat app start → rebutan slot koneksi/rate-limit join Supabase
/// Realtime → latensi acak dan lebih rentan `RealtimeSubscribeException(timedOut)`.
///
/// Channel typing indicator (`room_typing:$roomId`) dan stream messages
/// per-room tetap terpisah — scope-nya memang per-chat.
class AppRealtimeListener {
  final Ref _ref;
  final Logger _log = Logger();
  RealtimeChannel? _channel;

  AppRealtimeListener(this._ref);

  void start() {
    final supabaseService = _ref.read(supabaseServiceProvider);
    final userId = supabaseService.currentUserId;
    if (userId == null) {
      _log.w('AppRealtimeListener: user belum login, skip.');
      return;
    }

    // Setup non-channel (auth state lokal & prefetch owner IDs)
    _ref.read(passwordChangeAlertListenerProvider).startAuthListener();
    _ref.read(sosAlertListenerProvider).startPrefetch();

    final messageListener = _ref.read(messageNotificationListenerProvider);
    final callListener = _ref.read(callInvitationListenerProvider);
    final sosListener = _ref.read(sosAlertListenerProvider);
    final passwordListener = _ref.read(passwordChangeAlertListenerProvider);

    // Satu channel dengan beberapa binding onPostgresChanges, bukan 4 channel
    // yang subscribe bersamaan di window waktu yang sama.
    _channel = supabaseService.client
        .channel('public:app_events_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: messageListener.handleInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: messageListener.handleMessageChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: callListener.handleInsertCall,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_sessions',
          callback: sosListener.handleInsertSOS,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: passwordListener.handleProfileUpdated,
        )
        .subscribe();

    _log.i(
      'AppRealtimeListener: channel global aktif '
      '(messages, calls, sos_sessions, profiles).',
    );
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}

/// Provider untuk listener global terpadu agar lifecycle terikat ke widget root.
final appRealtimeListenerProvider = Provider<AppRealtimeListener>((ref) {
  final listener = AppRealtimeListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});