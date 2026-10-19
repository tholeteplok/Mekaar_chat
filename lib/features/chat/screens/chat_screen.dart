import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/chat_date_separator.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
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
import '../widgets/chat_room_privacy_sheet.dart';
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
import '../../../data/models/call_model.dart';
import '../widgets/call_history_bubble.dart';

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

enum _ChatItemKind { message, call, dateSeparator }

class _ChatItemEntry {
  final _ChatItemKind kind;
  final Message? message;
  final CallModel? call;
  final DateTime? date;

  const _ChatItemEntry.message(this.message)
    : kind = _ChatItemKind.message,
      call = null,
      date = null;

  const _ChatItemEntry.call(this.call)
    : kind = _ChatItemKind.call,
      message = null,
      date = null;

  const _ChatItemEntry.dateSeparator(this.date)
    : kind = _ChatItemKind.dateSeparator,
      message = null,
      call = null;

  DateTime get timestamp {
    if (kind == _ChatItemKind.message) return message!.createdAt;
    if (kind == _ChatItemKind.call) return call!.createdAt;
    return date ?? DateTime.now();
  }
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ChatComposerState> _composerKey =
      GlobalKey<ChatComposerState>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isViewOnce = false;
  bool _burnOnExit = false;
  bool _burnTriggered = false;
  bool _isEmojiPickerOpen = false;
  Message? _replyMessage;
  Message? _editingMessage;
  final Set<String> _selectedMessageIds = <String>{};
  final Set<String> _selectedCallIds = <String>{};
  Set<String> _hiddenCallIds = <String>{};
  String? _reactionAnchorMessageId;

  bool get _isSelectionMode =>
      _selectedMessageIds.isNotEmpty || _selectedCallIds.isNotEmpty;

  int get _totalSelectedCount =>
      _selectedMessageIds.length + _selectedCallIds.length;

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
      _selectedCallIds.clear();
      _reactionAnchorMessageId = null;
    });
  }

  void _toggleMessageSelection(String messageId) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_totalSelectedCount != 1 || _selectedCallIds.isNotEmpty) {
          _reactionAnchorMessageId = null;
        } else {
          _reactionAnchorMessageId = _selectedMessageIds.first;
        }
      } else {
        _selectedMessageIds.add(messageId);
        _reactionAnchorMessageId = null;
      }
    });
  }

  void _handleMessageLongPress(String messageId) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (!_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.add(messageId);
      }
      if (_totalSelectedCount == 1) {
        _reactionAnchorMessageId = messageId;
      } else {
        _reactionAnchorMessageId = null;
      }
    });
  }

  void _toggleCallSelection(String callId) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (_selectedCallIds.contains(callId)) {
        _selectedCallIds.remove(callId);
      } else {
        _selectedCallIds.add(callId);
      }
      _reactionAnchorMessageId = null;
    });
  }

  void _handleCallLongPress(String callId) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (!_selectedCallIds.contains(callId)) {
        _selectedCallIds.add(callId);
      }
      _reactionAnchorMessageId = null;
    });
  }

  Future<void> _loadHiddenCalls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list =
          prefs.getStringList('hidden_call_ids_${widget.chatId}') ?? [];
      if (mounted && list.isNotEmpty) {
        setState(() => _hiddenCallIds = list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _hideSelectedCalls(Set<String> callIds) async {
    if (callIds.isEmpty) return;
    setState(() {
      _hiddenCallIds.addAll(callIds);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'hidden_call_ids_${widget.chatId}',
        _hiddenCallIds.toList(),
      );
    } catch (_) {}
  }
  DateTime? _otherLastRead;
  final ValueNotifier<DateTime?> _otherLastSeenNotifier =
      ValueNotifier<DateTime?>(null);
  int _autoDeleteHours = 0;
  String _scheduledWipeMode = 'off';
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
            final name =
                (profile['display_name'] as String?)?.isNotEmpty == true
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
    final atBottom =
        _scrollController.hasClients &&
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
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
      }
    });
    _startPresenceHeartbeat();
    _loadHiddenCalls();

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
      DateTime? loadedWipeTarget;
      try {
        final wipeData = await repo.getRoomScheduledWipe(widget.chatId);
        if (wipeData != null) {
          loadedWipeMode = wipeData['scheduled_wipe_mode'] as String? ?? 'off';
          final targetStr = wipeData['scheduled_wipe_target_at'] as String?;
          loadedWipeTarget = targetStr != null
              ? DateTime.tryParse(targetStr)
              : null;
        }
      } catch (_) {}

      // Muat preferensi Sekali Lihat (View Once) per-room dari SharedPreferences
      bool savedViewOnce = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        savedViewOnce =
            prefs.getBool('room_view_once_${widget.chatId}') ?? false;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _autoDeleteHours = roomAutoDelete;
        _burnOnExit = roomBurnOnExit;
        _scheduledWipeMode = loadedWipeMode;
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
        _otherLastSeenNotifier.value = await repo.getLastSeen(
          widget.otherUserId!,
        );
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
      return 'Daring';
    }

    final isSameDay =
        now.year == lastSeen.year &&
        now.month == lastSeen.month &&
        now.day == lastSeen.day;

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == lastSeen.year &&
        yesterday.month == lastSeen.month &&
        yesterday.day == lastSeen.day;

    final hourStr = lastSeen.hour.toString().padLeft(2, '0');
    final minuteStr = lastSeen.minute.toString().padLeft(2, '0');
    final timeStr = '$hourStr:$minuteStr';

    if (isSameDay) {
      return 'Terakhir dilihat $timeStr';
    } else if (isYesterday) {
      return 'Terakhir kemarin $timeStr';
    } else if (diff.inDays < 7) {
      const days = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ];
      final dayName = days[lastSeen.weekday - 1];
      return 'Terakhir $dayName $timeStr';
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
        'Des',
      ];
      final monthName = monthNames[lastSeen.month - 1];
      return 'Terakhir ${lastSeen.day} $monthName';
    } else {
      final dayStr = lastSeen.day.toString().padLeft(2, '0');
      final monthStr = lastSeen.month.toString().padLeft(2, '0');
      final yearShort = lastSeen.year.toString().substring(2);
      return 'Terakhir $dayStr/$monthStr/$yearShort';
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
    _searchController.dispose();
    _scrollController.dispose();
    _showScrollButton.dispose();
    _newMessageCount.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _burnOnExit) {
      _triggerBurnOnExit();
    }
  }

  Future<void> _triggerBurnOnExit() async {
    if (_burnTriggered || !_burnOnExit) return;
    _burnTriggered = true;
    try {
      await ref
          .read(chatRepositoryProvider)
          .executeRoomBurnOnExit(widget.chatId);
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

    // ── Mode 2: Kirim Pesan Baru (Optimistic UI 0ms Latency) ──
    final textToSend = text;
    final replyToMessage = _replyMessage;
    final isViewOnceToSend = _isViewOnce;

    // Pengosongan Input Bar & Reset State UI Secara Instan (0ms Delay bagi Pengguna)
    _textController.clear();
    setState(() {
      _replyMessage = null;
    });
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(false);

    // Buat pesan optimistik agar bubble langsung muncul seketika di layar
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final optimisticMessage = Message(
      id: tempId,
      roomId: widget.chatId,
      senderId: currentUserId,
      content: textToSend,
      type: MessageType.text,
      isViewOnce: isViewOnceToSend,
      replyToId: replyToMessage?.id,
      createdAt: now,
      updatedAt: now,
      isSending: true,
    );

    ref
        .read(pendingMessagesProvider(widget.chatId).notifier)
        .addPending(optimisticMessage);
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

      // Setelah terkirim ke server, hapus item pending sementara
      if (mounted) {
        ref
            .read(pendingMessagesProvider(widget.chatId).notifier)
            .removePending(tempId);
      }
    } catch (e) {
      // Fail-Safe Restoration: Hapus pending, kembalikan teks dan state bila pengiriman gagal
      if (mounted) {
        ref
            .read(pendingMessagesProvider(widget.chatId).notifier)
            .removePending(tempId);
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

  Future<void> _handleSendMedia(
    File file,
    MessageType type, {
    String? caption,
    bool? isViewOnce,
  }) async {
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
        final result = await uploader.uploadEncryptedChatMedia(
          file,
          widget.chatId,
        );
        url = result.url;
        fileKeyB64 = result.keyB64;
      } else {
        // Fallback: unggah biasa
        url = await uploader.uploadChatMedia(file, widget.chatId);
      }

      uploadedUrl = url;
      final isViewOnceToSend = isViewOnce ?? _isViewOnce;

      final trimmedCaption = caption?.trim();
      String contentPayload;
      if (fileKeyB64 != null && fileKeyB64.isNotEmpty) {
        if (trimmedCaption != null && trimmedCaption.isNotEmpty) {
          contentPayload = jsonEncode({
            'key': fileKeyB64,
            'caption': trimmedCaption,
          });
        } else {
          contentPayload = fileKeyB64;
        }
      } else {
        contentPayload = trimmedCaption ?? '';
      }

      final replyId = _replyMessage?.id;

      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            contentPayload,
            mediaUrl: url,
            type: type,
            isViewOnce: isViewOnceToSend,
            replyToId: replyId,
            autoDeleteHours: _autoDeleteHours,
            scheduledWipeTargetAt: _scheduledWipeTargetAt,
          );

      if (mounted && _replyMessage != null) {
        setState(() => _replyMessage = null);
      }
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
        MekaarSnackbar.success(
          context,
          'Lokasi live dibagikan selama $durationMinutes menit',
        );
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
      message:
          'Pesan akan disembunyikan untuk Anda saja. Lawan bicara tetap dapat melihat pesan ini.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            await ref
                .read(chatActionsProvider)
                .hideMessageForMe(msg.id, roomId: widget.chatId);
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: Text('Hapus', style: TextStyle(color: MekaarColors.sosRed)),
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
            await ref
                .read(chatActionsProvider)
                .deleteMessageForEveryone(msg.id);
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
                      style: TextStyle(
                        color: MekaarColors.textPrimaryOf(context),
                      ),
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

  void _replyToSelectedMessage(List<Message> allMessages) {
    if (_selectedMessageIds.length != 1) return;
    final msgId = _selectedMessageIds.first;
    Message? targetMsg;
    for (final m in allMessages) {
      if (m.id == msgId) {
        targetMsg = m;
        break;
      }
    }
    if (targetMsg == null) return;
    setState(() {
      _replyMessage = targetMsg;
      _editingMessage = null;
    });
    _clearSelection();
  }

  void _copySelectedMessages(List<Message> allMessages) {
    final selectedMsgs = allMessages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();
    // Urutkan kronologis dari paling awal ke paling baru
    selectedMsgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final textPieces = selectedMsgs
        .where(
          (m) =>
              m.type == MessageType.text &&
              !m.isDeleted &&
              m.content.trim().isNotEmpty,
        )
        .map((m) => m.content)
        .toList();

    if (textPieces.isEmpty) {
      MekaarSnackbar.info(context, 'Tidak ada teks yang dapat disalin.');
      _clearSelection();
      return;
    }

    Clipboard.setData(ClipboardData(text: textPieces.join('\n\n')));
    HapticService.trigger(MekaarHapticIntent.selection);
    MekaarSnackbar.success(
      context,
      textPieces.length == 1
          ? 'Pesan disalin'
          : '${textPieces.length} pesan disalin',
    );
    _clearSelection();
  }

  void _confirmDeleteSingleMessage(Message msg) {
    _selectedMessageIds.clear();
    _selectedCallIds.clear();
    _selectedMessageIds.add(msg.id);
    _confirmDeleteSelectedItems([msg]);
  }

  void _confirmDeleteSingleCall(CallModel call) {
    _selectedMessageIds.clear();
    _selectedCallIds.clear();
    _selectedCallIds.add(call.id);
    _confirmDeleteSelectedItems([]);
  }

  void _confirmDeleteSelectedItems(List<Message> allMessages) {
    final currentUserId = ref.read(authProvider).user?.id;
    final selectedMsgs = allMessages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();
    final selectedCallIdsCopy = Set<String>.from(_selectedCallIds);

    if (selectedMsgs.isEmpty && selectedCallIdsCopy.isEmpty) return;

    final canDeleteForEveryone = selectedMsgs.any(
      (m) => m.senderId == currentUserId,
    );
    final totalCount = selectedMsgs.length + selectedCallIdsCopy.length;
    final isSingle = totalCount == 1;
    final title = isSingle ? 'Hapus item obrolan?' : 'Hapus $totalCount item?';

    bool deleteForEveryone = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final textPrimary = MekaarColors.textPrimaryOf(ctx);
            final textSecondary = MekaarColors.textSecondaryOf(ctx);

            return AlertDialog(
              backgroundColor: MekaarColors.surfaceOf(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.lg),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item yang dipilih akan dihapus dari obrolan ini.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (canDeleteForEveryone) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                      onTap: () {
                        setDialogState(() {
                          deleteForEveryone = !deleteForEveryone;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: deleteForEveryone,
                                activeColor: MekaarColors.sosRed,
                                onChanged: (val) {
                                  setDialogState(() {
                                    deleteForEveryone = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Hapus juga untuk ${widget.isGroup ? 'semua anggota' : widget.chatName}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final actions = ref.read(chatActionsProvider);
                    final toProcessMsgs = List<Message>.from(selectedMsgs);
                    final toProcessCalls = Set<String>.from(selectedCallIdsCopy);
                    _clearSelection();

                    // 1. Proses penghapusan pesan
                    for (final msg in toProcessMsgs) {
                      if (deleteForEveryone && msg.senderId == currentUserId) {
                        await actions.deleteMessageForEveryone(msg.id);
                      } else {
                        await actions.hideMessageForMe(
                          msg.id,
                          roomId: widget.chatId,
                        );
                      }
                    }

                    // 2. Proses penyembunyian/penghapusan riwayat panggilan
                    if (toProcessCalls.isNotEmpty) {
                      await _hideSelectedCalls(toProcessCalls);
                    }

                    if (mounted) {
                      MekaarSnackbar.success(
                        context,
                        deleteForEveryone
                            ? 'Item obrolan dihapus untuk semua orang'
                            : 'Item obrolan dihapus untuk Anda',
                      );
                    }
                  },
                  child: Text(
                    'Hapus',
                    style: TextStyle(
                      color: MekaarColors.sosRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (mounted && !_isSelectionMode) {
        _clearSelection();
      }
    });
  }

  void _forwardSelectedMessages(
    List<Message> allMessages, {
    required RoomForwardingProtection? forwardingProtection,
  }) {
    if (forwardingProtection?.effective ?? false) {
      MekaarSnackbar.warning(
        context,
        'Penerusan pesan dibatasi di obrolan ini.',
      );
      return;
    }

    final selectedMsgs = allMessages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();
    selectedMsgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final actions = ref.read(chatActionsProvider);
    final forwardableMsgs = selectedMsgs
        .where((m) => actions.canForward(m, forwardingProtectionActive: false))
        .toList();

    if (forwardableMsgs.isEmpty) {
      MekaarSnackbar.warning(
        context,
        'Pesan yang dipilih tidak dapat diteruskan.',
      );
      return;
    }

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
                      style: TextStyle(
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  title: Text(name),
                  onTap: () async {
                    Navigator.pop(ctx);
                    // Verifikasi ulang filter privasi secara segar
                    final currentForwarding = ref
                        .read(
                          roomForwardingProtectionProvider(widget.chatId),
                        )
                        .valueOrNull;
                    if (currentForwarding?.effective ?? false) {
                      if (context.mounted) {
                        MekaarSnackbar.warning(
                          context,
                          'Penerusan pesan dibatasi di obrolan ini.',
                        );
                      }
                      return;
                    }

                    _clearSelection();
                    int successCount = 0;
                    for (final msg in forwardableMsgs) {
                      if (!actions.canForward(
                        msg,
                        forwardingProtectionActive:
                            currentForwarding?.effective ?? false,
                      )) {
                        continue;
                      }
                      try {
                        await actions.forwardMessage(
                          msg,
                          room['id'] as String,
                        );
                        successCount++;
                      } catch (_) {}
                    }

                    if (mounted) {
                      if (successCount > 0) {
                        MekaarSnackbar.success(
                          context,
                          successCount == 1
                              ? 'Pesan diteruskan ke $name'
                              : '$successCount pesan diteruskan ke $name',
                        );
                      } else {
                        MekaarSnackbar.error(context, 'Gagal meneruskan pesan.');
                      }
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

  Widget _buildFloatingReactionPill(Message msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222A) : Colors.white,
          borderRadius: BorderRadius.circular(MekaarRadius.pill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((emoji) {
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                _handleReactToMessage(msg, emoji);
                _clearSelection();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSelectionAppBar(
    BuildContext context, {
    required ChatRoomThemeSpec roomThemeSpec,
    required RoomForwardingProtection? forwardingProtection,
    required List<Message> rawMessages,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        roomThemeSpec.glassBackgroundColor ?? MekaarColors.surfaceOf(context);
    final textPrimary = roomThemeSpec.textColor;
    final iconColor = roomThemeSpec.iconColor;

    final selectedCount = _totalSelectedCount;
    final isSingle = selectedCount == 1;
    final isForwardProtected = forwardingProtection?.effective ?? false;

    final canReply = isSingle && _selectedMessageIds.length == 1;
    final hasCopyableText = rawMessages.any(
      (m) =>
          _selectedMessageIds.contains(m.id) &&
          m.type == MessageType.text &&
          !m.isDeleted &&
          m.content.trim().isNotEmpty,
    );
    final canForward = !isForwardProtected &&
        _selectedCallIds.isEmpty &&
        _selectedMessageIds.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: MekaarColors.borderOf(
              context,
            ).withValues(alpha: isDark ? 0.3 : 0.1),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SizedBox(
        height: kToolbarHeight,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                SolarIconsOutline.closeCircle,
                size: 22,
                color: iconColor,
              ),
              tooltip: 'Batal',
              onPressed: _clearSelection,
            ),
            const SizedBox(width: 4),
            Text(
              '$selectedCount dipilih',
              style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (canReply)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.reply,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Balas',
                onPressed: () => _replyToSelectedMessage(rawMessages),
              ),
            if (hasCopyableText)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.copy,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Salin',
                onPressed: () => _copySelectedMessages(rawMessages),
              ),
            if (canForward)
              IconButton(
                icon: Icon(
                  SolarIconsOutline.forward,
                  size: 22,
                  color: iconColor,
                ),
                tooltip: 'Teruskan',
                onPressed: () => _forwardSelectedMessages(
                  rawMessages,
                  forwardingProtection: forwardingProtection,
                ),
              ),
            IconButton(
              icon: Icon(
                SolarIconsOutline.trashBinTrash,
                size: 22,
                color: MekaarColors.sosRed,
              ),
              tooltip: 'Hapus',
              onPressed: () => _confirmDeleteSelectedItems(rawMessages),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
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
          _scheduledWipeTargetAt = _scheduledWipeTargetAt!.add(
            const Duration(days: 1),
          );
        });
        _scheduleWipeTimer();
      }
    });
  }

  Future<void> _triggerLocalScheduledWipe() async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .executeRoomScheduledWipe(widget.chatId);
      if (mounted) {
        ref.invalidate(chatMessagesProvider(widget.chatId));
        if (_scheduledWipeMode == 'one_shot') {
          setState(() {
            _scheduledWipeMode = 'off';
            _scheduledWipeTargetAt = null;
          });
        }
      }
    } catch (_) {}
  }

  void _initiateCall(String callType) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null || widget.otherUserId == null) {
      MekaarSnackbar.error(
        context,
        'Panggilan tidak tersedia untuk obrolan ini.',
      );
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
        duration: MekaarMotion.counter,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readReceiptsEnabled =
        ref.watch(authProvider.select((a) => a.profile?.readReceiptsEnabled)) ??
        true;
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);

    final topAreaHeight =
        MediaQuery.of(context).padding.top + kToolbarHeight + 6.0;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_isEmojiPickerOpen && !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isSelectionMode) {
            _clearSelection();
            return;
          }
          if (_isEmojiPickerOpen) {
            _composerKey.currentState?.closeEmojiPicker();
            setState(() => _isEmojiPickerOpen = false);
            return;
          }
        }
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
                final chatPref =
                    ref.watch(chatThemeProvider).valueOrNull ??
                    const ChatThemePreference();
                return _buildWallpaperBackground(chatPref);
              },
            ),

            // ── Layer 1: Daftar Pesan (Scoped Consumer) ──
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, _) {
                  final chatPref =
                      ref.watch(chatThemeProvider).valueOrNull ??
                      const ChatThemePreference();
                  final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
                    chatPref,
                    context,
                  );
                  final e2eeStatus = ref.watch(
                    e2eeRoomStatusProvider(widget.chatId),
                  );
                  final messagesStream = ref.watch(
                    chatMessagesProvider(widget.chatId),
                  );
                  final reconnecting =
                      ref
                          .watch(chatReconnectingProvider(widget.chatId))
                          .value ??
                      false;
                  final protectionAsync = ref.watch(
                    roomScreenProtectionProvider(widget.chatId),
                  );
                  final protection = protectionAsync.valueOrNull;
                  final forwardingProtectionAsync = ref.watch(
                    roomForwardingProtectionProvider(widget.chatId),
                  );
                  final forwardingProtection =
                      forwardingProtectionAsync.valueOrNull;

                  return Column(
                    children: [
                      // Banner E2EE & proteksi harus di bawah header floating agar
                      // tidak tertimpa atau terlalu ke atas
                      SizedBox(height: topAreaHeight),
                      E2eePreparationBanner(status: e2eeStatus),
                      if (protection?.effective ?? true)
                        ScreenProtectionStatusBadge(
                          label:
                              protection?.statusLabel ?? 'Proteksi ruang aktif',
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
                                      final rawDbMessages =
                                          messagesStream.valueOrNull!;
                                      final pendingMessages = ref.watch(
                                        pendingMessagesProvider(widget.chatId),
                                      );
                                      final callsAsync = ref.watch(
                                        chatCallsProvider(widget.chatId),
                                      );
                                      final rawCallsUnfiltered =
                                          callsAsync.valueOrNull ?? const [];
                                      final rawCalls = _hiddenCallIds.isEmpty
                                          ? rawCallsUnfiltered
                                          : rawCallsUnfiltered
                                              .where(
                                                (c) => !_hiddenCallIds
                                                    .contains(c.id),
                                              )
                                              .toList();
                                      final dbIds = {
                                        for (var m in rawDbMessages) m.id,
                                      };
                                      final activePending = pendingMessages
                                          .where((p) => !dbIds.contains(p.id))
                                          .toList();
                                      final rawMessages = [
                                        ...rawDbMessages,
                                        ...activePending,
                                      ];

                                      if (rawMessages.isEmpty &&
                                          rawCalls.isEmpty) {
                                        return const MekaarStateView(
                                          pose: MikaPose.sleep,
                                          title: 'Belum Ada Pesan',
                                          message:
                                              'Belum ada pesan atau panggilan. Mulai percakapan pertama!',
                                        );
                                      }

                                      final messages = _searchQuery.isEmpty
                                          ? rawMessages
                                          : rawMessages
                                                .where(
                                                  (m) => m.content
                                                      .toLowerCase()
                                                      .contains(
                                                        _searchQuery
                                                            .toLowerCase(),
                                                      ),
                                                )
                                                .toList();

                                      final calls = _searchQuery.isEmpty
                                          ? rawCalls
                                          : rawCalls
                                                .where(
                                                  (c) =>
                                                      c.callType
                                                          .toLowerCase()
                                                          .contains(
                                                            _searchQuery
                                                                .toLowerCase(),
                                                          ) ||
                                                      c
                                                          .getDisplayStatus(
                                                            c.callerId ==
                                                                currentUserId,
                                                          )
                                                          .toLowerCase()
                                                          .contains(
                                                            _searchQuery
                                                                .toLowerCase(),
                                                          ),
                                                )
                                                .toList();

                                      if (messages.isEmpty && calls.isEmpty) {
                                        return MekaarStateView(
                                          pose: MikaPose.confused,
                                          title: 'Tidak Ditemukan',
                                          message:
                                              'Tidak ada pesan atau panggilan yang cocok dengan "$_searchQuery".',
                                        );
                                      }

                                      final itemEntries = _buildItemEntries(
                                        messages,
                                        calls,
                                      );
                                      final messageMap = {
                                        for (var m in rawMessages) m.id: m,
                                      };

                                      final emojiInset = _isEmojiPickerOpen
                                          ? 270.0
                                          : 0.0;
                                      return ListView.builder(
                                        controller: _scrollController,
                                        reverse: true,
                                        // Padding bawah memberi ruang untuk composer floating + inset keyboard + panel emoji
                                        padding: EdgeInsets.only(
                                          top: 8,
                                          bottom:
                                              130 + keyboardHeight + emojiInset,
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
                                        pose: ErrorResolver.resolvePose(
                                          messagesStream.error,
                                        ),
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
                          final isTyping = ref.watch(
                            typingStateProvider(widget.chatId),
                          );
                          if (!isTyping) return const SizedBox.shrink();
                          final emojiInset = _isEmojiPickerOpen ? 270.0 : 0.0;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: 84 + keyboardHeight + emojiInset,
                            ),
                            child: const TypingIndicator(
                              dotColor: AppColors.blue,
                            ),
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
                  final chatPref =
                      ref.watch(chatThemeProvider).valueOrNull ??
                      const ChatThemePreference();
                  final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
                    chatPref,
                    context,
                  );
                  final e2eeStatus = ref.watch(
                    e2eeRoomStatusProvider(widget.chatId),
                  );
                  final isE2eeReady = e2eeStatus == E2eeRoomStatus.ready;

                  return ChatComposer(
                    key: _composerKey,
                    controller: _textController,
                    replyMessage: _replyMessage,
                    editingMessage: _editingMessage,
                    enabled: isE2eeReady,
                    roomThemeSpec: roomThemeSpec,
                    onEmojiPanelVisibilityChanged: (isOpen) {
                      if (_isEmojiPickerOpen != isOpen) {
                        setState(() => _isEmojiPickerOpen = isOpen);
                        if (isOpen) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToBottom(),
                          );
                        }
                      }
                    },
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
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  120 +
                  (_isEmojiPickerOpen ? 270.0 : 0.0),
              child: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    final chatPref =
                        ref.watch(chatThemeProvider).valueOrNull ??
                        const ChatThemePreference();
                    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
                      chatPref,
                      context,
                    );

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
                  final chatPref =
                      ref.watch(chatThemeProvider).valueOrNull ??
                      const ChatThemePreference();
                  final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
                    chatPref,
                    context,
                  );

                  if (_isSelectionMode) {
                    final forwardingProtection = ref
                        .watch(roomForwardingProtectionProvider(widget.chatId))
                        .valueOrNull;

                    final messagesStream = ref.watch(
                      chatMessagesProvider(widget.chatId),
                    );
                    final rawDbMessages =
                        messagesStream.valueOrNull ?? const [];
                    final pendingMessages = ref.watch(
                      pendingMessagesProvider(widget.chatId),
                    );
                    final dbIds = {for (var m in rawDbMessages) m.id};
                    final activePending = pendingMessages
                        .where((p) => !dbIds.contains(p.id))
                        .toList();
                    final rawMessages = [...rawDbMessages, ...activePending];

                    return _buildSelectionAppBar(
                      context,
                      roomThemeSpec: roomThemeSpec,
                      forwardingProtection: forwardingProtection,
                      rawMessages: rawMessages,
                    );
                  }

                  final isDark = MekaarColors.isDarkContext(context);
                  final frostedBg = isDark
                      ? MekaarColors.composerOverlayDark
                      : MekaarColors.composerOverlayLight;
                  final frostedBorder = isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.10);
                  final textPrimary = MekaarColors.textPrimaryOf(context);

                  if (_isSearching) {
                    final topPadding = MediaQuery.of(context).padding.top;
                    return Padding(
                      padding: EdgeInsets.only(
                        top: topPadding + 4,
                        left: 12,
                        right: 12,
                      ),
                      child: MekaarGlassBlurContainer(
                        height: 52,
                        borderRadius: BorderRadius.circular(MekaarRadius.pill),
                        border: Border.all(color: frostedBorder, width: 1),
                        customColor: frostedBg,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                SolarIconsOutline.arrowLeft,
                                color: roomThemeSpec.iconColor,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Cari dalam obrolan...',
                                  hintStyle: TextStyle(
                                    color: MekaarColors.textMutedOf(context),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() => _searchQuery = val.trim());
                                },
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  SolarIconsOutline.closeCircle,
                                  color: MekaarColors.textMutedOf(context),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  final isTyping = ref.watch(
                    typingStateProvider(widget.chatId),
                  );

                  return ValueListenableBuilder<DateTime?>(
                    valueListenable: _otherLastSeenNotifier,
                    builder: (context, lastSeen, _) {
                      final isOnline = _isCurrentlyOnline(lastSeen);
                      return CustomAppBar(
                        isMaterialHeader: true,
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
                          // 1. Panggilan Video Langsung
                          IconButton(
                            icon: Icon(
                              SolarIconsOutline.videocamera,
                              color: roomThemeSpec.iconColor,
                              size: 22,
                            ),
                            tooltip: 'Panggilan Video',
                            onPressed: () => _initiateCall('video'),
                          ),
                          // 2. Panggilan Suara Langsung
                          IconButton(
                            icon: Icon(
                              SolarIconsOutline.phoneRounded,
                              color: roomThemeSpec.iconColor,
                              size: 22,
                            ),
                            tooltip: 'Panggilan Suara',
                            onPressed: () => _initiateCall('voice'),
                          ),
                          // 3. Actions Popup Menu (High-Contrast Frosted Glass)
                          PopupMenuButton<String>(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MekaarRadius.md,
                              ),
                              side: BorderSide(color: frostedBorder, width: 1),
                            ),
                            color: frostedBg,
                            surfaceTintColor: Colors.transparent,
                            elevation: 10,
                            shadowColor: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.18,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              SolarIconsOutline.menuDots,
                              color: roomThemeSpec.iconColor,
                            ),
                            onSelected: (value) async {
                              if (value == 'search') {
                                setState(() => _isSearching = true);
                              } else if (value == 'voice') {
                                _initiateCall('voice');
                              } else if (value == 'video') {
                                _initiateCall('video');
                              } else if (value == 'theme') {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.chatThemeSettings,
                                );
                              } else if (value == 'privacy_settings') {
                                ChatRoomPrivacySheet.show(
                                  context,
                                  roomId: widget.chatId,
                                  onSettingsChanged: () {
                                    if (mounted) setState(() {});
                                  },
                                );
                              } else if (value == 'clear') {
                                _confirmClearHistory();
                              } else if (value == 'delete') {
                                _confirmDeleteChat();
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'search',
                                child: Row(
                                  children: [
                                    Icon(
                                      SolarIconsOutline.magnifier,
                                      size: 20,
                                      color: textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cari Pesan',
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
                              PopupMenuItem<String>(
                                value: 'privacy_settings',
                                child: Row(
                                  children: [
                                    const Icon(
                                      SolarIconsBold.shieldKeyhole,
                                      size: 20,
                                      color: AppColors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pengaturan Privasi Obrolan',
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
  List<_ChatItemEntry> _buildItemEntries(
    List<Message> messages,
    List<CallModel> calls,
  ) {
    // 1. Kumpulkan seluruh pesan dan panggilan
    final combinedRaw = <_ChatItemEntry>[];
    for (final m in messages) {
      combinedRaw.add(_ChatItemEntry.message(m));
    }
    for (final c in calls) {
      combinedRaw.add(_ChatItemEntry.call(c));
    }

    // 2. Urutkan berdasarkan timestamp descending (terbaru di index 0 karena reverse: true pada ListView)
    combinedRaw.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 3. Sisipkan pemisah tanggal
    final entries = <_ChatItemEntry>[];
    DateTime? lastDate;

    for (var i = 0; i < combinedRaw.length; i++) {
      final item = combinedRaw[i];
      final localCreatedAt = item.timestamp.toLocal();
      final itemDate = DateTime(
        localCreatedAt.year,
        localCreatedAt.month,
        localCreatedAt.day,
      );

      // Sisipkan pemisah tanggal jika hari berubah
      if (lastDate == null || itemDate != lastDate) {
        entries.add(_ChatItemEntry.dateSeparator(localCreatedAt));
        lastDate = itemDate;
      }

      entries.add(item);
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

    if (entry.kind == _ChatItemKind.call) {
      final call = entry.call!;
      final isMe = call.callerId == currentUserId;
      final isSelected = _selectedCallIds.contains(call.id);
      final callWidget = CallHistoryBubble(
        call: call,
        isMe: isMe,
        isSelected: isSelected,
        isSelectionMode: _isSelectionMode,
        onSelectionTap: () => _toggleCallSelection(call.id),
        onSelectionLongPress: () => _handleCallLongPress(call.id),
        onCallBack: () => _initiateCall(call.callType),
      );

      return RepaintBoundary(
        key: ValueKey('call_bubble_${call.id}'),
        child: _isSelectionMode
            ? callWidget
            : _SwipeActionWrapper(
                onDelete: () => _confirmDeleteSingleCall(call),
                child: callWidget,
              ),
      );
    }

    final msg = entry.message!;
    final isMe = msg.senderId == currentUserId;
    final canEdit = actions.canEdit(msg, isGuardianRoom: widget.isGuardian);

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

    final isSelected = _selectedMessageIds.contains(msg.id);

    final bubble = ChatBubble(
      message: msg,
      isMe: isMe,
      isSelected: isSelected,
      isSelectionMode: _isSelectionMode,
      onSelectionTap: () => _toggleMessageSelection(msg.id),
      onSelectionLongPress: () => _handleMessageLongPress(msg.id),
      canDelete: true, // Semua pesan bisa dihapus secara lokal (hide for me)
      canUnsend:
          isMe, // Hanya pengirim yang bisa tarik pesan (delete for everyone)
      canEdit: isMe && canEdit,
      canForward: actions.canForward(
        msg,
        forwardingProtectionActive: forwardingProtection?.effective ?? false,
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
        if (!actions.canEdit(editMsg, isGuardianRoom: widget.isGuardian)) {
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
      onReact: (reactMsg, emoji) => _handleReactToMessage(reactMsg, emoji),
    );

    final showFloatingReactions =
        isSelected && _reactionAnchorMessageId == msg.id;

    final bubbleWithPill = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showFloatingReactions) _buildFloatingReactionPill(msg, isMe),
        bubble,
      ],
    );

    // Bungkus dengan RepaintBoundary untuk isolasi repaint dan SwipeActionWrapper
    return RepaintBoundary(
      key: ValueKey('bubble_${msg.id}'),
      child: _isSelectionMode
          ? bubbleWithPill
          : _SwipeActionWrapper(
              onReply: () => setState(() {
                _replyMessage = msg;
                _editingMessage = null;
              }),
              onDelete: () => _confirmDeleteSingleMessage(msg),
              child: bubbleWithPill,
            ),
    );
  }

  Widget _buildWallpaperBackground(ChatThemePreference pref) {
    return ChatPresetResolver.buildWallpaper(pref, context);
  }
}

/// Gesture wrapper untuk aksi swipe pada bubble chat:
/// - Geser ke kanan 1x untuk memicu balasan (reply).
/// - Geser ke kiri 2x (dalam jendela 2.0 detik) untuk memicu dialog hapus.
class _SwipeActionWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const _SwipeActionWrapper({
    required this.child,
    this.onReply,
    this.onDelete,
  });

  @override
  State<_SwipeActionWrapper> createState() => _SwipeActionWrapperState();
}

class _SwipeActionWrapperState extends State<_SwipeActionWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recoilController;
  double _dragOffset = 0.0;
  bool _rightThresholdReached = false;
  bool _leftThresholdReached = false;
  int _leftSwipeCount = 0;
  Timer? _leftSwipeTimer;

  static const double _actionThreshold = 48.0;
  static const double _maxDragDistance = 72.0;
  static const Duration _doubleSwipeWindow = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _recoilController = AnimationController(
      vsync: this,
      duration: MekaarMotion.fast,
    );
  }

  @override
  void dispose() {
    _leftSwipeTimer?.cancel();
    _recoilController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;

    // 1. Geser ke kanan (Reply)
    if ((delta > 0 || _dragOffset > 0) && _dragOffset >= 0 && widget.onReply != null) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, _maxDragDistance);
        if (_dragOffset >= _actionThreshold && !_rightThresholdReached) {
          _rightThresholdReached = true;
          HapticService.trigger(MekaarHapticIntent.selection);
        }
      });
      return;
    }

    // 2. Geser ke kiri (Delete)
    if ((delta < 0 || _dragOffset < 0) && _dragOffset <= 0 && widget.onDelete != null) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(-_maxDragDistance, 0.0);
        if (_dragOffset <= -_actionThreshold && !_leftThresholdReached) {
          _leftThresholdReached = true;
          HapticService.trigger(
            _leftSwipeCount == 1
                ? MekaarHapticIntent.destructive
                : MekaarHapticIntent.selection,
          );
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // 1. Tangani swipe kanan (Reply)
    if (_rightThresholdReached) {
      _resetLeftSwipe();
      widget.onReply?.call();
    }
    _rightThresholdReached = false;

    // 2. Tangani swipe kiri (Delete 2x)
    if (_leftThresholdReached) {
      if (_leftSwipeCount == 0) {
        // Geseran pertama: catat dan aktifkan jendela 2.0 detik
        setState(() {
          _leftSwipeCount = 1;
        });
        _leftSwipeTimer?.cancel();
        _leftSwipeTimer = Timer(_doubleSwipeWindow, () {
          if (mounted) {
            setState(() {
              _leftSwipeCount = 0;
            });
          }
        });
      } else if (_leftSwipeCount == 1) {
        // Geseran kedua: konfirmasi hapus!
        _resetLeftSwipe();
        widget.onDelete?.call();
      }
    }
    _leftThresholdReached = false;

    // Animasi recoil kembali ke posisi netral (0.0)
    if (_dragOffset != 0.0) {
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

  void _resetLeftSwipe() {
    _leftSwipeTimer?.cancel();
    _leftSwipeTimer = null;
    if (_leftSwipeCount != 0 && mounted) {
      setState(() {
        _leftSwipeCount = 0;
      });
    } else {
      _leftSwipeCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ikon Reply di sisi kiri (saat digeser ke kanan)
          if (_dragOffset > 6 && widget.onReply != null)
            Positioned(
              left: 14,
              child: Opacity(
                opacity: (_dragOffset / _actionThreshold).clamp(0.0, 1.0),
                child: Container(
                  width: 34,
                  height: 34,
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

          // Ikon Hapus di sisi kanan (saat digeser ke kiri)
          if (_dragOffset < -6 && widget.onDelete != null)
            Positioned(
              right: 14,
              child: Opacity(
                opacity: (-_dragOffset / _actionThreshold).clamp(0.0, 1.0),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: MekaarColors.sosRed.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: _leftSwipeCount == 1
                        ? Border.all(color: MekaarColors.sosRed, width: 1.5)
                        : null,
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.trashBinTrash,
                      color: MekaarColors.sosRed,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),

          // Petunjuk visual saat geseran pertama aktif (menunggu geseran kedua)
          if (_leftSwipeCount == 1 && _dragOffset.abs() < 6 && widget.onDelete != null)
            Positioned(
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MekaarColors.sosRed.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: MekaarColors.sosRed.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      SolarIconsBold.trashBinMinimalistic,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Geser 1x lagi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bubble utama yang digeser
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
