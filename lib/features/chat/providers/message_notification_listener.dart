import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/notification_service.dart';
import '../../../data/services/e2ee_service.dart';
import 'chat_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'call_invitation_listener.dart';

/// Listener terpusat untuk notifikasi pesan masuk (Opsi A dari Implementation Plan).
///
/// Berlangganan ke Realtime `postgres_changes` pada tabel `messages` dengan
/// `eventType: INSERT`. Untuk tiap baris:
///   1. Abaikan jika pengirim adalah user sendiri (broadcast echo).
///   2. Abaikan jika user sedang membuka room tersebut (activeRoomIdProvider)
///      — UX: tidak perlu notif saat sedang melihat percakapan.
///   3. Tampilkan notifikasi lokal + suara + haptik ringan via NotificationService.
///
/// Safety: blast radius dibatasi — hanya trigger saat app dalam foreground
/// (listener digerakkan oleh app lifecycle, bukan push server).
class MessageNotificationListener {
  final Ref _ref;
  final Logger _log = Logger();
  RealtimeChannel? _channel;
  bool _disposed = false;

  MessageNotificationListener(this._ref);

  void start() {
    final supabaseService = _ref.read(supabaseServiceProvider);
    final userId = supabaseService.currentUserId;
    if (userId == null) {
      _log.w('MessageNotificationListener: user belum login, skip.');
      return;
    }

    _channel = supabaseService.client
        .channel('public:messages:incoming')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: _onInsert,
        )
        .subscribe();

    _log.i('MessageNotificationListener: mulai berlangganan messages.');
  }

  void _onInsert(PostgresChangePayload payload) {
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
    if (!shouldNotify(
      currentUserId: currentUserId,
      senderId: senderId,
      roomId: roomId,
      activeRoomId: _ref.read(activeRoomIdProvider),
      isDeleted: isDeleted,
    )) {
      return;
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

  Future<void> _notify(
    String roomId,
    String senderId,
    String content,
    bool isEncrypted,
  ) async {
    final repo = _ref.read(chatRepositoryProvider);
    String senderName = 'Seseorang';
    try {
      final profile = await repo.searchProfileById(senderId);
      if (profile != null) {
        senderName = (profile['full_name'] as String?) ??
            (profile['username'] as String?) ??
            'Seseorang';
      }
    } catch (_) {
      // Fallback ke nama default jika profil gagal diambil.
    }

    // Dekripsi konten pesan jika terenkripsi
    String displayContent = content;
    if (isEncrypted && content.isNotEmpty) {
      try {
        final decrypted = await E2eeService.instance.decryptForRoom(roomId, content);
        displayContent = decrypted;
      } catch (_) {
        displayContent = E2eeService.undecryptableText;
      }
    }

    await NotificationService.showMessageNotification(
      title: senderName,
      body: displayContent,
      roomId: roomId,
    );
  }

  void dispose() {
    _disposed = true;
    _channel?.unsubscribe();
    _channel = null;
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
    ref.read(messageNotificationListenerProvider).start();
    ref.read(callInvitationListenerProvider).start();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
