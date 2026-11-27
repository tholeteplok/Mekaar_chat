import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/local_message_database.dart';
import '../providers/chat_provider.dart';

/// Pengendali lifecycle background, timer, dan pengaturan privasi per-ruangan obrolan.
///
/// Mengisolasi:
/// 1. Presence heartbeat timer (30 detik).
/// 2. Auto-delete purge timer (10 detik).
/// 3. Scheduled wipe timer & periodic reschedule.
/// 4. Supabase Realtime 'chat_rooms' settings stream subscription.
/// 5. State pengaturan ruangan (auto-delete, burn on exit, scheduled wipe, view once, mute).
class ChatScreenController extends ChangeNotifier {
  final String chatId;
  final String? effectiveOtherUserId;
  final String? Function()? getOtherUserId;
  final WidgetRef ref;
  final FocusNode composerFocusNode;
  final bool Function() isKeyboardVisible;
  final bool Function() isMounted;
  final bool Function()? hasExpiringMessages;
  final ValueNotifier<DateTime?> otherLastSeenNotifier;

  ChatScreenController({
    required this.chatId,
    required this.ref,
    required this.composerFocusNode,
    required this.isKeyboardVisible,
    required this.isMounted,
    required this.otherLastSeenNotifier,
    this.hasExpiringMessages,
    this.effectiveOtherUserId,
    this.getOtherUserId,
  });

  String? get currentOtherUserId =>
      getOtherUserId?.call() ?? effectiveOtherUserId;

  Timer? _presenceHeartbeatTimer;
  Timer? _purgeTimer;
  Timer? _scheduledWipeTimer;
  StreamSubscription? _roomSettingsSub;

  int _autoDeleteHours = 0;
  int _autoDeleteMinutes = 0;
  bool _burnOnExit = false;
  bool _burnTriggered = false;
  String _scheduledWipeMode = 'off';
  DateTime? _scheduledWipeTargetAt;
  bool _isViewOnce = false;
  bool _isMuted = false;
  bool _isDisposed = false;
  bool _isPaused = false;

  int get autoDeleteHours => _autoDeleteHours;
  int get autoDeleteMinutes => _autoDeleteMinutes;
  bool get burnOnExit => _burnOnExit;
  bool get burnTriggered => _burnTriggered;
  String get scheduledWipeMode => _scheduledWipeMode;
  DateTime? get scheduledWipeTargetAt => _scheduledWipeTargetAt;
  bool get isViewOnce => _isViewOnce;
  bool get isMuted => _isMuted;
  bool get isDisposed => _isDisposed;
  bool get isPaused => _isPaused;
  bool get shouldRunPurgeTimer =>
      _autoDeleteMinutes > 0 ||
      _scheduledWipeMode != 'off' ||
      (hasExpiringMessages?.call() ?? false);

  /// Memulai semua timer background dan listener stream pengaturan ruangan.
  void start() {
    if (_isDisposed) return;
    _isPaused = false;
    unawaited(loadRoomSettings());
    _startPresenceHeartbeat();
    _startPurgeTimer();
    _startRoomSettingsStream();
  }

  /// Hentikan timer background sementara saat aplikasi di-background/inactive.
  void pauseBackgroundTimers() {
    if (_isDisposed || _isPaused) return;
    _isPaused = true;
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _purgeTimer?.cancel();
    _purgeTimer = null;
  }

  /// Jalankan kembali timer background saat aplikasi kembali ke foreground.
  void resumeBackgroundTimers() {
    if (_isDisposed || !_isPaused) return;
    _isPaused = false;
    _startPresenceHeartbeat();
    _startPurgeTimer();
  }

  /// Sinkronkan status timer purge (mis. setelah loadRoomSettings atau ada pesan baru dengan autoDeleteAt).
  void syncPurgeTimerState() => _startPurgeTimer();

  /// Memulai ulang atau menjalankan siklus heartbeat secara eksplisit.
  void startPresenceHeartbeat() => _startPresenceHeartbeat();

  /// Timer detak kehadiran (presence heartbeat) setiap 30 detik.
  void _startPresenceHeartbeat() {
    if (_isDisposed ||
        _isPaused ||
        LocalMessageDatabase.instance.isDecoy ||
        chatId == 'room_welcome_mekaar') {
      return;
    }
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (_isDisposed || _isPaused || !isMounted()) return;

        try {
          final repo = ref.read(chatRepositoryProvider);
          final otherId = currentOtherUserId;
          if (otherId != null) {
            final results = await Future.wait<dynamic>([
              repo.updateLastSeen(),
              repo.getLastSeen(otherId),
            ]);
            final lastSeen = results[1] as DateTime?;
            if (!_isDisposed && !_isPaused && isMounted()) {
              otherLastSeenNotifier.value = lastSeen;
            }
          } else {
            await repo.updateLastSeen();
          }
        } catch (_) {}
      },
    );
  }

  /// Timer periodik pembersihan pesan kedaluwarsa (purge) setiap 10 detik.
  /// Hanya aktif bila room memiliki disappearing messages, scheduled wipe, atau pesan expiring aktif.
  void _startPurgeTimer() {
    if (_isDisposed || _isPaused || !shouldRunPurgeTimer) {
      _purgeTimer?.cancel();
      _purgeTimer = null;
      return;
    }
    if (_purgeTimer?.isActive ?? false) return;
    _purgeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isDisposed || _isPaused || !isMounted()) return;
      // Jangan ganggu fokus input dan cegah penutupan keyboard virtual oleh IME Android:
      // Jika composer sedang memiliki fokus atau keyboard sedang terbuka, tunda pembersihan berkala.
      if (composerFocusNode.hasFocus || isKeyboardVisible()) return;

      try {
        ref.read(chatRepositoryProvider).purgeExpiredMessages(
          targetRoomId: chatId,
        );
      } catch (_) {}
    });
  }

  /// Berlangganan perubahan baris tabel 'chat_rooms' di Supabase Realtime.
  void _startRoomSettingsStream() {
    try {
      _roomSettingsSub?.cancel();
      _roomSettingsSub = Supabase.instance.client
          .from('chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('id', chatId)
          .listen((_) {
            if (!_isDisposed && isMounted()) {
              loadRoomSettings();
            }
          });
    } catch (_) {
      // Graceful fallback untuk lingkungan testing atau offline
    }
  }

  /// Memuat konfigurasi pengaturan ruangan terkini dari remote/local database.
  Future<void> loadRoomSettings() async {
    if (_isDisposed) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final roomAutoDeleteMinutes = await repo.getRoomDisappearingMinutes(chatId);
      final roomBurnOnExit = await repo.getRoomBurnOnExit(chatId);
      String loadedWipeMode = 'off';
      DateTime? loadedWipeTarget;
      try {
        final wipeData = await repo.getRoomScheduledWipe(chatId);
        if (wipeData != null) {
          loadedWipeMode = wipeData['scheduled_wipe_mode'] as String? ?? 'off';
          final targetStr = wipeData['scheduled_wipe_target_at'] as String?;
          loadedWipeTarget = targetStr != null
              ? DateTime.tryParse(targetStr)?.toUtc()
              : null;
        }
      } catch (_) {}

      // Muat ulang preferensi Sekali Lihat (View Once) per-room dari SharedPreferences
      bool savedViewOnce = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        savedViewOnce = prefs.getBool('room_view_once_$chatId') ?? false;
      } catch (_) {}

      // Muat preferensi bisukan notifikasi per-room
      bool loadedMuted = false;
      try {
        final participantPrefs = await repo.getRoomPreferences(chatId);
        loadedMuted = participantPrefs?.isMuted ?? false;
      } catch (_) {}

      if (_isDisposed || !isMounted()) return;

      _autoDeleteMinutes = roomAutoDeleteMinutes;
      _autoDeleteHours = (_autoDeleteMinutes / 60).ceil();
      _burnOnExit = roomBurnOnExit;
      _scheduledWipeMode = loadedWipeMode;
      _scheduledWipeTargetAt = loadedWipeTarget;
      _isViewOnce = savedViewOnce;
      _isMuted = loadedMuted;
      notifyListeners();

      if (roomBurnOnExit) {
        unawaited(LocalMessageDatabase.instance.deleteDraft(chatId));
      }
      syncPurgeTimerState();
      scheduleWipeTimer();
    } catch (_) {}
  }

  /// Mengatur countdown timer untuk pembersihan terjadwal (scheduled wipe).
  void scheduleWipeTimer() {
    _scheduledWipeTimer?.cancel();
    if (_scheduledWipeMode == 'off' || _scheduledWipeTargetAt == null) return;

    final now = DateTime.now().toUtc();
    final diff = _scheduledWipeTargetAt!.difference(now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      triggerLocalScheduledWipe();
      if (_scheduledWipeMode == 'daily' && !_isDisposed && isMounted()) {
        _scheduledWipeTargetAt = _scheduledWipeTargetAt!.add(
          const Duration(days: 1),
        );
        notifyListeners();
        scheduleWipeTimer();
      }
      return;
    }

    _scheduledWipeTimer = Timer(diff, () {
      triggerLocalScheduledWipe();
      if (_scheduledWipeMode == 'daily' && !_isDisposed && isMounted()) {
        _scheduledWipeTargetAt = _scheduledWipeTargetAt!.add(
          const Duration(days: 1),
        );
        notifyListeners();
        scheduleWipeTimer();
      }
    });
  }

  /// Eksekusi pembersihan terjadwal lokal & invalidasi cache pesan.
  Future<void> triggerLocalScheduledWipe() async {
    if (_isDisposed) return;
    try {
      await ref.read(chatRepositoryProvider).executeRoomScheduledWipe(chatId);
      if (!_isDisposed && isMounted()) {
        ref.invalidate(chatMessagesProvider(chatId));
        if (_scheduledWipeMode == 'one_shot') {
          _scheduledWipeMode = 'off';
          _scheduledWipeTargetAt = null;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Eksekusi pembersihan instan saat keluar ruangan (Burn on Exit).
  Future<void> triggerBurnOnExit() async {
    if (_burnTriggered || !_burnOnExit || _isDisposed) return;
    _burnTriggered = true;
    try {
      await ref.read(chatRepositoryProvider).executeRoomBurnOnExit(chatId);
      if (!_isDisposed && isMounted()) {
        ref.invalidate(chatMessagesProvider(chatId));
      }
    } catch (_) {}
  }

  /// Memperbarui preferensi View Once lokal.
  void setViewOnce(bool value) {
    if (_isViewOnce != value) {
      _isViewOnce = value;
      notifyListeners();
    }
  }

  /// Memperbarui status bisukan (mute) lokal.
  void setMuted(bool value) {
    if (_isMuted != value) {
      _isMuted = value;
      notifyListeners();
    }
  }

  @visibleForTesting
  void testSetScheduledWipe({required String mode, DateTime? targetAt}) {
    _scheduledWipeMode = mode;
    _scheduledWipeTargetAt = targetAt;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _presenceHeartbeatTimer?.cancel();
    _purgeTimer?.cancel();
    _scheduledWipeTimer?.cancel();
    _roomSettingsSub?.cancel();
    super.dispose();
  }
}
