import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import '../../../data/services/file_export_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/utils/message_preview_resolver.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/chat_date_separator.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_banner.dart';
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
import '../providers/chat_draft_provider.dart';
import '../../../data/services/local_message_database.dart';
import '../providers/forwarding_protection_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_room_privacy_sheet.dart';
import '../providers/e2ee_room_status_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/media_upload_service.dart';
import '../../../data/services/e2ee_service.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/call_model.dart';
import '../../../data/repositories/call_repository.dart';
import '../widgets/call_history_bubble.dart';
import '../widgets/chat_floating_reaction_pill.dart';
import '../widgets/chat_selection_app_bar.dart';
import '../widgets/chat_swipe_action_wrapper.dart';
import '../providers/vault_provider.dart';

export '../widgets/chat_reconnecting_badge.dart';
export '../widgets/chat_swipe_action_wrapper.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../data/services/local_vault_database.dart';

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
    this.chatName = '',
    this.chatAvatar = '',
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
  late final FocusNode _inChatSearchFocusNode;
  late final FocusNode _composerFocusNode;
  Timer? _searchDebounceTimer;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isViewOnce = false;
  bool _burnOnExit = false;
  bool _burnTriggered = false;
  bool _isEmojiPickerOpen = false;
  bool _wasKeyboardOpenOnPause = false;
  Message? _replyMessage;
  Message? _editingMessage;
  final Set<String> _selectedMessageIds = <String>{};
  final Set<String> _selectedCallIds = <String>{};
  Set<String> _hiddenCallIds = <String>{};
  String? _reactionAnchorMessageId;
  bool _isMuted = false;

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
    try {
      unawaited(ref.read(callRepositoryProvider).hideCalls(callIds));
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
  StreamSubscription? _roomSettingsSub;

  String? _resolvedChatName;
  String? _resolvedAvatarInitial;
  String? _resolvedAvatarUrl;
  String? _resolvedOtherUserId;

  String get _effectiveChatName =>
      (_resolvedChatName?.isNotEmpty == true)
          ? _resolvedChatName!
          : (widget.chatName.isNotEmpty ? widget.chatName : 'Percakapan');

  String get _effectiveAvatarInitial =>
      (_resolvedAvatarInitial?.isNotEmpty == true)
          ? _resolvedAvatarInitial!
          : (widget.chatAvatar.isNotEmpty
              ? widget.chatAvatar
              : (_effectiveChatName.isNotEmpty
                  ? _effectiveChatName[0].toUpperCase()
                  : '💬'));

  String? get _effectiveAvatarUrl => _resolvedAvatarUrl ?? widget.chatAvatarUrl;
  String? get _effectiveOtherUserId =>
      _resolvedOtherUserId ?? widget.otherUserId;

  String _getSenderDisplayName(Message? msg) {
    if (msg == null) return '';
    final myId = ref.read(authProvider).user?.id ?? Supabase.instance.client.auth.currentUser?.id;
    if (msg.senderId == myId) return 'Anda';
    if (!widget.isGroup) return _effectiveChatName;
    return _participantNames[msg.senderId] ?? 'Anggota';
  }

  Future<void> _resolveMissingRoomMetadata() async {
    if (widget.isGroup) return;
    if (_effectiveOtherUserId != null &&
        widget.chatName.isNotEmpty &&
        widget.chatName != 'Percakapan') {
      return;
    }

    try {
      // 1. Coba baca dari state cache chatRoomsProvider di RAM
      final cachedRooms = ref.read(chatRoomsProvider).valueOrNull ?? [];
      final cached = cachedRooms.cast<Map<String, dynamic>?>().firstWhere(
        (r) => r?['id'] == widget.chatId,
        orElse: () => null,
      );

      if (cached != null && mounted) {
        setState(() {
          _resolvedChatName ??= cached['name'] as String?;
          _resolvedAvatarInitial ??= cached['avatar'] as String?;
          _resolvedAvatarUrl ??= cached['avatarUrl'] as String?;
          _resolvedOtherUserId ??= cached['otherUserId'] as String?;
        });
        if (_resolvedOtherUserId != null) {
          _startPresenceHeartbeat();
        }
        return;
      }

      // 2. Fallback query langsung ke Supabase jika belum ada di cache
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final participant = await client
          .from('room_participants')
          .select('profile_id')
          .eq('room_id', widget.chatId)
          .neq('profile_id', currentUserId)
          .maybeSingle();

      if (participant != null && mounted) {
        final otherId = participant['profile_id'] as String;
        final profile = await client
            .from('public_profiles')
            .select('id, username, full_name, display_name, avatar_url')
            .eq('id', otherId)
            .maybeSingle();

        if (profile != null && mounted) {
          final name = (profile['display_name'] as String?)?.isNotEmpty == true
              ? profile['display_name'] as String
              : profile['full_name'] as String? ??
                  profile['username'] as String? ??
                  'User';
          final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          final avatarUrl = profile['avatar_url'] as String?;

          setState(() {
            _resolvedOtherUserId = otherId;
            _resolvedChatName = name;
            _resolvedAvatarInitial = avatar;
            _resolvedAvatarUrl = avatarUrl;
          });
          _startPresenceHeartbeat();
        }
      }
    } catch (_) {}
  }

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
    if (LocalMessageDatabase.instance.isDecoy || widget.chatId == 'room_welcome_mekaar') {
      return;
    }
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      if (!mounted) return;
      // Jangan ganggu fokus input dan cegah penutupan keyboard virtual oleh IME Android:
      // Jika composer sedang memiliki fokus atau keyboard sedang terbuka, tunda siklus heartbeat.
      if (_composerFocusNode.hasFocus) return;
      final viewInsetsBottom =
          MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
      if (viewInsetsBottom > 0) return;

      final repo = ref.read(chatRepositoryProvider);
      await repo.updateLastSeen();
      final otherId = _effectiveOtherUserId;
      if (otherId != null) {
        final lastSeen = await repo.getLastSeen(otherId);
        if (mounted && !_composerFocusNode.hasFocus) {
          _otherLastSeenNotifier.value = lastSeen;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _inChatSearchFocusNode = FocusNode();
    _composerFocusNode = FocusNode();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScrollChanged);
    _restoreDraftAndListenText();
    // Tandai room ini sebagai aktif agar listener notifikasi pesan tahu
    // untuk tidak memunculkan notif saat user sedang melihat percakapan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
        ref
            .read(e2eeRoomStatusProvider(widget.chatId).notifier)
            .configureForRoom(isGroup: widget.isGroup);
      }
    });
    _startPresenceHeartbeat();
    _resolveMissingRoomMetadata();
    _loadHiddenCalls();

    // Timer periodik pembersihan pesan kedaluwarsa & sinkronisasi UI real-time
    _purgeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      // Jangan ganggu fokus input dan cegah penutupan keyboard virtual oleh IME Android:
      // Jika composer sedang memiliki fokus atau keyboard sedang terbuka, tunda pembersihan berkala.
      if (_composerFocusNode.hasFocus) return;
      final viewInsetsBottom =
          MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
      if (viewInsetsBottom > 0) return;

      try {
        ref.read(chatRepositoryProvider).purgeExpiredMessages(targetRoomId: widget.chatId);
      } catch (_) {}
    });

    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);

      await _loadRoomSettings();

      // Muat preferensi Sekali Lihat (View Once) per-room dari SharedPreferences
      bool savedViewOnce = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        savedViewOnce =
            prefs.getBool('room_view_once_${widget.chatId}') ?? false;
      } catch (_) {}

      // Muat preferensi bisukan notifikasi per-room
      bool loadedMuted = false;
      try {
        final participantPrefs = await repo.getRoomPreferences(widget.chatId);
        loadedMuted = participantPrefs?.isMuted ?? false;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isViewOnce = savedViewOnce;
        _isMuted = loadedMuted;
      });



      try {
        _roomSettingsSub = Supabase.instance.client
            .from('chat_rooms')
            .stream(primaryKey: ['id'])
            .eq('id', widget.chatId)
            .listen((_) {
              if (mounted) _loadRoomSettings();
            });
      } catch (_) {}


      // Best-effort purge pesan kedaluwarsa saat pertama buka chat
      try {
        await repo.purgeExpiredMessages(targetRoomId: widget.chatId);
      } catch (_) {}
      _otherLastRead = await repo.getOtherParticipantLastRead(widget.chatId);
      if (widget.isGroup) {
        _loadGroupParticipants();
      }
      if (!LocalMessageDatabase.instance.isDecoy &&
          widget.chatId != 'room_welcome_mekaar') {
        if (widget.otherUserId != null) {
          _otherLastSeenNotifier.value = await repo.getLastSeen(
            widget.otherUserId!,
          );
        }
        repo.updateLastSeen();
      }
    });
  }

  void _restoreDraftAndListenText() {
    final initialDraft = ref.read(chatDraftsProvider)[widget.chatId];
    if (initialDraft != null) {
      if (initialDraft.content.isNotEmpty) {
        _textController.text = initialDraft.content;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: initialDraft.content.length),
        );
      }
      if (initialDraft.replyToId != null) {
        _restoreRepliedMessage(initialDraft.replyToId!);
      }
    } else {
      LocalMessageDatabase.instance.getDraft(widget.chatId).then((dbDraft) {
        if (!mounted || dbDraft == null) return;
        if (dbDraft.content.isNotEmpty && _textController.text.isEmpty) {
          setState(() {
            _textController.text = dbDraft.content;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: dbDraft.content.length),
            );
          });
        }
        if (dbDraft.replyToId != null && _replyMessage == null) {
          _restoreRepliedMessage(dbDraft.replyToId!);
        }
      });
    }
    _textController.addListener(_onTextChanged);
  }


  Future<void> _loadRoomSettings() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final roomAutoDelete = await repo.getRoomDisappearingHours(widget.chatId);
      final roomBurnOnExit = await repo.getRoomBurnOnExit(widget.chatId);
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

      // Muat ulang preferensi Sekali Lihat (View Once) per-room dari SharedPreferences
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

      if (roomBurnOnExit) {
        unawaited(LocalMessageDatabase.instance.deleteDraft(widget.chatId));
      }
      _scheduleWipeTimer();
    } catch (_) {}
  }

  void _restoreRepliedMessage(String replyToId) async {
    try {
      final msg = await LocalMessageDatabase.instance.getMessage(replyToId);
      if (mounted && msg != null) {
        setState(() {
          _replyMessage = msg;
        });
      }
    } catch (_) {}
  }

  void _setReplyMessage(Message? msg) {
    setState(() {
      _replyMessage = msg;
      if (msg != null) {
        _editingMessage = null;
      }
    });
    ref.read(chatDraftsProvider.notifier).setDraft(
      roomId: widget.chatId,
      content: _textController.text,
      replyToId: msg?.id,
      isBurnOnExit: _burnOnExit,
    );
  }

  void _onTextChanged() {
    final isTyping = _textController.text.isNotEmpty;
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(isTyping);
    ref.read(chatDraftsProvider.notifier).setDraft(
      roomId: widget.chatId,
      content: _textController.text,
      replyToId: _replyMessage?.id,
      isBurnOnExit: _burnOnExit,
    );
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
    _roomSettingsSub?.cancel();
    if (_burnOnExit) {
      _triggerBurnOnExit();
      ref.read(chatDraftsProvider.notifier).deleteDraft(widget.chatId);
    } else {
      ref.read(chatDraftsProvider.notifier).setDraft(
        roomId: widget.chatId,
        content: _textController.text,
        replyToId: _replyMessage?.id,
        isBurnOnExit: false,
        flushNow: true,
      );
    }
    // Hentikan live location sharing jika masih aktif saat meninggalkan room
    ref.read(chatActionsProvider).stopLiveLocationShare();
    // Bersihkan penanda room aktif agar notif pesan kembali aktif
    // saat user meninggalkan percakapan ini.
    if (ref.read(activeRoomIdProvider) == widget.chatId) {
      ref.read(activeRoomIdProvider.notifier).state = null;
    }
    // Pastikan status pesan ditandai telah dibaca dan unread count disegarkan saat keluar dari room
    ref.read(chatActionsProvider).markRoomRead(widget.chatId);
    ref.read(chatRoomsProvider.notifier).refreshRooms();
    _searchDebounceTimer?.cancel();
    _inChatSearchFocusNode.dispose();
    _composerFocusNode.dispose();
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasKeyboardOpenOnPause = _composerFocusNode.hasFocus ||
          ((MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0) > 0);
      if (_burnOnExit) {
        _triggerBurnOnExit();
        ref.read(chatDraftsProvider.notifier).deleteDraft(widget.chatId);
      } else {
        ref.read(chatDraftsProvider.notifier).setDraft(
          roomId: widget.chatId,
          content: _textController.text,
          replyToId: _replyMessage?.id,
          isBurnOnExit: false,
          flushNow: true,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasKeyboardOpenOnPause && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Pulihkan fokus dan tampilkan kembali keyboard virtual IME pasca lock screen (Standar Telegram)
            if (!_composerFocusNode.hasFocus) {
              _composerFocusNode.requestFocus();
            } else {
              // Jika focus node masih terdaftar hasFocus di memori Flutter,
              // lakukan re-attachment dengan IME Android melalui unfocus -> requestFocus -> TextInput.show
              _composerFocusNode.unfocus();
              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted && _composerFocusNode.canRequestFocus) {
                  _composerFocusNode.requestFocus();
                  SystemChannels.textInput.invokeMethod('TextInput.show');
                }
              });
            }
          }
        });
      }
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

    // ──── Mode 1: Edit Pesan ────
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

    // ──── Mode 2: Kirim Pesan Baru (Optimistic UI 0ms Latency) ────
    final textToSend = text;
    final replyToMessage = _replyMessage;
    final isViewOnceToSend = _isViewOnce;

    // Pengosongan Input Bar & Reset State UI Secara Instan (0ms Delay bagi Pengguna)
    _textController.clear();
    setState(() {
      _replyMessage = null;
    });
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(false);
    unawaited(ref.read(chatRepositoryProvider).updateLastSeen());
    ref.read(chatDraftsProvider.notifier).deleteDraft(widget.chatId);

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

    // Mutasi lokal list room agar pesan langsung tampil di daftar percakapan (0 ms)
    ref.read(chatRoomsProvider.notifier).updateLastMessageLocally(
      roomId: widget.chatId,
      previewText: textToSend,
      timestamp: now,
      isFromOtherUser: false,
      isCurrentlyInRoom: true,
    );

    try {
      await actions.sendMessage(
        widget.chatId,
        textToSend,
        type: MessageType.text,
        isViewOnce: isViewOnceToSend,
        replyToId: replyToMessage?.id,
        autoDeleteHours: _autoDeleteHours,
        scheduledWipeTargetAt: _scheduledWipeTargetAt,
        isGroup: widget.isGroup,
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
        ref.read(chatDraftsProvider.notifier).setDraft(
          roomId: widget.chatId,
          content: textToSend,
          replyToId: replyToMessage?.id,
          isBurnOnExit: _burnOnExit,
          flushNow: true,
        );
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
      final otherId = _effectiveOtherUserId;
      final peerKey = otherId != null
          ? await E2eeService.instance.getPeerPublicKey(otherId)
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
      if (type == MessageType.file) {
        final originalFileName = file.path.split(Platform.pathSeparator).last;
        final fileSize = await file.length();
        final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
        contentPayload = FileAttachmentMeta(
          fileName: originalFileName,
          fileSize: fileSize,
          mimeType: mimeType,
          keyB64: fileKeyB64,
          caption: trimmedCaption,
        ).toContentJson();
      } else if (fileKeyB64 != null && fileKeyB64.isNotEmpty) {
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
            isGroup: widget.isGroup,
          );

      ref.read(chatRoomsProvider.notifier).updateLastMessageLocally(
        roomId: widget.chatId,
        previewText: MessagePreviewResolver.formatChatListPreview(
          type: type,
          content: contentPayload,
          isUnreadFromOther: false,
        ),
        timestamp: DateTime.now(),
        isFromOtherUser: false,
        isCurrentlyInRoom: true,
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
            isGroup: widget.isGroup,
          );

      ref.read(chatRoomsProvider.notifier).updateLastMessageLocally(
        roomId: widget.chatId,
        previewText: MessagePreviewResolver.formatChatListPreview(
          type: MessageType.location,
          content: '$lat, $lng',
          isUnreadFromOther: false,
        ),
        timestamp: DateTime.now(),
        isFromOtherUser: false,
        isCurrentlyInRoom: true,
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


  Future<void> _showE2eeRestoreBottomSheet(BuildContext context) async {
    final pinController = TextEditingController();
    bool isLoading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(ctx),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MekaarRadius.xl),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.xl,
              vertical: MekaarSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MekaarColors.textSecondaryOf(ctx).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: MekaarSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MekaarColors.sosCoral.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        SolarIconsOutline.keyMinimalisticSquare,
                        color: MekaarColors.sosCoral,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: MekaarSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pulihkan Kunci E2EE',
                            style: MekaarTypography.headingMD.copyWith(
                              color: MekaarColors.textPrimaryOf(ctx),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Masukkan 6-digit PIN akun Anda untuk membuka sesi privat.',
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textSecondaryOf(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MekaarSpacing.lg),
                TextField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: MekaarTypography.monoLG.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.textPrimaryOf(ctx),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      letterSpacing: 12,
                      color: MekaarColors.textSecondaryOf(ctx).withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: MekaarColors.surface2Of(ctx),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: MekaarSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final confirmed = await MekaarDialog.showConfirmation<bool>(
                                  context: ctx,
                                  title: 'Reset Kunci E2EE?',
                                  message: 'Kunci enkripsi lama akan dihapus dan dibuatkan kunci baru. Riwayat pesan terenkripsi lama mungkin tidak dapat didekripsi.',
                                  isDestructive: true,
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Batal'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(backgroundColor: MekaarColors.sosCoral),
                                      child: const Text('Ya, Reset'),
                                    ),
                                  ],
                                );
                                if (confirmed == true && mounted) {
                                  setSheetState(() => isLoading = true);
                                  await E2eeService.instance.forceResetIdentity();
                                  ref.read(authProvider.notifier).setE2eeNeedsRestore(false);
                                  ref.read(e2eeRoomStatusProvider(widget.chatId).notifier).retry(isGroup: widget.isGroup);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    MekaarSnackbar.success(context, 'Kunci enkripsi baru berhasil dibuat.');
                                  }
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MekaarColors.sosCoral,
                          side: BorderSide(color: MekaarColors.sosCoral.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MekaarRadius.md),
                          ),
                        ),
                        child: const Text('Reset Kunci'),
                      ),
                    ),
                    const SizedBox(width: MekaarSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final pin = pinController.text.trim();
                                if (pin.length != 6) return;
                                setSheetState(() => isLoading = true);
                                final success = await E2eeService.instance.tryRestoreWithPin(pin);
                                setSheetState(() => isLoading = false);
                                if (success) {
                                  ref.read(authProvider.notifier).setE2eeNeedsRestore(false);
                                  ref.read(e2eeRoomStatusProvider(widget.chatId).notifier).retry(isGroup: widget.isGroup);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    MekaarSnackbar.success(context, 'Kunci E2EE berhasil dipulihkan!');
                                  }
                                } else {
                                  if (ctx.mounted) {
                                    MekaarSnackbar.error(ctx, 'PIN salah. Silakan coba lagi.');
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: MekaarColors.primaryOf(ctx),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MekaarRadius.md),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Buka Kunci'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MekaarSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
    pinController.dispose();
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
            Navigator.pop(context);
            await ref
                .read(chatActionsProvider)
                .deleteMessageForEveryone(msg.id, roomId: widget.chatId);
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

  Future<void> _handleSaveToVault(Message msg) async {
    final mediaUrl = msg.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      MekaarSnackbar.error(context, 'Tidak ada berkas yang dapat disimpan.');
      return;
    }

    MekaarSnackbar.info(context, 'Menyimpan berkas ke Brankas...');

    try {
      final payload = parseMediaPayload(msg);
      final file = await getOrDecryptMedia(
        messageId: msg.id,
        url: mediaUrl,
        isEncrypted: msg.isEncrypted,
        fileKeyB64:
            payload.fileKeyB64.isNotEmpty ? payload.fileKeyB64 : msg.content,
      );

      if (file == null || !await file.exists()) {
        if (!mounted) return;
        MekaarSnackbar.error(context, 'Gagal memproses berkas media.');
        return;
      }

      if (!mounted) return;
      if (!LocalVaultDatabase.instance.isUnlocked) {
        final verified = await MekaarPinVerificationSheet.verify(
          context,
          title: 'Buka Brankas Berkas',
          subtitle: 'Masukkan PIN untuk menyimpan berkas ke Brankas Berkas',
        );
        if (!verified || !mounted) return;
      }

      final senderName = widget.isGroup
          ? (_participantNames[msg.senderId] ?? _effectiveChatName)
          : _effectiveChatName;

      await ref.read(vaultRepositoryProvider).saveMediaToVault(
            sourceFile: file,
            originalMessageId: msg.id,
            customFileName: null,
            senderName: senderName,
            senderId: msg.senderId,
            roomId: widget.chatId,
          );

      if (!mounted) return;
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        'Berkas berhasil disimpan ke Brankas Berkas',
      );
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(
        context,
        'Gagal menyimpan ke Brankas: $e',
      );
    }
  }

  Future<void> _handleDownloadSelectedFiles(List<Message> downloadableMessages) async {
    _clearSelection();
    if (downloadableMessages.isEmpty) return;

    MekaarSnackbar.info(
      context,
      downloadableMessages.length == 1
          ? 'Mengunduh dan mendekripsi berkas...'
          : 'Mengunduh dan mendekripsi ${downloadableMessages.length} berkas...',
    );

    int successCount = 0;
    String? lastExportedPath;

    for (final msg in downloadableMessages) {
      try {
        final localFile = await FileExportService.resolveOrDownloadFile(msg);
        if (localFile != null) {
          final meta = msg.fileMeta;
          final fileName = meta?.fileName ?? localFile.path.split(Platform.pathSeparator).last;
          final exported = await FileExportService.exportToMekaarDownloads(
            file: localFile,
            fileName: fileName,
            mimeType: meta?.mimeType,
          );
          if (exported != null) {
            successCount++;
            lastExportedPath = exported;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (successCount > 0) {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        successCount == 1
            ? 'Berkas berhasil disimpan di $lastExportedPath'
            : '$successCount berkas berhasil disimpan di folder Download/Mekaar/',
      );
    } else {
      HapticService.trigger(MekaarHapticIntent.warning);
      MekaarSnackbar.error(
        context,
        'Gagal mengunduh berkas. Pastikan koneksi internet stabil.',
      );
    }
  }

  Future<void> _handleSaveSelectedToVault(List<Message> savableMessages) async {
    if (savableMessages.isEmpty) return;

    if (!LocalVaultDatabase.instance.isUnlocked) {
      final verified = await MekaarPinVerificationSheet.verify(
        context,
        title: 'Buka Brankas Berkas',
        subtitle: 'Masukkan PIN untuk menyimpan berkas ke Brankas Berkas',
      );
      if (!verified || !mounted) return;
    }

    if (!mounted) return;
    MekaarSnackbar.info(
      context,
      savableMessages.length == 1
          ? 'Menyimpan berkas ke Brankas...'
          : 'Menyimpan ${savableMessages.length} berkas ke Brankas...',
    );

    int savedCount = 0;
    final vaultRepo = ref.read(vaultRepositoryProvider);

    for (final msg in savableMessages) {
      final mediaUrl = msg.mediaUrl;
      if (mediaUrl == null || mediaUrl.isEmpty) continue;

      try {
        final payload = parseMediaPayload(msg);
        final file = await getOrDecryptMedia(
          messageId: msg.id,
          url: mediaUrl,
          isEncrypted: msg.isEncrypted,
          fileKeyB64:
              payload.fileKeyB64.isNotEmpty ? payload.fileKeyB64 : msg.content,
        );

        if (file != null && await file.exists()) {
          final senderName = widget.isGroup
              ? (_participantNames[msg.senderId] ?? _effectiveChatName)
              : _effectiveChatName;

          await vaultRepo.saveMediaToVault(
            sourceFile: file,
            originalMessageId: msg.id,
            customFileName: null,
            senderName: senderName,
            senderId: msg.senderId,
            roomId: widget.chatId,
          );
          savedCount++;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    _clearSelection();

    if (savedCount > 0) {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        savedCount == 1
            ? 'Berkas berhasil disimpan ke Brankas Berkas'
            : '$savedCount berkas berhasil disimpan ke Brankas Berkas',
      );
    } else {
      MekaarSnackbar.error(
        context,
        'Gagal memproses dan menyimpan berkas ke Brankas Berkas.',
      );
    }
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
    _setReplyMessage(targetMsg);
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
                                'Hapus juga untuk ${widget.isGroup ? 'semua anggota' : _effectiveChatName}',
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
                        await actions.deleteMessageForEveryone(
                          msg.id,
                          roomId: widget.chatId,
                        );
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
    return ChatFloatingReactionPill(
      isMe: isMe,
      onReact: (emoji) {
        _handleReactToMessage(msg, emoji);
        _clearSelection();
      },
    );
  }

  Widget _buildSelectionAppBar(
    BuildContext context, {
    required ChatRoomThemeSpec roomThemeSpec,
    required RoomForwardingProtection? forwardingProtection,
    required List<Message> rawMessages,
  }) {
    final selectedCount = _totalSelectedCount;
    final isSingle = selectedCount == 1;
    final isForwardProtected = forwardingProtection?.effective ?? false;
    final currentUserId = ref.read(authProvider).user?.id;

    final canReply = isSingle && _selectedMessageIds.length == 1;
    final singleSelectedMsg = isSingle && _selectedMessageIds.length == 1
        ? rawMessages.cast<Message?>().firstWhere(
            (m) => m?.id == _selectedMessageIds.first,
            orElse: () => null,
          )
        : null;
    final canEdit = singleSelectedMsg != null &&
        currentUserId != null &&
        singleSelectedMsg.senderId == currentUserId &&
        singleSelectedMsg.type == MessageType.text &&
        !singleSelectedMsg.isDeleted &&
        !widget.isGuardian;
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

    final savableMediaMessages = rawMessages.where(
      (m) =>
          _selectedMessageIds.contains(m.id) &&
          !m.isDeleted &&
          !m.isSilentDeleted &&
          (m.type == MessageType.image ||
              m.type == MessageType.video ||
              m.type == MessageType.voice ||
              m.type == MessageType.file ||
              (m.mediaUrl != null && m.mediaUrl!.isNotEmpty)),
    ).toList();
    final canSaveToVault =
        savableMediaMessages.isNotEmpty && _selectedCallIds.isEmpty;

    final downloadableFileMessages = rawMessages.where(
      (m) =>
          _selectedMessageIds.contains(m.id) &&
          !m.isDeleted &&
          !m.isSilentDeleted &&
          (m.type == MessageType.file ||
              m.type == MessageType.image ||
              m.type == MessageType.video ||
              m.type == MessageType.voice) &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty,
    ).toList();
    final canDownload =
        downloadableFileMessages.isNotEmpty && _selectedCallIds.isEmpty;

    return ChatSelectionAppBar(
      selectedCount: selectedCount,
      canReply: canReply,
      canEdit: canEdit,
      hasCopyableText: hasCopyableText,
      canForward: canForward,
      canDownload: canDownload,
      canSaveToVault: canSaveToVault,
      surfaceColor: roomThemeSpec.glassBackgroundColor,
      textColor: roomThemeSpec.textColor,
      iconColor: roomThemeSpec.iconColor,
      onClose: _clearSelection,
      onReply: () => _replyToSelectedMessage(rawMessages),
      onEdit: canEdit
          ? () {
              final msgToEdit = singleSelectedMsg;
              setState(() {
                _editingMessage = msgToEdit;
                _textController.text = msgToEdit.content;
                _replyMessage = null;
                _clearSelection();
              });
              _composerFocusNode.requestFocus();
            }
          : null,
      onCopy: () => _copySelectedMessages(rawMessages),
      onForward: () => _forwardSelectedMessages(
        rawMessages,
        forwardingProtection: forwardingProtection,
      ),
      onDownload: () => _handleDownloadSelectedFiles(downloadableFileMessages),
      onSaveToVault: () => _handleSaveSelectedToVault(savableMediaMessages),
      onDelete: () => _confirmDeleteSelectedItems(rawMessages),
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

  Future<T?> _pushNamedWithoutActiveRoom<T>(
    String routeName, {
    Object? arguments,
  }) async {
    // Kosongkan sementara agar notifikasi pesan masuk tetap berbunyi/muncul
    // saat pengguna berada di layar anak (panggilan, setelan, detail, dsb)
    ref.read(activeRoomIdProvider.notifier).state = null;
    try {
      return await Navigator.pushNamed<T>(
        context,
        routeName,
        arguments: arguments,
      );
    } finally {
      if (mounted) {
        ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
      }
    }
  }

  void _initiateCall(String callType) {
    final currentUserId = ref.read(authProvider).user?.id;
    final otherId = _effectiveOtherUserId;
    if (currentUserId == null || otherId == null) {
      MekaarSnackbar.error(
        context,
        'Panggilan tidak tersedia untuk obrolan ini.',
      );
      return;
    }
    _pushNamedWithoutActiveRoom(
      AppRoutes.call,
      arguments: {
        'roomId': widget.chatId,
        'chatName': _effectiveChatName,
        'callerId': currentUserId,
        'receiverId': otherId,
        'isCaller': true,
        'callType': callType,
      },
    );
  }

  Future<void> _toggleMute() async {
    final targetMuted = !_isMuted;
    setState(() => _isMuted = targetMuted);
    HapticService.trigger(MekaarHapticIntent.selection);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateRoomMute(widget.chatId, targetMuted);
      ref.read(chatRoomsProvider.notifier).refreshRooms();
      if (mounted) {
        MekaarSnackbar.info(
          context,
          targetMuted
              ? 'Notifikasi obrolan dibisukan'
              : 'Notifikasi obrolan diaktifkan',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isMuted = !targetMuted);
        MekaarSnackbar.error(
          context,
          'Gagal mengubah status bisukan: ${ErrorResolver.resolve(e)}',
        );
      }
    }
  }

  void _confirmClearHistory() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Bersihkan Riwayat di Perangkat Ini?',
      message: widget.isGuardian
          ? 'Seluruh riwayat chat akan dibersihkan dari tampilan Anda saja, namun log percakapan tetap diarsipkan demi kepatuhan Room Guardian.'
          : 'Semua pesan di ruangan ini hanya akan dibersihkan dari tampilan Anda. Rekan obrolan tetap dapat melihat riwayat percakapan di perangkat mereka.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            await ref.read(chatActionsProvider).clearChatHistory(widget.chatId);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('hidden_call_ids_${widget.chatId}');
            } catch (_) {}
            if (mounted) {
              setState(() => _hiddenCallIds.clear());
              MekaarSnackbar.success(context, 'Riwayat obrolan & panggilan dibersihkan untuk perangkat ini.');
            }
          },
          child: const Text(
            'Bersihkan (Hanya Saya)',
            style: TextStyle(color: MekaarColors.sosRed),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteChat() {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Percakapan dari Daftar Anda?',
      message:
          'Obrolan ini hanya akan dihapus dari daftar pesan Anda. Percakapan di sisi rekan obrolan tidak akan terhapus.',
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
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('hidden_call_ids_${widget.chatId}');
            } catch (_) {}
            if (!mounted) return;
            Navigator.pop(context); // Exit chat room to ChatListScreen
          },
          child: const Text(
            'Hapus (Hanya Saya)',
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

    // Auto-read listener: saat pengguna aktif di dalam layar dan ada pesan baru masuk dari lawan bicara,
    // langsung tandai telah dibaca secara reaktif agar unread count tidak menumpuk saat keluar.
    ref.listen<AsyncValue<List<Message>>>(
      chatMessagesProvider(widget.chatId),
      (previous, next) {
        final prevList = previous?.valueOrNull;
        final nextList = next.valueOrNull;
        if (nextList != null && nextList.isNotEmpty && currentUserId != null) {
          final hasNewMessages =
              prevList == null || nextList.length > prevList.length;
          final lastIsFromOther = nextList.last.senderId != currentUserId;
          if (hasNewMessages && lastIsFromOther && mounted) {
            actions.markRoomRead(widget.chatId);
          }
        }
      },
    );

    final topAreaHeight =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 6.0;

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
        if (didPop) {
          // Bersihkan status kamar aktif seketika layar mulai keluar (animasi pop)
          ref.read(activeRoomIdProvider.notifier).state = null;
          ref.read(chatActionsProvider).markRoomRead(widget.chatId);
          ref.read(chatRoomsProvider.notifier).refreshRooms();
          if (_burnOnExit) {
            _triggerBurnOnExit();
          }
        }
      },
      child: MekaarScaffold(
        flat: false,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ──── Layer 0: Wallpaper/Background (Scoped Consumer) ────
            Consumer(
              builder: (context, ref, _) {
                final chatPref =
                    ref.watch(chatThemeProvider).valueOrNull ??
                    const ChatThemePreference();
                return _buildWallpaperBackground(chatPref);
              },
            ),

            // ──── Layer 1: Daftar Pesan (Scoped Consumer) ────
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
                  final messagesStream = ref.watch(
                    chatMessagesProvider(widget.chatId),
                  );
                  final reconnecting =
                      ref
                          .watch(chatReconnectingProvider(widget.chatId))
                          .value ??
                      false;
                  final forwardingProtectionAsync = ref.watch(
                    roomForwardingProtectionProvider(widget.chatId),
                  );
                  final forwardingProtection =
                      forwardingProtectionAsync.valueOrNull;

                  return Column(
                    children: [
                      SizedBox(height: topAreaHeight),
                      Expanded(
                        child: Column(
                          children: [
                            // Stale-while-revalidate: selama masih ada data
                            // termuat, jangan collapse ke error view — tampilkan
                            // banner statis 'Mode Offline' saat menyambung ulang / offline.
                            if (messagesStream.hasValue && reconnecting)
                              MekaarBanner.offlineMode(),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  switch (chatMessagesUiMode(messagesStream)) {
                                    case ChatMessagesUiMode.data:
                                      final rawDbMessages =
                                          messagesStream.valueOrNull!;
                                      final nowUtc = DateTime.now().toUtc();
                                      final activeDbMessages = rawDbMessages.where((m) {
                                        if (m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(nowUtc)) {
                                          return false;
                                        }
                                        return true;
                                      }).toList();
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
                                        for (var m in activeDbMessages) m.id,
                                      };
                                      final activePending = pendingMessages
                                          .where((p) =>
                                              !dbIds.contains(p.id) &&
                                              (p.autoDeleteAt == null || p.autoDeleteAt!.isAfter(nowUtc)))
                                          .toList();
                                      final rawMessages = [
                                        ...activeDbMessages,
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
                                      return Builder(
                                        builder: (context) {
                                          final keyboardHeight =
                                              MediaQuery.viewInsetsOf(context)
                                                  .bottom;
                                          return ListView.builder(
                                            controller: _scrollController,
                                            keyboardDismissBehavior:
                                                ScrollViewKeyboardDismissBehavior
                                                    .manual,
                                            reverse: true,
                                            // Padding bawah memberi ruang untuk composer floating + inset keyboard + panel emoji
                                            padding: EdgeInsets.only(
                                              top: 8,
                                              bottom:
                                                  130 +
                                                  math.max(
                                                    keyboardHeight,
                                                    MediaQuery.viewPaddingOf(
                                                      context,
                                                    ).bottom,
                                                  ) +
                                                  emojiInset,
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
                                        },
                                      );
                                    case ChatMessagesUiMode.error:
                                      final isNetworkErr =
                                          ErrorResolver.isNetworkError(
                                        messagesStream.error,
                                      );
                                      return MekaarStateView(
                                        pose: isNetworkErr
                                            ? MikaPose.confused
                                            : ErrorResolver.resolvePose(
                                                messagesStream.error,
                                              ),
                                        title: isNetworkErr
                                            ? 'Mode Offline'
                                            : 'Gagal Memuat',
                                        message: isNetworkErr
                                            ? 'Tidak ada koneksi internet dan belum ada riwayat obrolan tersimpan untuk obrolan ini.'
                                            : ErrorResolver.resolve(
                                                messagesStream.error,
                                              ),
                                        actionLabel: 'Coba Lagi',
                                        onAction: () => ref.invalidate(
                                          chatMessagesProvider(widget.chatId),
                                        ),
                                        icon: isNetworkErr
                                            ? SolarIconsOutline.cloudCross
                                            : SolarIconsOutline.refresh,
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

                    ],
                  );
                },
              ),
            ),

            // ──── Layer 2: Composer Floating (Scoped Consumer) ────
            Positioned(
              left: 0,
              right: 0,
              bottom: math.max(
                MediaQuery.viewInsetsOf(context).bottom,
                MediaQuery.viewPaddingOf(context).bottom,
              ),
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
                  final isComposerEnabled =
                      widget.isGroup || (e2eeStatus == E2eeRoomStatus.ready);
                  final isOtherTyping = ref.watch(
                    typingStateProvider(widget.chatId),
                  );

                  return ChatComposer(
                    key: _composerKey,
                    isOtherTyping: isOtherTyping,
                    e2eeStatus: widget.isGroup ? null : e2eeStatus,
                    onRetryE2ee: () => ref
                        .read(e2eeRoomStatusProvider(widget.chatId).notifier)
                        .retry(isGroup: widget.isGroup),
                    onRestoreE2ee: () => _showE2eeRestoreBottomSheet(context),
                    controller: _textController,
                    focusNode: _composerFocusNode,
                    replyMessage: _replyMessage,
                    replySenderName: _getSenderDisplayName(_replyMessage),
                    editingMessage: _editingMessage,
                    enabled: true,
                    canSend: isComposerEnabled,
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
                    onCancelReply: () => _setReplyMessage(null),
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

            // ──── Layer 5: Scroll-to-bottom button (ValueListenableBuilder) ────
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  math.max(
                    MediaQuery.viewInsetsOf(context).bottom,
                    MediaQuery.viewPaddingOf(context).bottom,
                  ) +
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

            // ──── Layer 4: Custom App Bar Floating Frosted Glass ────
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
                    final nowUtc = DateTime.now().toUtc();
                    final activeDbMessages = rawDbMessages.where((m) {
                      if (m.autoDeleteAt != null && m.autoDeleteAt!.isBefore(nowUtc)) {
                        return false;
                      }
                      return true;
                    }).toList();
                    final pendingMessages = ref.watch(
                      pendingMessagesProvider(widget.chatId),
                    );
                    final dbIds = {for (var m in activeDbMessages) m.id};
                    final activePending = pendingMessages
                        .where((p) =>
                            !dbIds.contains(p.id) &&
                            (p.autoDeleteAt == null || p.autoDeleteAt!.isAfter(nowUtc)))
                        .toList();
                    final rawMessages = [...activeDbMessages, ...activePending];

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
                                _searchDebounceTimer?.cancel();
                                _inChatSearchFocusNode.unfocus();
                                setState(() {
                                  _isSearching = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                key: const ValueKey('in_chat_search_input'),
                                controller: _searchController,
                                focusNode: _inChatSearchFocusNode,
                                textInputAction: TextInputAction.search,
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
                                  _searchDebounceTimer?.cancel();
                                  _searchDebounceTimer = Timer(
                                    const Duration(milliseconds: 180),
                                    () {
                                      if (mounted && _searchQuery != val.trim()) {
                                        setState(() => _searchQuery = val.trim());
                                      }
                                    },
                                  );
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
                        title: _effectiveChatName,
                        avatarInitial: _effectiveAvatarInitial,
                        avatarUrl: _effectiveAvatarUrl,
                        isGuardian: widget.isGuardian,
                        showOnlineIndicator: true,
                        isOnline: isOnline || isTyping,
                        subtitle: widget.isGroup
                            ? '${_participantNames.isNotEmpty ? '${_participantNames.length} anggota • ' : ''}Enkripsi Server'
                            : (isTyping
                                ? 'sedang mengetik...'
                                : _formatPresenceSubtitle(lastSeen)),
                        glassBorder: roomThemeSpec.glassBorder,
                        glassBackgroundColor:
                            roomThemeSpec.glassBackgroundColor,
                        iconColor: roomThemeSpec.iconColor,
                        textColor: roomThemeSpec.textColor,
                        subtitleColor: roomThemeSpec.subtitleColor,
                        onAvatarTap: widget.isGroup
                            ? () => _pushNamedWithoutActiveRoom(
                                AppRoutes.groupDetails,
                                arguments: {
                                  'roomId': widget.chatId,
                                  'groupName': _effectiveChatName,
                                  'groupAvatarUrl': _effectiveAvatarUrl,
                                },
                              )
                            : (_effectiveOtherUserId != null &&
                                    !LocalMessageDatabase.instance.isDecoy &&
                                    widget.chatId != 'room_welcome_mekaar'
                                  ? () => _pushNamedWithoutActiveRoom(
                                      AppRoutes.contactSettings,
                                      arguments: {
                                        'roomId': widget.chatId,
                                        'chatName': _effectiveChatName,
                                        'chatAvatar': _effectiveAvatarInitial,
                                        'otherUserId': _effectiveOtherUserId!,
                                        'isGuardian': widget.isGuardian,
                                      },
                                    )
                                  : null),
                        actions: [
                          if (!LocalMessageDatabase.instance.isDecoy &&
                              widget.chatId != 'room_welcome_mekaar') ...[
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
                          ],
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
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted &&
                                      _inChatSearchFocusNode.canRequestFocus) {
                                    _inChatSearchFocusNode.requestFocus();
                                  }
                                });
                              } else if (value == 'mute') {
                                _toggleMute();
                              } else if (value == 'theme') {
                                _pushNamedWithoutActiveRoom(
                                  AppRoutes.chatThemeSettings,
                                );
                              } else if (value == 'privacy_settings') {
                                ChatRoomPrivacySheet.show(
                                  context,
                                  roomId: widget.chatId,
                                  onSettingsChanged: () {
                                    if (mounted) _loadRoomSettings();
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
                                value: 'mute',
                                child: Row(
                                  children: [
                                    Icon(
                                      _isMuted
                                          ? SolarIconsOutline.volumeLoud
                                          : SolarIconsOutline.volumeCross,
                                      size: 20,
                                      color: textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isMuted
                                          ? 'Bunyikan Notifikasi'
                                          : 'Bisukan Notifikasi',
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
                                      'Bersihkan Riwayat (Hanya Saya)',
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
                                      'Hapus Obrolan (Hanya Saya)',
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

            // ──── Layer 5: Floating Privacy Indicators Capsule (Frosted Glass Capsule) ────
            Positioned(
              top: topAreaHeight + 4,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, _) {
                  final protectionAsync = ref.watch(
                    roomScreenProtectionProvider(widget.chatId),
                  );
                  final forwardingAsync = ref.watch(
                    roomForwardingProtectionProvider(widget.chatId),
                  );
                  final isScreenProtected =
                      protectionAsync.valueOrNull?.effective ?? true;
                  final isForwardingProtected =
                      forwardingAsync.valueOrNull?.effective ?? false;

                  final activeItems = <RoomPrivacyIndicatorItem>[];
                  if (isScreenProtected) {
                    activeItems.add(const RoomPrivacyIndicatorItem(
                      icon: SolarIconsBold.shieldCheck,
                      color: MekaarColors.safeTeal,
                    ));
                  }
                  if (isForwardingProtected) {
                    activeItems.add(const RoomPrivacyIndicatorItem(
                      icon: SolarIconsBold.forbiddenCircle,
                      color: MekaarColors.blue,
                    ));
                  }
                  if (_isViewOnce) {
                    activeItems.add(const RoomPrivacyIndicatorItem(
                      icon: SolarIconsBold.eyeClosed,
                      color: MekaarColors.blue,
                    ));
                  }
                  if (_autoDeleteHours > 0) {
                    activeItems.add(const RoomPrivacyIndicatorItem(
                      icon: SolarIconsBold.history,
                      color: MekaarColors.warnAmber,
                    ));
                  }
                  if (_scheduledWipeMode != 'off') {
                    activeItems.add(const RoomPrivacyIndicatorItem(
                      icon: SolarIconsBold.clockCircle,
                      color: MekaarColors.warnAmber,
                    ));
                  }
                  if (_burnOnExit) {
                    activeItems.add(const RoomPrivacyIndicatorItem(
                      icon: SolarIconsBold.fire,
                      color: MekaarColors.sosCoral,
                    ));
                  }

                  if (activeItems.isEmpty) return const SizedBox.shrink();

                  return Center(
                    child: RoomPrivacyIndicatorCapsule(
                      items: activeItems,
                      onTap: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        ChatRoomPrivacySheet.show(
                          context,
                          roomId: widget.chatId,
                          onSettingsChanged: () {
                            if (mounted) {
                              _loadRoomSettings();
                            }
                          },
                        );
                      },
                    ),
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
    // Pada ListView(reverse: true), index yang lebih tinggi dirender di posisi ATAS layar.
    // Karena combinedRaw diurutkan descending (terbaru ke terlama), pesan-pesan suatu hari
    // harus ditambahkan terlebih dahulu (index lebih rendah), lalu pemisah tanggal ditambahkan
    // setelah pesan terakhir hari itu (index lebih tinggi), sehingga pemisah tanggal
    // secara visual konsisten tampil di ATAS rentetan pesan pada hari tersebut.
    final entries = <_ChatItemEntry>[];

    for (var i = 0; i < combinedRaw.length; i++) {
      final item = combinedRaw[i];
      entries.add(item);

      final localCreatedAt = item.timestamp.toLocal();
      final itemDate = DateTime(
        localCreatedAt.year,
        localCreatedAt.month,
        localCreatedAt.day,
      );

      final isLastItem = i == combinedRaw.length - 1;
      if (isLastItem) {
        entries.add(_ChatItemEntry.dateSeparator(localCreatedAt));
      } else {
        final nextLocalCreatedAt = combinedRaw[i + 1].timestamp.toLocal();
        final nextItemDate = DateTime(
          nextLocalCreatedAt.year,
          nextLocalCreatedAt.month,
          nextLocalCreatedAt.day,
        );
        if (itemDate != nextItemDate) {
          entries.add(_ChatItemEntry.dateSeparator(localCreatedAt));
        }
      }
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
        replyToSender = _getSenderDisplayName(replyToMsg);
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
      onReply: (replyMsg) => _setReplyMessage(replyMsg),
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
      onSaveToVault: (saveMsg) => _handleSaveToVault(saveMsg),
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
              onReply: () => _setReplyMessage(msg),
              onDelete: () => _confirmDeleteSingleMessage(msg),
              child: bubbleWithPill,
            ),
    );
  }

  Widget _buildWallpaperBackground(ChatThemePreference pref) {
    return ChatPresetResolver.buildWallpaper(pref, context);
  }
}

/// Alias backward-compatibility untuk ChatSwipeActionWrapper
typedef _SwipeActionWrapper = ChatSwipeActionWrapper;

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
