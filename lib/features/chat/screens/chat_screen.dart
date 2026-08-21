import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/chat_date_separator.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/screen_protection_widgets.dart';
import '../../../core/widgets/scroll_to_bottom_button.dart';
import '../../../data/repositories/forwarding_protection_repository.dart';
import '../providers/chat_provider.dart';
import '../providers/forwarding_protection_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/scheduled_wipe_bottom_sheet.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/e2ee_preparation_banner.dart';
import '../providers/e2ee_room_status_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/media_upload_service.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../../../core/routes/app_routes.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final String? chatAvatarUrl;
  final bool isGuardian;
  final bool isGroup;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.chatAvatarUrl,
    this.isGuardian = false,
    this.isGroup = false,
    this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

enum _ChatItemKind { message, dateSeparator }

class _ChatItemEntry {
  final _ChatItemKind kind;
  final Message? message;
  final DateTime? date;

  const _ChatItemEntry.message(this.message)
      : kind = _ChatItemKind.message,
        date = null;

  const _ChatItemEntry.dateSeparator(this.date)
      : kind = _ChatItemKind.dateSeparator,
        message = null;
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isViewOnce = false;
  bool _burnOnExit = false;
  bool _burnTriggered = false;
  Message? _replyMessage;
  Message? _editingMessage;
  DateTime? _otherLastRead;
  final ValueNotifier<DateTime?> _otherLastSeenNotifier = ValueNotifier<DateTime?>(null);
  int _autoDeleteHours = 0;
  String _scheduledWipeMode = 'off';
  TimeOfDay? _scheduledWipeTime;
  DateTime? _scheduledWipeTargetAt;
  final ValueNotifier<bool> _showScrollButton = ValueNotifier<bool>(false);
  final ValueNotifier<int> _newMessageCount = ValueNotifier<int>(0);
  Map<String, String> _participantNames = {};
  Timer? _purgeTimer;
  Timer? _scheduledWipeTimer;

  Future<void> _loadGroupParticipants() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final details = await repo.getGroupDetails(widget.chatId);
      if (details != null && mounted) {
        final participants = (details['participants'] as List?) ?? [];
        final names = <String, String>{};
        for (final p in participants) {
          final pid = p['profile_id'] as String?;
          final profile = p['public_profiles'] as Map<String, dynamic>?;
          if (pid != null && profile != null) {
            final name = (profile['display_name'] as String?)?.isNotEmpty == true
                ? profile['display_name'] as String
                : profile['full_name'] as String? ??
                    profile['username'] as String? ??
                    'Anggota';
            names[pid] = name;
          }
        }
        setState(() => _participantNames = names);
      }
    } catch (_) {}
  }

  void _onScrollChanged() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
             _scrollController.position.minScrollExtent + 200;
    if (_showScrollButton.value != atBottom) {
      _showScrollButton.value = atBottom;
      if (!atBottom && _newMessageCount.value > 0) {
        _newMessageCount.value = 0;
      }
    }
  }

  Timer? _presenceHeartbeatTimer;

  void _startPresenceHeartbeat() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final repo = ref.read(chatRepositoryProvider);
      await repo.updateLastSeen();
      if (widget.otherUserId != null) {
        final lastSeen = await repo.getLastSeen(widget.otherUserId!);
        if (mounted) {
          _otherLastSeenNotifier.value = lastSeen;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollChanged);
    // Tandai room ini sebagai aktif agar listener notifikasi pesan tahu
    // untuk tidak memunculkan notif saat user sedang melihat percakapan.
    ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
    _startPresenceHeartbeat();

    // Timer periodik pembersihan pesan kedaluwarsa (client guard)
    _purgeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      try {
        ref.read(chatRepositoryProvider).purgeExpiredMessages();
      } catch (_) {}
    });

    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);
      
      // Muat preferensi pesan menghilang level room (tersinkronisasi untuk kedua pihak)
      final roomAutoDelete = await repo.getRoomDisappearingHours(widget.chatId);
      
      // Muat preferensi Burn on Exit level room
      final roomBurnOnExit = await repo.getRoomBurnOnExit(widget.chatId);
      
      // Muat preferensi Pembersihan Terjadwal level room
      String loadedWipeMode = 'off';
      TimeOfDay? loadedWipeTime;
      DateTime? loadedWipeTarget;
      try {
        final wipeData = await repo.getRoomScheduledWipe(widget.chatId);
        if (wipeData != null) {
          loadedWipeMode = wipeData['scheduled_wipe_mode'] as String? ?? 'off';
          final timeStr = wipeData['scheduled_wipe_time'] as String?;
          final targetStr = wipeData['scheduled_wipe_target_at'] as String?;
          if (timeStr != null && timeStr.contains(':')) {
            final parts = timeStr.split(':');
            if (parts.length >= 2) {
              loadedWipeTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 14,
                minute: int.tryParse(parts[1]) ?? 0,
              );
            }
          }
          loadedWipeTarget = targetStr != null ? DateTime.tryParse(targetStr) : null;
        }
      } catch (_) {}

      // Muat preferensi Sekali Lihat (View Once) per-room dari SharedPreferences
      bool savedViewOnce = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        savedViewOnce = prefs.getBool('room_view_once_${widget.chatId}') ?? false;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _autoDeleteHours = roomAutoDelete;
        _burnOnExit = roomBurnOnExit;
        _scheduledWipeMode = loadedWipeMode;
        _scheduledWipeTime = loadedWipeTime;
        _scheduledWipeTargetAt = loadedWipeTarget;
        _isViewOnce = savedViewOnce;
      });

      // Jadwalkan pembersihan terjadwal secara presisi (tanpa polling baterai)
      _scheduleWipeTimer();

      // Best-effort purge pesan kedaluwarsa saat pertama buka chat
      try {
        await repo.purgeExpiredMessages();
      } catch (_) {}
      _otherLastRead = await repo.getOtherParticipantLastRead(widget.chatId);
      if (widget.otherUserId != null) {
        _otherLastSeenNotifier.value = await repo.getLastSeen(widget.otherUserId!);
      }
      if (widget.isGroup) {
        _loadGroupParticipants();
      }
      repo.updateLastSeen();
    });
  }

  void _onTextChanged() {
    final isTyping = _textController.text.isNotEmpty;
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(isTyping);
  }

  /// Format presence subtitle: online (< 2 min) > last seen (formatted) > hidden privacy
  String _formatPresenceSubtitle(DateTime? otherLastSeen) {
    // Jika null: pengguna menyembunyikan "terakhir dilihat" (enforce di server via RPC get_last_seen_for)
    if (otherLastSeen == null) return 'Terakhir dilihat baru-baru ini';

    final now = DateTime.now();
    final lastSeen = otherLastSeen.toLocal();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 2) {
      return 'Online';
    }

    final isSameDay = now.year == lastSeen.year &&
        now.month == lastSeen.month &&
        now.day == lastSeen.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == lastSeen.year &&
        yesterday.month == lastSeen.month &&
        yesterday.day == lastSeen.day;

    final hourStr = lastSeen.hour.toString().padLeft(2, '0');
    final minuteStr = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr';

    if (isSameDay) {
      return 'Terakhir dilihat hari ini pukul $timeStr';
    } else if (isYesterday) {
      return 'Terakhir dilihat kemarin pukul $timeStr';
    } else if (now.year == lastSeen.year) {
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      final monthName = monthNames[lastSeen.month - 1];
      return 'Terakhir dilihat ${lastSeen.day} $monthName pukul $timeStr';
    } else {
      final dayStr = lastSeen.day.toString().padLeft(2, '0');
      final monthStr = lastSeen.month.toString().padLeft(2, '0');
      return 'Terakhir dilihat $dayStr/$monthStr/${lastSeen.year}';
    }
  }

  bool _isCurrentlyOnline(DateTime? otherLastSeen) {
    if (otherLastSeen == null) return false;
    return DateTime.now().difference(otherLastSeen).inMinutes < 2;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceHeartbeatTimer?.cancel();
    _purgeTimer?.cancel();
    _scheduledWipeTimer?.cancel();
    if (_burnOnExit) {
      _triggerBurnOnExit();
    }
    // Hentikan live location sharing jika masih aktif saat meninggalkan room
    ref.read(chatActionsProvider).stopLiveLocationShare();
    // Bersihkan penanda room aktif agar notif pesan kembali aktif
    // saat user meninggalkan percakapan ini.
    if (ref.read(activeRoomIdProvider) == widget.chatId) {
      ref.read(activeRoomIdProvider.notifier).state = null;
    }
    _otherLastSeenNotifier.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _showScrollButton.dispose();
    _newMessageCount.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) && _burnOnExit) {
      _triggerBurnOnExit();
    }
  }

  Future<void> _triggerBurnOnExit() async {
    if (_burnTriggered || !_burnOnExit) return;
    _burnTriggered = true;
    try {
      await ref.read(chatRepositoryProvider).executeRoomBurnOnExit(widget.chatId);
      if (mounted) {
        ref.invalidate(chatMessagesProvider(widget.chatId));
      }
    } catch (_) {}
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Tactile Feedback 0ms: Pemicuan getaran ringan instan saat tombol diketuk
    HapticService.trigger(MekaarHapticIntent.selection);

    final actions = ref.read(chatActionsProvider);

    // ── Mode 1: Edit Pesan ──
    if (_editingMessage != null) {
      final msgToEdit = _editingMessage!;
      if (!actions.canEdit(msgToEdit, isGuardianRoom: widget.isGuardian)) {
        _textController.clear();
        setState(() => _editingMessage = null);
        return;
      }

      final originalText = text;
      final originalMsg = msgToEdit;

      _textController.clear();
      setState(() => _editingMessage = null);
      ref.read(typingStateProvider(widget.chatId).notifier).setTyping(false);

      try {
        await actions.editMessage(
          msgToEdit.id,
          text,
          isGuardianRoom: widget.isGuardian,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _textController.text = originalText;
            _editingMessage = originalMsg;
          });
          MekaarSnackbar.error(
            context,
            'Gagal menyimpan pesan: ${ErrorResolver.resolve(e)}',
          );
        }
      }
      return;
    }

    // ── Mode 2: Kirim Pesan Baru (Optimistic Input Clearing) ──
    final textToSend = text;
    final replyToMessage = _replyMessage;
    final isViewOnceToSend = _isViewOnce;

    // Pengosongan Input Bar & Reset State UI Secara Instan (0ms Delay bagi Pengguna)
    _textController.clear();
    setState(() {
      _replyMessage = null;
    });
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(false);
    _scrollToBottom();

    try {
      await actions.sendMessage(
        widget.chatId,
        textToSend,
        type: MessageType.text,
        isViewOnce: isViewOnceToSend,
        replyToId: replyToMessage?.id,
        autoDeleteHours: _autoDeleteHours,
        scheduledWipeTargetAt: _scheduledWipeTargetAt,
      );
    } catch (e) {
      // Fail-Safe Restoration: Kembalikan teks dan state bila pengiriman jaringan gagal
      if (mounted) {
        setState(() {
          _textController.text = textToSend;
          _replyMessage = replyToMessage;
          _isViewOnce = isViewOnceToSend;
        });
        MekaarSnackbar.error(
          context,
          'Gagal mengirim pesan: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  Future<void> _handleSendMedia(File file, MessageType type) async {
    String? uploadedUrl;
    final uploader = MediaUploadService(Supabase.instance.client);

    try {
      String? fileKeyB64;
      String url;

      // Check whether room supports E2EE (peer key exists) without wasteful dummy encryption
      final peerKey = widget.otherUserId != null 
          ? await E2eeService.instance.getPeerPublicKey(widget.otherUserId!)
          : null;
      if (peerKey != null && peerKey.isNotEmpty) {
        // Kamar chat mendukung E2EE, enkripsi & unggah media
        final result = await uploader.uploadEncryptedChatMedia(file, widget.chatId);
        url = result.url;
        fileKeyB64 = result.keyB64;
      } else {
        // Fallback: unggah biasa
        url = await uploader.uploadChatMedia(file, widget.chatId);
      }

      uploadedUrl = url;
      final isViewOnceToSend = _isViewOnce;

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            fileKeyB64 ?? '',
            mediaUrl: url,
            type: type,
            isViewOnce: isViewOnceToSend,
            autoDeleteHours: _autoDeleteHours,
            scheduledWipeTargetAt: _scheduledWipeTargetAt,
          );
      _scrollToBottom();
    } catch (e) {
      // Cleanup uploaded media if message creation fails
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        try {
          await uploader.deleteMediaByUrl(uploadedUrl);
        } catch (_) {}
      }
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal mengirim media: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  Future<void> _handleSendLocation() async {
    final location = loc.Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) return;
      }

      final locationData = await location.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;
      if (lat == null || lng == null) return;

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            '$lat, $lng',
            type: MessageType.location,
            autoDeleteHours: _autoDeleteHours,
            scheduledWipeTargetAt: _scheduledWipeTargetAt,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal mendapatkan lokasi: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  Future<void> _handleShareLiveLocation(int durationMinutes) async {
    try {
      await ref
          .read(chatActionsProvider)
          .shareLiveLocation(widget.chatId, durationMinutes);
      if (mounted) {
        MekaarSnackbar.success(context, 'Lokasi live dibagikan selama $durationMinutes menit');
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal membagikan lokasi live: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  void _handleDeleteMessage(Message msg) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus untuk Saya?',
      message: 'Pesan akan disembunyikan untuk Anda saja. Lawan bicara tetap dapat melihat pesan ini.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(chatActionsProvider).hideMessageForMe(msg.id, roomId: widget.chatId);
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text(
            'Hapus',
            style: TextStyle(color: MekaarColors.textSecondary),
          ),
        ),
      ],
    );
  }

  void _handleUnsendMessage(Message msg) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Tarik Pesan?',
      message: widget.isGuardian
          ? 'Konten pesan akan hilang dari layar. Log sistem tetap mencatat snapshot penghapusan demi integritas bukti.'
          : 'Pesan akan dihapus untuk semua orang. Jika belum dibaca, pesan ini akan ditarik tanpa jejak.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(chatActionsProvider).deleteMessageForEveryone(msg.id);
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text(
            'Tarik Pesan',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _handleReactToMessage(Message msg, String emoji) {
    ref.read(chatActionsProvider).reactToMessage(msg.id, emoji);
  }

  void _handleForwardMessage(Message msg) {
    final rooms = ref.read(chatRoomsProvider).value ?? [];
    final targets = rooms.where((r) => r['id'] != widget.chatId).toList();

    final hasTargets = targets.isNotEmpty;

    MekaarBottomSheet.show(
      context: context,
      title: 'Teruskan ke',
      builder: (ctx) => hasTargets
          ? ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: targets.map((room) {
                final name = room['name'] as String? ?? 'User';
                final avatar = room['avatar'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Text(
                      avatar.isNotEmpty ? avatar : name[0],
                      style: const TextStyle(color: MekaarColors.textPrimary),
                    ),
                  ),
                  title: Text(name),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref
                          .read(chatActionsProvider)
                          .forwardMessage(msg, room['id'] as String);
                    } catch (e) {
                      if (ctx.mounted) {
                        MekaarSnackbar.error(
                          ctx,
                          'Gagal meneruskan pesan: ${ErrorResolver.resolve(e)}',
                        );
                      }
                      return;
                    }
                    if (ctx.mounted) {
                      MekaarSnackbar.success(ctx, 'Pesan diteruskan ke $name');
                    }
                  },
                );
              }).toList(),
            )
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada chat lain untuk meneruskan pesan.',
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  void _toggleViewOnce() async {
    final newValue = !_isViewOnce;
    setState(() => _isViewOnce = newValue);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('room_view_once_${widget.chatId}', newValue);
    } catch (_) {}
    if (!mounted) return;
    MekaarSnackbar.info(
      context,
      newValue
          ? 'Mode Sekali Lihat Aktif (Media akan hilang setelah dibuka).'
          : 'Mode Sekali Lihat Dinonaktifkan.',
    );
  }

  void _setAutoDeleteHours(int hours) {
    setState(() => _autoDeleteHours = hours);
  }

  String _autoDeleteLabel() {
    if (_autoDeleteHours <= 0) return 'Mati';
    if (_autoDeleteHours == 1) return '1 Jam';
    if (_autoDeleteHours == 24) return '1 Hari';
    if (_autoDeleteHours == 168) return '7 Hari';
    return '$_autoDeleteHours Jam';
  }

  Future<void> _showAutoDeleteMenu() async {
    final choice = await MekaarBottomSheet.show<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final options = [
          (0, 'Mati', 'Pesan disimpan selamanya'),
          (1, '1 Jam', 'Pesan otomatis terhapus setelah 1 jam'),
          (24, '1 Hari', 'Pesan otomatis terhapus setelah 1 hari'),
          (168, '7 Hari', 'Pesan otomatis terhapus setelah 7 hari'),
        ];
        return MekaarBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pesan Menghilang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final selected = opt.$1 == _autoDeleteHours;
                return ListTile(
                  leading: Icon(
                    selected ? SolarIconsBold.history : SolarIconsOutline.history,
                    color: selected ? AppColors.blue : null,
                  ),
                  title: Text(opt.$2),
                  subtitle: Text(opt.$3),
                  trailing: selected
                      ? const Icon(MekaarIcons.check, color: AppColors.blue)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt.$1),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (choice != null) {
      final previousHours = _autoDeleteHours;
      _setAutoDeleteHours(choice);
      try {
        await ref
            .read(chatRepositoryProvider)
            .updateRoomDisappearingHours(widget.chatId, choice);
      } catch (e) {
        // Rollback tampilan optimis -- jangan biarkan UI menunjukkan
        // pilihan baru seolah tersimpan padahal RPC gagal (ini persis
        // pola yang sebelumnya membuat pengaturan tampak "hilang"/
        // "terkunci" tanpa disadari, lihat migrations/40_fix_room_
        // participant_rpcs_search_path.sql untuk akar masalahnya).
        if (mounted) {
          _setAutoDeleteHours(previousHours);
          MekaarSnackbar.error(
            context,
            'Gagal menyimpan pengaturan pesan menghilang: $e',
          );
        }
      }
    }
  }

  String _scheduledWipeLabel() {
    if (_scheduledWipeMode == 'off' || _scheduledWipeTime == null) return 'Mati';
    final hour = _scheduledWipeTime!.hour.toString().padLeft(2, '0');
    final minute = _scheduledWipeTime!.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    if (_scheduledWipeMode == 'daily') return '$timeStr (Harian)';
    return '$timeStr (1x)';
  }

  void _scheduleWipeTimer() {
    _scheduledWipeTimer?.cancel();
    if (_scheduledWipeMode == 'off' || _scheduledWipeTargetAt == null) return;

    final now = DateTime.now().toUtc();
    final diff = _scheduledWipeTargetAt!.difference(now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      _triggerLocalScheduledWipe();
      return;
    }

    _scheduledWipeTimer = Timer(diff, () {
      _triggerLocalScheduledWipe();
      if (_scheduledWipeMode == 'daily' && mounted) {
        setState(() {
          _scheduledWipeTargetAt =
              _scheduledWipeTargetAt!.add(const Duration(days: 1));
        });
        _scheduleWipeTimer();
      }
    });
  }

  Future<void> _triggerLocalScheduledWipe() async {
    try {
      await ref.read(chatRepositoryProvider).executeRoomScheduledWipe(widget.chatId);
      if (mounted) {
        ref.invalidate(chatMessagesProvider(widget.chatId));
        if (_scheduledWipeMode == 'one_shot') {
          setState(() {
            _scheduledWipeMode = 'off';
            _scheduledWipeTime = null;
            _scheduledWipeTargetAt = null;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _showScheduledWipeMenu() async {
    final result = await ScheduledWipeBottomSheet.show(
      context: context,
      initialMode: _scheduledWipeMode,
      initialTime: _scheduledWipeTime,
      initialTargetAt: _scheduledWipeTargetAt,
    );

    if (result != null) {
      final prevMode = _scheduledWipeMode;
      final prevTime = _scheduledWipeTime;
      final prevTarget = _scheduledWipeTargetAt;

      String? timeStr;
      if (result.time != null) {
        final h = result.time!.hour.toString().padLeft(2, '0');
        final m = result.time!.minute.toString().padLeft(2, '0');
        timeStr = '$h:$m:00';
      }

      setState(() {
        _scheduledWipeMode = result.mode;
        _scheduledWipeTime = result.time;
        _scheduledWipeTargetAt = result.targetAtUtc;
      });

      _scheduleWipeTimer();

      try {
        await ref.read(chatRepositoryProvider).setRoomScheduledWipe(
          roomId: widget.chatId,
          mode: result.mode,
          timeString: timeStr,
          targetAtUtc: result.targetAtUtc,
        );
        if (mounted) {
          MekaarSnackbar.success(
            context,
            result.mode == 'off'
                ? 'Pembersihan terjadwal dinonaktifkan'
                : 'Pembersihan terjadwal aktif pada pukul ${_scheduledWipeLabel()}',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _scheduledWipeMode = prevMode;
            _scheduledWipeTime = prevTime;
            _scheduledWipeTargetAt = prevTarget;
          });
          _scheduleWipeTimer();
          MekaarSnackbar.error(
            context,
            'Gagal menyimpan pembersihan terjadwal: $e',
          );
        }
      }
    }
  }

  Future<void> _toggleBurnOnExit() async {
    if (!_burnOnExit) {
      // Konfirmasi eksplisit sebelum aktivasi untuk mencegah penghapusan yang tidak disengaja
      final confirmed = await MekaarDialog.showConfirmation<bool>(
        context: context,
        title: 'Aktifkan Hapus Saat Keluar?',
        message:
            'Seluruh riwayat pesan (kirim & terima) dalam ruangan ini akan otomatis terhapus seketika saat Anda meninggalkan layar obrolan.\n\nApakah Anda yakin ingin mengaktifkannya?',
        isDestructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aktifkan'),
          ),
        ],
      );
      if (confirmed != true) return;
    }

    final newValue = !_burnOnExit;
    final prevValue = _burnOnExit;
    setState(() => _burnOnExit = newValue);

    try {
      await ref.read(chatRepositoryProvider).setRoomBurnOnExit(widget.chatId, newValue);
      if (mounted) {
        MekaarSnackbar.success(
          context,
          newValue
              ? 'Hapus Saat Keluar Aktif: Pesan otomatis terhapus saat Anda keluar.'
              : 'Hapus Saat Keluar Dinonaktifkan.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _burnOnExit = prevValue);
        MekaarSnackbar.error(
          context,
          'Gagal menyimpan setelan Hapus Saat Keluar: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  void _initiateCall(String callType) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null || widget.otherUserId == null) {
      MekaarSnackbar.error(context, 'Panggilan tidak tersedia untuk obrolan ini.');
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.call,
      arguments: {
        'roomId': widget.chatId,
        'chatName': widget.chatName,
        'callerId': currentUserId,
        'receiverId': widget.otherUserId!,
        'isCaller': true,
        'callType': callType,
      },
    );
  }

  void _confirmClearHistory() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Bersihkan Riwayat?',
      message: widget.isGuardian
          ? 'Seluruh riwayat chat akan dibersihkan dari tampilan Anda, namun log percakapan tetap diarsipkan demi kepatuhan Room Guardian.'
          : 'Seluruh riwayat chat di ruangan ini akan dibersihkan untuk Anda.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await ref.read(chatActionsProvider).clearChatHistory(widget.chatId);
            if (!mounted) return;
            MekaarSnackbar.success(context, 'Riwayat obrolan dibersihkan.');
          },
          child: const Text(
            'Bersihkan',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteChat() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Chat?',
      message:
          'Apakah Anda yakin ingin menghapus seluruh obrolan ini? Obrolan akan hilang dari daftar chat Anda.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await ref.read(chatActionsProvider).deleteChat(widget.chatId);
            if (!mounted) return;
            Navigator.pop(context); // Exit chat room to ChatListScreen
          },
          child: const Text(
            'Hapus',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readReceiptsEnabled = ref.watch(
      authProvider.select((a) => a.profile?.readReceiptsEnabled),
    ) ?? true;
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);

    final topAreaHeight = MediaQuery.of(context).padding.top + kToolbarHeight + 16.0;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _burnOnExit) {
          _triggerBurnOnExit();
        }
      },
      child: MekaarScaffold(
        flat: false,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // ── Layer 0: Wallpaper/Background (Scoped Consumer) ──
            Consumer(
              builder: (context, ref, _) {
                final chatPref = ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
                return _buildWallpaperBackground(chatPref);
              },
            ),

            // ── Layer 1: Daftar Pesan (Scoped Consumer) ──
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, _) {
                  final chatPref = ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
                  final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(chatPref, context);
                  final e2eeStatus = ref.watch(e2eeRoomStatusProvider(widget.chatId));
                  final messagesStream = ref.watch(chatMessagesProvider(widget.chatId));
                  final reconnecting =
                      ref.watch(chatReconnectingProvider(widget.chatId)).value ??
                          false;
                  final protectionAsync = ref.watch(roomScreenProtectionProvider(widget.chatId));
                  final protection = protectionAsync.valueOrNull;
                  final forwardingProtectionAsync = ref.watch(roomForwardingProtectionProvider(widget.chatId));
                  final forwardingProtection = forwardingProtectionAsync.valueOrNull;

                  return Column(
                    children: [
                      // Banner E2EE & proteksi harus di bawah header floating agar
                      // tidak tertimpa atau terlalu ke atas
                      SizedBox(height: topAreaHeight),
                      E2eePreparationBanner(status: e2eeStatus),
                      if (protection?.effective ?? true)
                        ScreenProtectionStatusBadge(
                          label: protection?.statusLabel ?? 'Proteksi ruang aktif',
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            // Stale-while-revalidate: selama masih ada data
                            // termuat, jangan collapse ke error view — tampilkan
                            // badge tipis non-blocking saat menyambung ulang.
                            if (messagesStream.hasValue && reconnecting)
                              const ReconnectingBadge(),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  switch (chatMessagesUiMode(messagesStream)) {
                                    case ChatMessagesUiMode.data:
                                      final messages = messagesStream.valueOrNull!;
                                      if (messages.isEmpty) {
                                        return const MekaarStateView(
                                          pose: MikaPose.sleep,
                                          title: 'Belum Ada Pesan',
                                          message:
                                              'Belum ada pesan. Kirim pesan pertama!',
                                        );
                                      }

                                      final reversed = messages.reversed.toList();
                                      final itemEntries = _buildItemEntries(
                                        reversed,
                                      );
                                      final messageMap = {
                                        for (var m in messages) m.id: m,
                                      };

                                      return ListView.builder(
                                        controller: _scrollController,
                                        reverse: true,
                                        // Padding bawah memberi ruang untuk composer floating + inset keyboard
                                        padding: EdgeInsets.only(
                                          top: 8,
                                          bottom: 130 + keyboardHeight,
                                        ),
                                        itemCount: itemEntries.length,
                                        itemBuilder: (context, index) {
                                          return _buildLazyMessageItem(
                                            itemEntries[index],
                                            currentUserId,
                                            actions,
                                            messageMap,
                                            forwardingProtection:
                                                forwardingProtection,
                                            roomThemeSpec: roomThemeSpec,
                                            showReadReceipts:
                                                readReceiptsEnabled,
                                          );
                                        },
                                      );
                                    case ChatMessagesUiMode.error:
                                      return MekaarStateView(
                                        pose: MikaPose.huft,
                                        title: 'Gagal Memuat',
                                        message: ErrorResolver.resolve(
                                          messagesStream.error,
                                        ),
                                        actionLabel: 'Coba Lagi',
                                        onAction: () => ref.invalidate(
                                          chatMessagesProvider(widget.chatId),
                                        ),
                                        icon: SolarIconsOutline.refresh,
                                      );
                                    case ChatMessagesUiMode.loading:
                                      return const MekaarStateView(
                                        pose: MikaPose.neutral,
                                        title: 'Memuat',
                                        message: 'Memuat pesan...',
                                      );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final isTyping = ref.watch(typingStateProvider(widget.chatId));
                          if (!isTyping) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(bottom: 84 + keyboardHeight),
                            child: const TypingIndicator(dotColor: AppColors.blue),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Layer 2: Composer Floating (Scoped Consumer) ──
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: Consumer(
                builder: (context, ref, _) {
                  final chatPref = ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
                  final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(chatPref, context);
                  final e2eeStatus = ref.watch(e2eeRoomStatusProvider(widget.chatId));
                  final isE2eeReady = e2eeStatus == E2eeRoomStatus.ready;

                  return ChatComposer(
                    controller: _textController,
                    replyMessage: _replyMessage,
                    editingMessage: _editingMessage,
                    enabled: isE2eeReady,
                    roomThemeSpec: roomThemeSpec,
                    onSend: _handleSend,
                    onCancelReply: () => setState(() => _replyMessage = null),
                    onCancelEdit: () {
                      setState(() => _editingMessage = null);
                      _textController.clear();
                    },
                    onSendMedia: _handleSendMedia,
                    onSendLocation: _handleSendLocation,
                    onShareLiveLocation: _handleShareLiveLocation,
                  );
                },
              ),
            ),

            // ── Layer 5: Scroll-to-bottom button (ValueListenableBuilder) ──
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 120,
              child: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    final chatPref = ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
                    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(chatPref, context);

                    return ValueListenableBuilder<bool>(
                      valueListenable: _showScrollButton,
                      builder: (context, showButton, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _newMessageCount,
                          builder: (context, newCount, _) {
                            return ScrollToBottomButton(
                              visible: showButton,
                              newMessageCount: newCount,
                              accentColor: roomThemeSpec.primaryAccentColor,
                              iconColor: roomThemeSpec.iconColor,
                              onTap: () {
                                _scrollToBottom();
                                _newMessageCount.value = 0;
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // ── Layer 4: Custom App Bar Floating Frosted Glass ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, _) {
                  final chatPref = ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
                  final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(chatPref, context);
                  final isTyping = ref.watch(typingStateProvider(widget.chatId));
                  final protection = ref.watch(roomScreenProtectionProvider(widget.chatId)).valueOrNull;
                  final forwardingProtection = ref.watch(roomForwardingProtectionProvider(widget.chatId)).valueOrNull;

                  final isScreenProtOn = protection?.callerEnabled ?? true;
                  final isFwdProtOn = forwardingProtection?.callerEnabled ?? false;
                  final isAutoDelOn = _autoDeleteHours > 0;
                  final isViewOnceOn = _isViewOnce;

                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final frostedBg = isDark
                      ? const Color(0xF2181D2E)
                      : const Color(0xF6FFFFFF);
                  final frostedBorder = isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.10);
                  final textPrimary = MekaarColors.textPrimaryOf(context);

                  return ValueListenableBuilder<DateTime?>(
                    valueListenable: _otherLastSeenNotifier,
                    builder: (context, lastSeen, _) {
                      final isOnline = _isCurrentlyOnline(lastSeen);
                      return CustomAppBar(
                        isFloating: true,
                        title: widget.chatName,
                        avatarInitial: widget.chatAvatar,
                        avatarUrl: widget.chatAvatarUrl,
                        isGuardian: widget.isGuardian,
                        showOnlineIndicator: true,
                        isOnline: isOnline || isTyping,
                        subtitle: isTyping
                            ? 'sedang mengetik...'
                            : _formatPresenceSubtitle(lastSeen),
                        glassBorder: roomThemeSpec.glassBorder,
                        glassBackgroundColor:
                            roomThemeSpec.glassBackgroundColor,
                        iconColor: roomThemeSpec.iconColor,
                        textColor: roomThemeSpec.textColor,
                        subtitleColor: roomThemeSpec.subtitleColor,
                        onAvatarTap: widget.isGroup
                            ? () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.groupDetails,
                                  arguments: {
                                    'roomId': widget.chatId,
                                    'groupName': widget.chatName,
                                    'groupAvatarUrl': widget.chatAvatarUrl,
                                  },
                                )
                            : (widget.otherUserId != null
                                ? () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.contactSettings,
                                      arguments: {
                                        'roomId': widget.chatId,
                                        'chatName': widget.chatName,
                                        'chatAvatar': widget.chatAvatar,
                                        'otherUserId': widget.otherUserId!,
                                        'isGuardian': widget.isGuardian,
                                      },
                                    )
                                : null),
                        actions: [
                          // Actions Popup Menu (High-Contrast Frosted Glass)
                          PopupMenuButton<String>(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MekaarRadius.md),
                              side: BorderSide(
                                color: frostedBorder,
                                width: 1,
                              ),
                            ),
                            color: frostedBg,
                            surfaceTintColor: Colors.transparent,
                            elevation: 10,
                            shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                            padding: EdgeInsets.zero,
                            icon: RotatedBox(
                              quarterTurns: 1,
                              child: Icon(
                                SolarIconsOutline.menuDots,
                                color: roomThemeSpec.primaryAccentColor,
                              ),
                            ),
                        onSelected: (value) async {
                          if (value == 'voice') {
                            _initiateCall('voice');
                          } else if (value == 'video') {
                            _initiateCall('video');
                          } else if (value == 'sync_e2ee_keys') {
                            E2eeService.instance.invalidateRoomKey(widget.chatId);
                            ref.invalidate(chatMessagesProvider(widget.chatId));
                            HapticService.trigger(MekaarHapticIntent.success);
                            MekaarSnackbar.success(
                              context,
                              'Kunci enkripsi ruangan berhasil disinkronkan ulang.',
                            );
                          } else if (value == 'screen_protection') {
                            try {
                              await ref
                                  .read(screenProtectionControllerProvider)
                                  .setRoomPreference(widget.chatId, !isScreenProtOn);
                            } catch (_) {}
                          } else if (value == 'forwarding_protection') {
                            try {
                              await ref
                                  .read(forwardingProtectionControllerProvider)
                                  .setRoomPreference(widget.chatId, !isFwdProtOn);
                            } catch (_) {}
                          } else if (value == 'auto_delete') {
                            _showAutoDeleteMenu();
                          } else if (value == 'scheduled_wipe') {
                            _showScheduledWipeMenu();
                          } else if (value == 'burn_on_exit') {
                            _toggleBurnOnExit();
                          } else if (value == 'view_once') {
                            _toggleViewOnce();
                          } else if (value == 'theme') {
                            Navigator.pushNamed(context, AppRoutes.chatThemeSettings);
                          } else if (value == 'clear') {
                            _confirmClearHistory();
                          } else if (value == 'delete') {
                            _confirmDeleteChat();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'voice',
                            child: Row(
                              children: [
                                Icon(
                                  SolarIconsOutline.phone,
                                  size: 20,
                                  color: textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Panggilan Suara',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'video',
                            child: Row(
                              children: [
                                Icon(
                                  SolarIconsOutline.videocamera,
                                  size: 20,
                                  color: textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Panggilan Video',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'sync_e2ee_keys',
                            child: Row(
                              children: [
                                const Icon(
                                  SolarIconsOutline.refreshSquare,
                                  size: 20,
                                  color: AppColors.blue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sinkronkan Kunci Enkripsi',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'theme',
                            child: Row(
                              children: [
                                Icon(
                                  SolarIconsOutline.palette,
                                  size: 20,
                                  color: textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tema & Wallpaper Chat',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          // ── Kontrol Privasi Room ──
                          PopupMenuItem<String>(
                            value: 'screen_protection',
                            child: Row(
                              children: [
                                Icon(
                                  isScreenProtOn
                                      ? SolarIconsBold.shieldCheck
                                      : SolarIconsOutline.shieldCross,
                                  size: 20,
                                  color: isScreenProtOn
                                      ? MekaarColors.accentOf(context)
                                      : MekaarColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Proteksi Layar: ${isScreenProtOn ? "Aktif" : "Mati"}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'forwarding_protection',
                            child: Row(
                              children: [
                                Icon(
                                  isFwdProtOn
                                      ? SolarIconsBold.forbiddenCircle
                                      : SolarIconsOutline.forward,
                                  size: 20,
                                  color: isFwdProtOn
                                      ? MekaarColors.accentOf(context)
                                      : MekaarColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Larang Teruskan: ${isFwdProtOn ? "Aktif" : "Mati"}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'auto_delete',
                            child: Row(
                              children: [
                                Icon(
                                  isAutoDelOn
                                      ? SolarIconsBold.history
                                      : SolarIconsOutline.history,
                                  size: 20,
                                  color: isAutoDelOn
                                      ? MekaarColors.accentOf(context)
                                      : MekaarColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pesan Menghilang: ${_autoDeleteLabel()}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'scheduled_wipe',
                            child: Row(
                              children: [
                                Icon(
                                  _scheduledWipeMode != 'off'
                                      ? SolarIconsBold.clockCircle
                                      : SolarIconsOutline.clockCircle,
                                  size: 20,
                                  color: _scheduledWipeMode != 'off'
                                      ? MekaarColors.accentOf(context)
                                      : MekaarColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pembersihan Terjadwal: ${_scheduledWipeLabel()}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'burn_on_exit',
                            child: Row(
                              children: [
                                Icon(
                                  _burnOnExit
                                      ? SolarIconsBold.fire
                                      : SolarIconsOutline.fire,
                                  size: 20,
                                  color: _burnOnExit
                                      ? MekaarColors.accentOf(context)
                                      : MekaarColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hapus Saat Keluar: ${_burnOnExit ? "Aktif" : "Mati"}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'view_once',
                            child: Row(
                              children: [
                                Icon(
                                  isViewOnceOn
                                      ? SolarIconsBold.eyeClosed
                                      : SolarIconsOutline.eyeClosed,
                                  size: 20,
                                  color: isViewOnceOn
                                      ? MekaarColors.accentOf(context)
                                      : MekaarColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mode Sekali Lihat: ${isViewOnceOn ? "Aktif" : "Mati"}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<String>(
                            value: 'clear',
                            child: Row(
                              children: [
                                Icon(
                                  SolarIconsOutline.eraser,
                                  size: 20,
                                  color: MekaarColors.warning,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bersihkan Obrolan',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  SolarIconsOutline.trashBinTrash,
                                  size: 20,
                                  color: MekaarColors.sosRed,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hapus Chat',
                                  style: TextStyle(
                                    color: MekaarColors.sosRed,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  ),
);
}


  /// Buat daftar data entri secara cepat (O(N) data pointer tanpa alokasi widget eager).
  List<_ChatItemEntry> _buildItemEntries(List<Message> reversedMessages) {
    final entries = <_ChatItemEntry>[];
    DateTime? lastDate;

    for (var i = 0; i < reversedMessages.length; i++) {
      final msg = reversedMessages[i];
      final localCreatedAt = msg.createdAt.toLocal();
      final msgDate = DateTime(
        localCreatedAt.year,
        localCreatedAt.month,
        localCreatedAt.day,
      );

      // Sisipkan pemisah tanggal jika hari berubah
      if (lastDate == null || msgDate != lastDate) {
        entries.add(_ChatItemEntry.dateSeparator(localCreatedAt));
        lastDate = msgDate;
      }

      entries.add(_ChatItemEntry.message(msg));
    }
    return entries;
  }

  /// Bangun widget pesan individual secara lazy pada index viewport yang sedang aktif.
  Widget _buildLazyMessageItem(
    _ChatItemEntry entry,
    String? currentUserId,
    ChatActionsNotifier actions,
    Map<String, Message> messageMap, {
    RoomForwardingProtection? forwardingProtection,
    ChatRoomThemeSpec? roomThemeSpec,
    bool showReadReceipts = true,
  }) {
    if (entry.kind == _ChatItemKind.dateSeparator) {
      return ChatDateSeparator(
        date: entry.date!,
        accentColor: roomThemeSpec?.secondaryAccentColor,
        textColor: roomThemeSpec?.textColor,
      );
    }

    final msg = entry.message!;
    final isMe = msg.senderId == currentUserId;
    final canEdit = actions.canEdit(
      msg,
      isGuardianRoom: widget.isGuardian,
    );

    Message? replyToMsg;
    String? replyToSender;
    if (msg.replyToId != null) {
      replyToMsg = messageMap[msg.replyToId];
      if (replyToMsg != null) {
        if (replyToMsg.senderId == currentUserId) {
          replyToSender = 'Anda';
        } else {
          replyToSender = _participantNames[replyToMsg.senderId] ?? 'Pengirim';
        }
      }
    }

    final bubble = ChatBubble(
      message: msg,
      isMe: isMe,
      canDelete: true, // Semua pesan bisa dihapus secara lokal (hide for me)
      canUnsend: isMe, // Hanya pengirim yang bisa tarik pesan (delete for everyone)
      canEdit: isMe && canEdit,
      canForward: actions.canForward(
        msg,
        forwardingProtectionActive:
            forwardingProtection?.effective ?? false,
      ),
      otherLastReadAt: _otherLastRead,
      showReadReceipts: showReadReceipts,
      senderName: widget.isGroup ? _participantNames[msg.senderId] : null,
      replyToMessage: replyToMsg,
      replyToSenderName: replyToSender,
      onDelete: () => _handleDeleteMessage(msg),
      onUnsend: () => _handleUnsendMessage(msg),
      onReply: (replyMsg) {
        setState(() {
          _replyMessage = replyMsg;
          _editingMessage = null;
        });
      },
      onEdit: (editMsg, newContent) {
        if (!actions.canEdit(
          editMsg,
          isGuardianRoom: widget.isGuardian,
        )) {
          return;
        }
        ref
            .read(chatActionsProvider)
            .editMessage(
              editMsg.id,
              newContent,
              isGuardianRoom: widget.isGuardian,
            );
      },
      onForward: (forwardingProtection?.effective ?? false)
          ? null
          : (forwardMsg) => _handleForwardMessage(forwardMsg),
      onReact: (reactMsg, emoji) =>
          _handleReactToMessage(reactMsg, emoji),
    );

    // Bungkus dengan RepaintBoundary untuk isolasi repaint dan SwipeToReply
    return RepaintBoundary(
      key: ValueKey('bubble_${msg.id}'),
      child: _SwipeToReplyWrapper(
        onReply: () => setState(() {
          _replyMessage = msg;
          _editingMessage = null;
        }),
        child: bubble,
      ),
    );
  }

  Widget _buildWallpaperBackground(ChatThemePreference pref) {
    return ChatPresetResolver.buildWallpaper(pref, context);
  }
}

/// Gesture wrapper untuk swipe-to-reply pada bubble chat berbasis GestureDetector + Transform.
/// Geser bubble ke kanan untuk memicu balasan dengan pegas kembali halus dan getaran haptic.
class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReply,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recoilController;
  double _dragOffset = 0.0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _recoilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _recoilController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    if (delta > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, 72.0);
        if (_dragOffset >= 48.0 && !_thresholdReached) {
          _thresholdReached = true;
          HapticService.trigger(MekaarHapticIntent.selection);
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      widget.onReply();
    }
    _thresholdReached = false;

    if (_dragOffset > 0) {
      final startOffset = _dragOffset;
      final anim = Tween<double>(begin: startOffset, end: 0.0).animate(
        CurvedAnimation(parent: _recoilController, curve: Curves.easeOutCubic),
      );
      anim.addListener(() {
        setState(() {
          _dragOffset = anim.value;
        });
      });
      _recoilController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dragOffset > 6)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Opacity(
                opacity: (_dragOffset / 48.0).clamp(0.0, 1.0),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MekaarColors.guardianTeal.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.reply,
                      color: MekaarColors.guardianTeal,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Mode tampilan daftar pesan (murni, bisa diuji unit).
///
/// Stale-while-revalidate: selama masih ada data termuat ([AsyncValue.hasValue]),
/// tampilkan data lama meski stream sempat error — jangan collapse ke error
/// view. `error` hanya dipakai kalau tidak ada data sama sekali (kegagalan
/// pertama buka chat), `loading` untuk state awal.
enum ChatMessagesUiMode { data, error, loading }

@visibleForTesting
ChatMessagesUiMode chatMessagesUiMode(AsyncValue<List<Message>> stream) {
  if (stream.hasValue) return ChatMessagesUiMode.data;
  if (stream.hasError) return ChatMessagesUiMode.error;
  return ChatMessagesUiMode.loading;
}

/// Badge tipis non-blocking yang muncul saat stream pesan sedang mencoba
/// menyambung ulang setelah gangguan Realtime sesaat (retry+backoff).
class ReconnectingBadge extends StatelessWidget {
  const ReconnectingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = MekaarColors.surfaceOf(context);
    final accent = MekaarColors.accentOf(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
          const SizedBox(width: 8),
          Text(
            'Menyambung ulang…',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

