import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart' hide AuthState;
import '../../auth/providers/password_change_alert_listener.dart';
import '../../guardian/providers/guardian_provider.dart';
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
  StreamSubscription<AuthState>? _authSub;
  String? _subscribedUserId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  AppRealtimeListener(this._ref) {
    _initAuthListener();
  }

  void _initAuthListener() {
    final supabase = _ref.read(supabaseServiceProvider);
    _authSub = supabase.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        if (_subscribedUserId != user.id || _channel == null) {
          _log.i('AppRealtimeListener: Auth state update (user: ${user.id}), starting listener...');
          start(force: true);
        }
      } else {
        _stopChannel();
      }
    });
  }

  void _stopChannel() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    if (_channel != null) {
      final supabaseService = _ref.read(supabaseServiceProvider);
      try {
        supabaseService.client.removeChannel(_channel!);
      } catch (_) {
        _channel?.unsubscribe();
      }
      _channel = null;
    }
    _subscribedUserId = null;
    _log.i('AppRealtimeListener: channel dihentikan (user logged out / no session).');
  }

  void _scheduleReconnect() {
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
    _log.w(
      'AppRealtimeListener: menjadwalkan koneksi ulang channel dalam $delaySeconds detik '
      '(percobaan ke-$_reconnectAttempts)...',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_ref.read(supabaseServiceProvider).currentUserId == userId) {
        start(force: true);
      }
    });
  }

  /// Memverifikasi dan memulihkan koneksi channel jika mati atau terputus
  /// (misalnya saat aplikasi kembali ke foreground / resumed).
  void reconnectIfNeeded() {
    final userId = _ref.read(supabaseServiceProvider).currentUserId;
    if (userId == null) return;

    if (_channel == null || _subscribedUserId != userId) {
      _log.i('AppRealtimeListener: reconnecting realtime channel on demand (lifecycle resume)...');
      start(force: true);
    }
  }

  void start({bool force = false}) {
    final supabaseService = _ref.read(supabaseServiceProvider);
    final userId = supabaseService.currentUserId;
    if (userId == null) {
      _log.w('AppRealtimeListener: user belum login, skip.');
      return;
    }

    if (!force && _channel != null && _subscribedUserId == userId) {
      return; // Sudah tersubscribe untuk user yang sama
    }

    _reconnectTimer?.cancel();

    // Bersihkan channel lama secara menyeluruh jika ada
    if (_channel != null) {
      try {
        supabaseService.client.removeChannel(_channel!);
      } catch (_) {
        _channel?.unsubscribe();
      }
      _channel = null;
    }
    _subscribedUserId = userId;

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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'guardians',
          callback: (payload) {
            final record = payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord;
            final ownerId = record['owner_id'] as String?;
            final guardianId = record['guardian_id'] as String?;
            if (ownerId == userId || guardianId == userId) {
              _log.i(
                '[REALTIME] Perubahan relasi guardian terdeteksi '
                '(event: ${payload.eventType.name}), memperbarui daftar guardian...',
              );
              _ref.read(whoAddedMeProvider.notifier).refresh();
              _ref.read(guardianProvider.notifier).refreshGuardians();
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _reconnectAttempts = 0;
            _log.i(
              '[REALTIME][app_events_$userId] Status: SUBSCRIBED '
              '(messages, calls, sos_sessions, profiles, guardians aktif).',
            );
          } else if (status == RealtimeSubscribeStatus.channelError) {
            _log.e(
              '[REALTIME][app_events_$userId] Status: CHANNEL_ERROR! '
              'Gagal berlangganan channel: $error',
            );
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            _log.w(
              '[REALTIME][app_events_$userId] Status: TIMED_OUT! '
              'Timeout saat berlangganan channel: $error',
            );
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.closed) {
            _log.w('[REALTIME][app_events_$userId] Status: CLOSED (channel ditutup).');
            _scheduleReconnect();
          } else {
            _log.i('[REALTIME][app_events_$userId] Status: $status, error: $error');
          }
        });

    _log.i(
      'AppRealtimeListener: mendaftarkan subscription channel global public:app_events_$userId '
      '(menunggu konfirmasi websocket)...',
    );
  }

  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    _stopChannel();
  }
}

/// Provider untuk listener global terpadu agar lifecycle terikat ke widget root.
final appRealtimeListenerProvider = Provider<AppRealtimeListener>((ref) {
  final listener = AppRealtimeListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});