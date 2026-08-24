import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/emoji_shortcode_parser.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_dedup_service.dart';
import '../../settings/providers/trip_monitor_scheduler.dart';
import 'chat_provider.dart';
import 'private_vault_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'app_realtime_listener.dart';

/// Listener terpusat untuk notifikasi pesan masuk (Opsi A dari Implementation Plan).
///
/// Handler untuk Realtime `postgres_changes` pada tabel `messages` dengan
/// `eventType: INSERT` — channel dikelola bersama oleh [AppRealtimeListener]
/// (satu channel global terpadu, bukan per-listener). Untuk tiap baris:
///   1. Abaikan jika pengirim adalah user sendiri (broadcast echo).
///   2. Abaikan jika user sedang membuka room tersebut (activeRoomIdProvider)
///      — UX: tidak perlu notif saat sedang melihat percakapan.
///   3. Tampilkan notifikasi lokal + suara + haptik ringan via NotificationService.
///
/// Safety: blast radius dibatasi — hanya trigger saat app dalam foreground
/// (listener digerakkan oleh app lifecycle, bukan push server).
class MessageNotificationListener {
  final Ref _ref;
  bool _disposed = false;

  MessageNotificationListener(this._ref);

  /// Dipanggil oleh [AppRealtimeListener] (channel global terpadu) saat ada
  /// INSERT di tabel messages.
  void handleInsert(PostgresChangePayload payload) {
    if (_disposed) return;

    final newRow = payload.newRecord;
    final roomId = newRow['room_id'] as String?;
    final senderId = newRow['sender_id'] as String?;
    final content = newRow['content'] as String? ?? '';
    final isDeleted = newRow['is_deleted'] as bool? ?? false;
    final isEncrypted = newRow['is_encrypted'] as bool? ?? false;

    final currentUserId = _ref.read(supabaseServiceProvider).currentUserId;
    if (roomId == null || senderId == null || currentUserId == null) return;

    // 1. Echo broadcast: abaikan pesan sendiri.
    // 2. User sedang di room ini? Jangan ganggu.
    // 3. Pesan yang di-soft-delete tidak perlu notif.
    // 4. Dedup: abaikan jika sudah dinotifikasi dari jalur FCM.
    if (!shouldNotify(
      currentUserId: currentUserId,
      senderId: senderId,
      roomId: roomId,
      activeRoomId: _ref.read(activeRoomIdProvider),
      isDeleted: isDeleted,
    )) {
      return;
    }

    // Dedup: cek apakah sudah dinotifikasi dari jalur FCM
    final messageId = newRow['id'] as String?;
    if (messageId != null &&
        NotificationDedupService.isDuplicate('msg_$messageId')) {
      return;
    }
    if (messageId != null) {
      NotificationDedupService.markNotified('msg_$messageId');
    }

    _notify(roomId, senderId, content, isEncrypted);
  }

  /// Filter murni (tanpa side-effect) untuk menentukan apakah sebuah pesan
  /// masuk layak memicu notifikasi. Diekstrak sebagai static method agar
  /// dapat diuji unit tanpa perlu menginisialisasi Supabase/Ref.
  ///
  /// Aturan:
  ///  - Abaikan jika [senderId] == [currentUserId] (echo broadcast diri sendiri).
  ///  - Abaikan jika user sedang membuka [roomId] ([activeRoomId] sama).
  ///  - Abaikan jika pesan di-soft-delete ([isDeleted] true).
  static bool shouldNotify({
    required String currentUserId,
    required String senderId,
    required String roomId,
    required String? activeRoomId,
    required bool isDeleted,
  }) {
    if (senderId == currentUserId) return false; // echo
    if (activeRoomId == roomId) return false; // lagi di room ini
    if (isDeleted) return false; // pesan dihapus
    return true;
  }

  final Map<String, String> _senderNameCache = {};
  final Map<String, ({bool isMuted, DateTime? mutedUntil, DateTime cachedAt})> _roomMuteCache = {};

  Future<void> _notify(
    String roomId,
    String senderId,
    String content,
    bool isEncrypted,
  ) async {
    // Cek apakah room di-mute oleh user (dengan cache in-memory)
    if (await _isRoomMuted(roomId)) return;

    final repo = _ref.read(chatRepositoryProvider);
    String senderName = _senderNameCache[senderId] ?? 'Seseorang';
    if (!_senderNameCache.containsKey(senderId)) {
      try {
        final profile = await repo.searchProfileById(senderId);
        if (profile != null) {
          senderName = (profile['full_name'] as String?) ??
              (profile['username'] as String?) ??
              'Seseorang';
          _senderNameCache[senderId] = senderName;
        }
      } catch (_) {
        // Fallback ke nama default jika profil gagal diambil.
      }
    }

    // Cek apakah room disembunyikan dalam Private Contact Vault
    final isHidden = _ref.read(hiddenRoomIdsProvider).contains(roomId);
    final isVaultUnlocked = _ref.read(privateVaultUnlockedProvider);

    final String finalTitle;
    final String finalBody;

    if (isHidden && !isVaultUnlocked) {
      // Masking total: Jangan bocorkan nama pengirim maupun isi pesan
      finalTitle = 'Pemberitahuan Sistem';
      finalBody = 'Anda menerima pesan baru';
    } else {
      finalTitle = senderName;
      finalBody = isEncrypted
          ? '🔒 Pesan terenkripsi'
          : replaceCustomEmojiTokens(content, (_) => '[emoji]');
    }

    await NotificationService.showMessageNotification(
      title: finalTitle,
      body: finalBody,
      roomId: roomId,
    );
  }

  /// Cek apakah room saat ini di-mute oleh user yang sedang login (dengan TTL 5 menit).
  Future<bool> _isRoomMuted(String roomId) async {
    final now = DateTime.now();
    final cached = _roomMuteCache[roomId];
    if (cached != null && now.difference(cached.cachedAt) < const Duration(minutes: 5)) {
      if (!cached.isMuted) return false;
      if (cached.mutedUntil == null) return true;
      return cached.mutedUntil!.isAfter(DateTime.now().toUtc());
    }

    try {
      final client = _ref.read(supabaseServiceProvider).client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await client
          .from('room_participants')
          .select('is_muted, muted_until')
          .eq('room_id', roomId)
          .eq('profile_id', userId)
          .maybeSingle();

      if (response == null) {
        _roomMuteCache[roomId] = (isMuted: false, mutedUntil: null, cachedAt: now);
        return false;
      }

      final isMuted = response['is_muted'] as bool? ?? false;
      final mutedUntilStr = response['muted_until'] as String?;
      final mutedUntil = mutedUntilStr != null ? DateTime.parse(mutedUntilStr) : null;

      _roomMuteCache[roomId] = (isMuted: isMuted, mutedUntil: mutedUntil, cachedAt: now);

      if (!isMuted) return false;
      if (mutedUntil == null) return true; // muted tanpa batas waktu

      return mutedUntil.isAfter(DateTime.now().toUtc());
    } catch (_) {
      return false; // default: jangan blokir notifikasi jika query gagal
    }
  }

  void dispose() {
    _disposed = true;
  }
}

/// Provider untuk listener agar lifecycle terikat ke widget root (MekaarApp).
final messageNotificationListenerProvider = Provider<MessageNotificationListener>((
  ref,
) {
  final listener = MessageNotificationListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});

/// Widget root yang bertugas memulai listener sejak app jalan.
/// Ditempelkan di atas MekaarApp agar lifecycle listener terikat ke tree.
class NotificationListenerHost extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationListenerHost({super.key, required this.child});

  @override
  ConsumerState<NotificationListenerHost> createState() =>
      _NotificationListenerHostState();
}

class _NotificationListenerHostState
    extends ConsumerState<NotificationListenerHost> {
  @override
  void initState() {
    super.initState();
    // Pastikan tidak ada room "aktif" tersisa dari sesi sebelumnya.
    ref.read(activeRoomIdProvider.notifier).state = null;
    // Satu channel global terpadu untuk seluruh listener notifikasi DB
    // (messages, calls, sos_sessions, profiles) — mengurangi kontensi subscribe.
    ref.read(appRealtimeListenerProvider).start();
    ref.read(tripMonitorSchedulerProvider).start();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
