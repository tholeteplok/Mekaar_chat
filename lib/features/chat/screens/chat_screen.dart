import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/screen_protection_widgets.dart';
import '../../../data/repositories/forwarding_protection_repository.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_draft_provider.dart';
import '../../../data/services/local_message_database.dart';
import '../providers/forwarding_protection_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../controllers/chat_screen_controller.dart';
import '../dialogs/chat_deletion_dialogs.dart';
import '../handlers/chat_media_handler.dart';
import '../handlers/chat_file_action_handler.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_bottom_area.dart';
import '../widgets/chat_message_list_view.dart';
import '../widgets/chat_forward_sheet.dart';
import '../widgets/chat_e2ee_restore_sheet.dart';
import '../widgets/chat_room_privacy_sheet.dart';
import '../providers/e2ee_room_status_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/call_model.dart';
import '../../../data/repositories/call_repository.dart';

export '../widgets/chat_reconnecting_badge.dart';
export '../widgets/chat_swipe_action_wrapper.dart';
export '../widgets/chat_message_list_view.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final String? chatAvatarUrl;
  final bool isGuardian;
  final bool isGroup;
  final String? otherUserId;
  final String? initialSharedText;
  final List<String>? initialSharedFiles;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.chatName = '',
    this.chatAvatar = '',
    this.chatAvatarUrl,
    this.isGuardian = false,
    this.isGroup = false,
    this.otherUserId,
    this.initialSharedText,
    this.initialSharedFiles,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  late final ChatScreenController _controller;
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
  bool _isEmojiPickerOpen = false;
  bool _wasKeyboardOpenOnPause = false;
  Message? _replyMessage;
  Message? _editingMessage;
  final Set<String> _selectedMessageIds = <String>{};
  final Set<String> _selectedCallIds = <String>{};
  Set<String> _hiddenCallIds = <String>{};
  String? _reactionAnchorMessageId;

  int get _autoDeleteHours => _controller.autoDeleteHours;
  bool get _burnOnExit => _controller.burnOnExit;
  String get _scheduledWipeMode => _controller.scheduledWipeMode;
  DateTime? get _scheduledWipeTargetAt => _controller.scheduledWipeTargetAt;
  bool get _isViewOnce => _controller.isViewOnce;
  set _isViewOnce(bool val) => _controller.setViewOnce(val);
  bool get _isMuted => _controller.isMuted;
  set _isMuted(bool val) => _controller.setMuted(val);

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
  final ValueNotifier<bool> _showScrollButton = ValueNotifier<bool>(false);
  final ValueNotifier<int> _newMessageCount = ValueNotifier<int>(0);
  Map<String, String> _participantNames = {};

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
          _controller.startPresenceHeartbeat();
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
          _controller.startPresenceHeartbeat();
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

  @override
  void initState() {
    super.initState();
    _inChatSearchFocusNode = FocusNode();
    _composerFocusNode = FocusNode();
    _controller = ChatScreenController(
      chatId: widget.chatId,
      effectiveOtherUserId: widget.otherUserId,
      getOtherUserId: () => _effectiveOtherUserId,
      ref: ref,
      composerFocusNode: _composerFocusNode,
      isKeyboardVisible: () =>
          (MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0) > 0,
      isMounted: () => mounted,
      otherLastSeenNotifier: _otherLastSeenNotifier,
    );
    _controller.addListener(_onControllerChanged);
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

        if (widget.initialSharedFiles != null &&
            widget.initialSharedFiles!.isNotEmpty) {
          _handleInitialSharedFiles(widget.initialSharedFiles!);
        }
      }
    });
    _controller.start();
    _resolveMissingRoomMetadata();
    _loadHiddenCalls();

    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);

      await _controller.loadRoomSettings();

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

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _restoreDraftAndListenText() {
    if (widget.initialSharedText != null &&
        widget.initialSharedText!.trim().isNotEmpty) {
      _textController.text = widget.initialSharedText!.trim();
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else {
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
    }
    _textController.addListener(_onTextChanged);
  }


  Future<void> _loadRoomSettings() => _controller.loadRoomSettings();

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
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

  Future<void> _triggerBurnOnExit() => _controller.triggerBurnOnExit();

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

  Future<void> _handleInitialSharedFiles(List<String> filePaths) =>
      ChatMediaHandler.handleInitialSharedFiles(
        context,
        ref: ref,
        filePaths: filePaths,
        onSendMedia: _handleSendMedia,
      );

  Future<void> _handleSendMedia(
    File file,
    MessageType type, {
    String? caption,
    bool? isViewOnce,
  }) =>
      ChatMediaHandler.sendMedia(
        context,
        ref: ref,
        chatId: widget.chatId,
        isGroup: widget.isGroup,
        otherUserId: _effectiveOtherUserId,
        file: file,
        type: type,
        caption: caption,
        isViewOnce: isViewOnce ?? _isViewOnce,
        replyMessage: _replyMessage,
        autoDeleteHours: _autoDeleteHours,
        scheduledWipeTargetAt: _scheduledWipeTargetAt,
        onScrollToBottom: _scrollToBottom,
        onAfterSend: () {
          if (mounted && _replyMessage != null) {
            setState(() => _replyMessage = null);
          }
        },
      );

  Future<void> _handleSendLocation() => ChatMediaHandler.sendLocation(
        context,
        ref: ref,
        chatId: widget.chatId,
        isGroup: widget.isGroup,
        autoDeleteHours: _autoDeleteHours,
        scheduledWipeTargetAt: _scheduledWipeTargetAt,
        onScrollToBottom: _scrollToBottom,
      );

  Future<void> _handleShareLiveLocation(int durationMinutes) =>
      ChatMediaHandler.shareLiveLocation(
        context,
        ref: ref,
        chatId: widget.chatId,
        durationMinutes: durationMinutes,
      );


  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: MekaarMotion.counter,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showE2eeRestoreBottomSheet(BuildContext context) =>
      ChatE2eeRestoreSheet.show(
        context,
        ref: ref,
        roomId: widget.chatId,
        isGroup: widget.isGroup,
      );

  void _handleDeleteMessage(Message msg) {
    ChatDeletionDialogs.confirmDeleteSingleMessage(
      context,
      ref: ref,
      roomId: widget.chatId,
      message: msg,
    );
  }

  void _handleUnsendMessage(Message msg) {
    ChatDeletionDialogs.confirmUnsingleMessage(
      context,
      ref: ref,
      roomId: widget.chatId,
      message: msg,
      isGuardian: widget.isGuardian,
    );
  }

  void _handleReactToMessage(Message msg, String emoji) {
    ref.read(chatActionsProvider).reactToMessage(msg.id, emoji);
  }

  Future<void> _handleSaveToVault(Message msg) =>
      ChatFileActionHandler.saveToVault(
        context,
        ref: ref,
        roomId: widget.chatId,
        message: msg,
        isGroup: widget.isGroup,
        participantNames: _participantNames,
        effectiveChatName: _effectiveChatName,
      );

  Future<void> _handleDownloadSelectedFiles(
          List<Message> downloadableMessages) =>
      ChatFileActionHandler.downloadSelectedFiles(
        context,
        downloadableMessages: downloadableMessages,
        onCompleted: _clearSelection,
      );

  Future<void> _handleSaveSelectedToVault(List<Message> savableMessages) =>
      ChatFileActionHandler.saveSelectedToVault(
        context,
        ref: ref,
        roomId: widget.chatId,
        savableMessages: savableMessages,
        isGroup: widget.isGroup,
        participantNames: _participantNames,
        effectiveChatName: _effectiveChatName,
        onCompleted: _clearSelection,
      );

  void _handleForwardMessage(Message msg) {
    ChatForwardSheet.show(
      context,
      ref: ref,
      currentRoomId: widget.chatId,
      messages: [msg],
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
    final selectedMsgs = allMessages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();
    ChatDeletionDialogs.confirmDeleteSelectedItems(
      context,
      ref: ref,
      roomId: widget.chatId,
      otherParticipantName: _effectiveChatName,
      isGroup: widget.isGroup,
      selectedMessages: selectedMsgs,
      selectedCallIds: _selectedCallIds,
      onHideCalls: _hideSelectedCalls,
      onSelectionCleared: _clearSelection,
    );
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

    ChatForwardSheet.show(
      context,
      ref: ref,
      currentRoomId: widget.chatId,
      messages: selectedMsgs,
      onForwardCompleted: _clearSelection,
    );
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
    ChatDeletionDialogs.confirmClearHistory(
      context,
      ref: ref,
      roomId: widget.chatId,
      isGuardian: widget.isGuardian,
      onCleared: () {
        if (mounted) {
          setState(() => _hiddenCallIds.clear());
        }
      },
    );
  }

  void _confirmDeleteChat() {
    ChatDeletionDialogs.confirmDeleteChat(
      context,
      ref: ref,
      roomId: widget.chatId,
      onDeleted: () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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

            // ──── Layer 1: Feed Pesan & Scroll Button (ChatMessageListView) ────
            Positioned.fill(
              child: ChatMessageListView(
                chatId: widget.chatId,
                isGroup: widget.isGroup,
                isGuardian: widget.isGuardian,
                topAreaHeight: topAreaHeight,
                searchQuery: _searchQuery,
                scrollController: _scrollController,
                isEmojiPickerOpen: _isEmojiPickerOpen,
                hiddenCallIds: _hiddenCallIds,
                otherLastRead: _otherLastRead,
                selectedMessageIds: _selectedMessageIds,
                selectedCallIds: _selectedCallIds,
                reactionAnchorMessageId: _reactionAnchorMessageId,
                participantNames: _participantNames,
                showScrollButton: _showScrollButton,
                newMessageCount: _newMessageCount,
                onScrollToBottom: _scrollToBottom,
                onToggleMessageSelection: _toggleMessageSelection,
                onMessageLongPress: _handleMessageLongPress,
                onToggleCallSelection: _toggleCallSelection,
                onCallLongPress: _handleCallLongPress,
                onInitiateCall: _initiateCall,
                onDeleteSingleCall: _confirmDeleteSingleCall,
                onDeleteMessage: _handleDeleteMessage,
                onSwipeDeleteMessage: _confirmDeleteSingleMessage,
                onUnsendMessage: _handleUnsendMessage,
                onReplyMessage: _setReplyMessage,
                onForwardMessage: _handleForwardMessage,
                onReactToMessage: (msg, emoji) {
                  _handleReactToMessage(msg, emoji);
                  _clearSelection();
                },
                onSaveToVault: _handleSaveToVault,
                getSenderDisplayName: _getSenderDisplayName,
              ),
            ),

            // ──── Layer 2: Composer Floating (ChatBottomArea) ────
            Positioned(
              left: 0,
              right: 0,
              bottom: math.max(
                MediaQuery.viewInsetsOf(context).bottom,
                MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: ChatBottomArea(
                chatId: widget.chatId,
                isGroup: widget.isGroup,
                composerKey: _composerKey,
                textController: _textController,
                composerFocusNode: _composerFocusNode,
                replyMessage: _replyMessage,
                replySenderName: _getSenderDisplayName(_replyMessage),
                editingMessage: _editingMessage,
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
                onRestoreE2ee: () => _showE2eeRestoreBottomSheet(context),
              ),
            ),

            // ──── Layer 4: Custom App Bar Floating Frosted Glass (ChatAppBar) ────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Consumer(
                builder: (context, ref, _) {
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

                  return ChatAppBar(
                    chatId: widget.chatId,
                    chatName: _effectiveChatName,
                    avatarInitial: _effectiveAvatarInitial,
                    avatarUrl: _effectiveAvatarUrl,
                    isGuardian: widget.isGuardian,
                    isGroup: widget.isGroup,
                    otherUserId: _effectiveOtherUserId,
                    participantCount: _participantNames.length,
                    otherLastSeenNotifier: _otherLastSeenNotifier,
                    isMuted: _isMuted,
                    // Mode Seleksi Pesan
                    isSelectionMode: _isSelectionMode,
                    totalSelectedCount: _totalSelectedCount,
                    selectedMessageIds: _selectedMessageIds,
                    selectedCallIds: _selectedCallIds,
                    rawMessages: rawMessages,
                    forwardingProtection: forwardingProtection,
                    onClearSelection: _clearSelection,
                    onReplySelectedMessage: () => _replyToSelectedMessage(rawMessages),
                    onEditSelectedMessage: (msgToEdit) {
                      setState(() {
                        _editingMessage = msgToEdit;
                        _textController.text = msgToEdit.content;
                        _replyMessage = null;
                        _clearSelection();
                      });
                      _composerFocusNode.requestFocus();
                    },
                    onCopySelectedMessages: () => _copySelectedMessages(rawMessages),
                    onForwardSelectedMessages: () => _forwardSelectedMessages(
                      rawMessages,
                      forwardingProtection: forwardingProtection,
                    ),
                    onDownloadSelectedFiles: _handleDownloadSelectedFiles,
                    onSaveSelectedToVault: _handleSaveSelectedToVault,
                    onDeleteSelectedMessages: _confirmDeleteSelectedItems,
                    // Mode Pencarian
                    isSearching: _isSearching,
                    searchQuery: _searchQuery,
                    searchController: _searchController,
                    inChatSearchFocusNode: _inChatSearchFocusNode,
                    onCloseSearch: () {
                      _searchDebounceTimer?.cancel();
                      _inChatSearchFocusNode.unfocus();
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    onSearchChanged: (val) {
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
                    onClearSearchQuery: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    // Aksi Menu & Kontak
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
                            : () {}),
                    onInitiateCall: _initiateCall,
                    onMenuActionSelected: (value) async {
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

  Widget _buildWallpaperBackground(ChatThemePreference pref) {
    return ChatPresetResolver.buildWallpaper(pref, context);
  }
}
