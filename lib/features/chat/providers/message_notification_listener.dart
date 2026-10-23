import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/emoji_shortcode_parser.dart';
import '../../../core/utils/message_preview_resolver.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../data/services/local_message_database.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/notification_dedup_service.dart';
import '../../settings/providers/trip_monitor_scheduler.dart';
import 'chat_provider.dart';
import 'emoji_pack_provider.dart';
import 'private_vault_provider.dart';
import '../../settings/providers/privacy_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'app_realtime_listener.dart';
import 'call_invitation_listener.dart';
import 'sos_alert_listener.dart';

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
    final msgType = newRow['msg_type'] as String? ?? 'text';

    final currentUserId = _ref.read(supabaseServiceProvider).currentUserId;
    if (roomId == null || senderId == null || currentUserId == null) return;
    if (isDeleted) return;

    final activeRoomId = _ref.read(activeRoomIdProvider);
    final isCurrentlyInRoom = activeRoomId == roomId;
    final isFromOtherUser = senderId != currentUserId;

    // Pembaruan Optimistik Local-First:
    // Dekripsi background, simpan ke database SQLite lokal, dan mutasi RAM seketika (0 ms).
    unawaited(
      _processLocalFirstUpdate(
        newRow: newRow,
        roomId: roomId,
        senderId: senderId,
        rawContent: content,
        isEncrypted: isEncrypted,
        msgType: msgType,
        isFromOtherUser: isFromOtherUser,
        isCurrentlyInRoom: isCurrentlyInRoom,
        currentUserId: currentUserId,
      ),
    );
  }

  Future<void> _processLocalFirstUpdate({
    required Map<String, dynamic> newRow,
    required String roomId,
    required String senderId,
    required String rawContent,
    required bool isEncrypted,
    required String msgType,
    required bool isFromOtherUser,
    required bool isCurrentlyInRoom,
    required String currentUserId,
  }) async {
    String decryptedContent = rawContent;
    Message? messageObj;

    try {
      messageObj = Message.fromJson(newRow);
    } catch (_) {}

    if (isEncrypted && rawContent.isNotEmpty) {
      try {
        decryptedContent =
            await E2eeService.instance.decryptForRoom(roomId, rawContent);
        if (messageObj != null) {
          messageObj = messageObj.copyWith(content: decryptedContent);
        }
      } catch (_) {
        decryptedContent = E2eeService.undecryptableText;
      }
    }

    if (messageObj != null) {
      unawaited(LocalMessageDatabase.instance.saveMessage(messageObj));
    }

    final isStillEncrypted = isEncrypted && decryptedContent == rawContent;

    final previewText = formatPreviewText(
      msgType: msgType,
      content: decryptedContent,
      isEncrypted: isStillEncrypted,
      isFromOtherUser: isFromOtherUser,
    );

    final createdAt = messageObj?.createdAt ??
        (DateTime.tryParse(newRow['created_at'] as String? ?? '') ??
            DateTime.now());

    // Update RAM seketika tanpa query HTTP monolitik
    _ref.read(chatRoomsProvider.notifier).updateLastMessageLocally(
      roomId: roomId,
      previewText: previewText,
      timestamp: createdAt,
      isFromOtherUser: isFromOtherUser,
      isCurrentlyInRoom: isCurrentlyInRoom,
    );

    // Filter notifikasi sistem (suara, banner, dsb)
    if (!shouldNotify(
      currentUserId: currentUserId,
      senderId: senderId,
      roomId: roomId,
      activeRoomId: _ref.read(activeRoomIdProvider),
      isDeleted: false,
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

    _notify(
      roomId,
      senderId,
      decryptedContent,
      isStillEncrypted,
      msgType: msgType,
    );
  }

  /// Format cuplikan teks untuk preview daftar chat
  static String formatPreviewText({
    required String msgType,
    required String content,
    required bool isEncrypted,
    required bool isFromOtherUser,
  }) {
    if (isEncrypted) {
      return isFromOtherUser ? 'Pesan baru' : '••••••••';
    }
    return MessagePreviewResolver.formatChatListPreview(
      rawMsgType: msgType,
      content: content,
      isUnreadFromOther: isFromOtherUser,
    );
  }

  /// Dipanggil saat ada perubahan pesan (update/soft-delete) di tabel messages
  void handleMessageChange(PostgresChangePayload payload) {
    if (_disposed) return;
    _ref.read(chatRoomsProvider.notifier).refreshRooms();
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

  /// Format cuplikan isi notifikasi sesuai tipe pesan dan setelan privasi
  static String formatNotificationBody({
    required String msgType,
    required String content,
    bool isEncrypted = false,
    bool isStealthPreview = false,
  }) {
    if (isEncrypted) {
      return '🔒 Pesan terenkripsi';
    }
    if (isStealthPreview) {
      return '••••••••';
    }
    switch (msgType) {
      case 'image':
        return '📷 Foto';
      case 'voice':
        return '🎤 Pesan suara';
      case 'video':
        return '🎬 Video';
      case 'file':
        if (MessagePreviewResolver.isRecognizedDocument(content)) {
          return '📎 Dokumen';
        }
        return '📎 Berkas';
      case 'location':
        return '📍 Lokasi';
      default:
        final cleaned = replaceCustomEmojiTokens(content, (_) => '[emoji]');
        return cleaned.isNotEmpty ? cleaned : 'Pesan baru';
    }
  }

  final Map<String, String> _senderNameCache = {};
  final Map<String, ({bool isMuted, DateTime? mutedUntil, DateTime cachedAt})> _roomMuteCache = {};

  Future<void> _notify(
    String roomId,
    String senderId,
    String content,
    bool isEncrypted, {
    String msgType = 'text',
  }) async {
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

    // Cek apakah room/sender disembunyikan dalam Private Contact Vault (terisolasi per-slot)
    final isCloaked = VaultIsolationHelper.isRoomCloaked(
      _ref,
      roomId: roomId,
      otherUserId: senderId,
    );
    final isStealthPreview = _ref.read(stealthChatPreviewProvider);

    final String finalTitle;
    final String finalBody;

    if (isCloaked) {
      // Masking total ala WhatsApp Locked Chat:
      // Tampilkan nama brand & teks netral tanpa membocorkan pengirim/isi pesan
      finalTitle = 'MEKAAR';
      finalBody = 'Pesan baru masuk';
    } else {
      finalTitle = senderName;
      finalBody = formatNotificationBody(
        msgType: msgType,
        content: content,
        isEncrypted: isEncrypted,
        isStealthPreview: isStealthPreview,
      );
    }

    await NotificationService.showMessageNotification(
      title: finalTitle,
      body: finalBody,
      roomId: roomId,
      route: NotificationRoute(
        type: NotificationRouteType.message,
        roomId: roomId,
        chatName: isCloaked ? null : senderName,
        otherUserId: isCloaked ? null : senderId,
      ),
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
    extends ConsumerState<NotificationListenerHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pastikan tidak ada room "aktif" tersisa dari sesi sebelumnya.
    ref.read(activeRoomIdProvider.notifier).state = null;
    ref.read(appRealtimeListenerProvider).start();
    ref.read(tripMonitorSchedulerProvider).start();
    // Cek antrian panggilan offline saat cold start
    Future.microtask(() {
      ref.read(callInvitationListenerProvider).checkPendingCallsOnResume();
      ref.read(sosAlertListenerProvider).checkActiveSOSOnResume();
      ref.read(emojiCatalogProvider.future);
      ref.read(installedPacksProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 1. Pulihkan koneksi realtime channel jika sempat terputus/closed saat background
      ref.read(appRealtimeListenerProvider).reconnectIfNeeded();
      // 2. Periksa antrian panggilan offline (mitigasi app tertutup / background dibunuh OS)
      ref.read(callInvitationListenerProvider).checkPendingCallsOnResume();
      // 2b. Periksa apakah ada SOS darurat aktif dari orang yang dijaga
      ref.read(sosAlertListenerProvider).checkActiveSOSOnResume();
      // 3. Refresh chat rooms agar badge unread & pesan terkini ter-update
      ref.read(chatRoomsProvider.notifier).refreshRooms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
