import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/repositories/call_repository.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_dedup_service.dart';
import 'chat_provider.dart';
import 'call_state_provider.dart';
import 'private_vault_provider.dart';
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
  void handleInsertCall(PostgresChangePayload payload) {
    if (_disposed) return;
    processIncomingCallRecord(payload.newRecord);
  }

  /// Memproses data panggilan masuk baik dari realtime listener maupun recovery queue
  Future<void> processIncomingCallRecord(Map<String, dynamic> newRow) async {
    if (_disposed) return;

    final callId = newRow['id'] as String?;
    final roomId = newRow['room_id'] as String?;
    final callerId = newRow['caller_id'] as String?;
    final receiverId = newRow['receiver_id'] as String?;
    final callType = newRow['call_type'] as String? ?? 'voice';
    final status = newRow['status'] as String?;

    final currentUserId = _ref.read(supabaseServiceProvider).currentUserId;
    _log.i(
      '[CALL_INVITE] Menerima record calls: '
      'callId=$callId, callerId=$callerId, receiverId=$receiverId, '
      'status=$status, currentUserId=$currentUserId',
    );

    if (currentUserId == null) {
      _log.w('[CALL_INVITE] Diabaikan: currentUserId adalah null');
      return;
    }

    if (receiverId != currentUserId) {
      _log.d(
        '[CALL_INVITE] Diabaikan: receiverId ($receiverId) != currentUserId ($currentUserId)',
      );
      return; // Abaikan jika kita bukan penerima panggilan ini
    }

    final isValidStatus = status == 'calling' || status == 'ringing';
    if (callId == null ||
        roomId == null ||
        callerId == null ||
        !isValidStatus) {
      _log.w(
        '[CALL_INVITE] Diabaikan: payload tidak valid atau status bukan calling/ringing '
        '(callId=$callId, roomId=$roomId, callerId=$callerId, status=$status)',
      );
      return;
    }

    _log.i(
      '🔔 [CALL_INVITE] Validasi lolos: Memproses panggilan masuk $callId dari $callerId',
    );

    // Call Collision Guard: Jika user sedang aktif dalam panggilan lain, otomatis tolak dengan status 'busy'
    final activeCallId = _ref.read(activeCallIdProvider);
    if (activeCallId != null && activeCallId != callId) {
      _log.w(
        '[CALL_INVITE] User sedang sibuk dalam panggilan $activeCallId. '
        'Menolak panggilan masuk $callId (busy).',
      );
      try {
        await _ref.read(callRepositoryProvider).updateCallStatus(callId, 'busy');
      } catch (e) {
        _log.e('[CALL_INVITE] Gagal memperbarui status panggilan ke busy: $e');
      }
      return;
    }

    // Dedup: cek apakah sudah dinotifikasi dari jalur FCM atau Realtime sebelumnya
    if (NotificationDedupService.isDuplicate('call_$callId')) {
      _log.w(
        '[CALL_INVITE] Diabaikan: Panggilan $callId sudah pernah diproses (dedup match).',
      );
      return;
    }
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
    } catch (e) {
      _log.w('[CALL_INVITE] Gagal memuat profil pemanggil ($callerId): $e');
    }

    // Cek apakah room/caller termasuk kontak Private Vault yang sedang terkunci (terisolasi per-slot)
    final isVaultLocked = VaultIsolationHelper.isRoomCloaked(
      _ref,
      roomId: roomId,
      otherUserId: callerId,
    );
    final callerSlot = VaultIsolationHelper.getContactVaultSlot(_ref, callerId);

    // 1. Tampilkan layar panggilan masuk langsung ke UI (decoupling dari notifikasi/audio)
    void navigateToIncomingScreen(BuildContext ctx) {
      Navigator.of(ctx).push(
        // PENGECAHAN TRANSISI: layar panggilan masuk sengaja memakai
        // MaterialPageRoute (platform-feel ala dialer OS).
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: callId,
            roomId: roomId,
            callerId: callerId,
            callerName: callerName,
            callerAvatarUrl: callerAvatarUrl,
            callType: callType,
            isVaultLocked: isVaultLocked,
            callerSlot: callerSlot,
          ),
        ),
      );
    }

    final context = AppNavigator.currentContext;
    if (context != null && context.mounted) {
      _log.i('[CALL_INVITE] Membuka IncomingCallScreen untuk callId=$callId (isVaultLocked: $isVaultLocked)');
      navigateToIncomingScreen(context);
    } else {
      _log.w(
        '[CALL_INVITE] PERINGATAN: AppNavigator.currentContext bernilai null atau unmounted! '
        'Mencoba via addPostFrameCallback...',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retryContext = AppNavigator.currentContext;
        if (retryContext != null && retryContext.mounted) {
          _log.i(
            '[CALL_INVITE] Membuka IncomingCallScreen (via post-frame retry) untuk callId=$callId (isVaultLocked: $isVaultLocked)',
          );
          navigateToIncomingScreen(retryContext);
        } else {
          _log.e(
            '[CALL_INVITE] GAGAL TOTAL: Tidak ada context aktif untuk membuka IncomingCallScreen',
          );
        }
      });
    }

    // 2. Bunyikan ringtone & tampilkan notifikasi secara terpisah (disamarkan jika vault terkunci)
    final notificationCallerName = isVaultLocked ? 'MEKAAR' : callerName;
    final notificationAvatarUrl = isVaultLocked ? null : callerAvatarUrl;

    NotificationService.showIncomingCallNotification(
      callerName: notificationCallerName,
      callType: callType,
      roomId: roomId,
      callId: callId,
      callerId: callerId,
      callerAvatarUrl: notificationAvatarUrl,
    ).catchError((e) {
      _log.e('[CALL_INVITE] Gagal menyalakan notifikasi/ringtone panggilan masuk: $e');
    });
  }

  /// Memeriksa panggilan masuk yang tertunda atau panggilan tak terjawab saat aplikasi
  /// dibuka kembali (mitigasi ketika aplikasi tertutup/dimatikan OS).
  Future<void> checkPendingCallsOnResume() async {
    if (_disposed) return;
    final currentUserId = _ref.read(supabaseServiceProvider).currentUserId;
    if (currentUserId == null) return;

    try {
      final callRepo = _ref.read(callRepositoryProvider);

      // 1. Cek apakah ada panggilan yang masih berdering (dalam window 45 detik)
      final pendingCall = await callRepo.getPendingIncomingCall(currentUserId);
      if (pendingCall != null) {
        final callId = pendingCall['id'] as String?;
        if (callId != null &&
            !NotificationDedupService.isDuplicate('call_$callId')) {
          _log.i('[CALL_RESUME] Menemukan panggilan tertunda yang masih aktif: $callId');
          await processIncomingCallRecord(pendingCall);
          return;
        }
      }

      // 2. Cek apakah ada panggilan tak terjawab yang terjadi saat offline
      final missedCalls = await callRepo.getRecentMissedCalls(currentUserId);
      for (final missed in missedCalls) {
        final callId = missed['id'] as String?;
        final callerId = missed['caller_id'] as String?;
        final roomId = missed['room_id'] as String?;
        final callType = missed['call_type'] as String? ?? 'voice';
        if (callId == null || callerId == null) continue;

        if (!NotificationDedupService.isDuplicate('missed_$callId')) {
          NotificationDedupService.markNotified('missed_$callId');

          final chatRepo = _ref.read(chatRepositoryProvider);
          String callerName = 'Seseorang';
          try {
            final profile = await chatRepo.searchProfileById(callerId);
            if (profile != null) {
              callerName = (profile['display_name'] as String?)?.isNotEmpty == true
                  ? profile['display_name'] as String
                  : (profile['full_name'] as String?) ??
                      (profile['username'] as String?) ??
                      'Seseorang';
            }
          } catch (_) {}

          final isVaultLocked = VaultIsolationHelper.isRoomCloaked(
            _ref,
            roomId: roomId,
            otherUserId: callerId,
          );

          await NotificationService.showMissedCallNotification(
            callerName: isVaultLocked ? 'MEKAAR' : callerName,
            callType: callType,
            roomId: roomId,
            callId: callId,
            callerId: isVaultLocked ? null : callerId,
          );
        }
      }
    } catch (e) {
      _log.w('[CALL_RESUME] Gagal memeriksa antrian panggilan offline: $e');
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
