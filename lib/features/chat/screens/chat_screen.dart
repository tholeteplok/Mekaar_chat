import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:location/location.dart' as loc;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/screen_protection_widgets.dart';
import '../providers/chat_provider.dart';
import '../providers/screen_protection_provider.dart';
import '../widgets/chat_composer.dart';
import '../widgets/typing_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/media_upload_service.dart';
import '../../../core/routes/app_routes.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final bool isGuardian;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.isGuardian = false,
    this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isViewOnce = false;
  Message? _replyMessage;
  Message? _editingMessage;
  DateTime? _otherLastRead;
  DateTime? _otherLastSeen;
  // ignore: prefer_final_fields — mutable: updated when partner sends typing event
  bool _partnerIsTyping = false;
  int _autoDeleteHours = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    // Tandai room ini sebagai aktif agar listener notifikasi pesan tahu
    // untuk tidak memunculkan notif saat user sedang melihat percakapan.
    ref.read(activeRoomIdProvider.notifier).state = widget.chatId;
    // Default Pesan Menghilang diambil dari preferensi pengguna.
    _autoDeleteHours =
        ref.read(authProvider).profile?.autoDeleteDefaultHours ?? 0;
    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);
      // Best-effort purge pesan kedaluwarsa (authoritative via cron Supabase).
      try {
        await repo.purgeExpiredMessages();
      } catch (_) {}
      _otherLastRead = await repo.getOtherParticipantLastRead(widget.chatId);
      // Fetch other user's last_seen_at for presence subtitle
      if (widget.otherUserId != null) {
        _otherLastSeen = await repo.getLastSeen(widget.otherUserId!);
      }
      repo.updateLastSeen();
      if (mounted) setState(() {});
    });
  }

  void _onTextChanged() {
    // Local typing indicator — broadcast event to partner via Realtime
    // For now set local state only; Realtime Broadcast can be wired later
    // without changing the UI contract.
    final isTyping = _textController.text.isNotEmpty;
    ref.read(typingStateProvider(widget.chatId).notifier).setTyping(isTyping);
  }

  /// Build presence subtitle: typing > online (< 5 min) > last seen > hidden
  String _buildPresenceSubtitle() {
    if (_partnerIsTyping) return 'sedang mengetik...';
    // Jika null, bisa jadi belum pernah online ATAU pengguna menyembunyikan
    // "terakhir dilihat" (enforce di server via get_last_seen_for). Sembunyikan
    // detail demi privasi.
    if (_otherLastSeen == null) return '';
    final diff = DateTime.now().difference(_otherLastSeen!);
    if (diff.inMinutes < 5) return 'Online';
    if (diff.inMinutes < 60) {
      return 'Terakhir dilihat ${diff.inMinutes} menit lalu';
    }
    if (diff.inHours < 24) return 'Terakhir dilihat ${diff.inHours} jam lalu';
    final days = diff.inDays;
    if (days == 1) return 'Terakhir dilihat kemarin';
    return 'Terakhir dilihat $days hari lalu';
  }

  bool get _isCurrentlyOnline {
    if (_otherLastSeen == null) return false;
    return DateTime.now().difference(_otherLastSeen!).inMinutes < 5;
  }

  @override
  void dispose() {
    // Bersihkan penanda room aktif agar notif pesan kembali aktif
    // saat user meninggalkan percakapan ini.
    if (ref.read(activeRoomIdProvider) == widget.chatId) {
      ref.read(activeRoomIdProvider.notifier).state = null;
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final actions = ref.read(chatActionsProvider);

    if (_editingMessage != null) {
      if (!actions.canEdit(
        _editingMessage!,
        isGuardianRoom: widget.isGuardian,
      )) {
        _textController.clear();
        setState(() => _editingMessage = null);
        return;
      }
      await actions.editMessage(
        _editingMessage!.id,
        text,
        isGuardianRoom: widget.isGuardian,
      );
      _textController.clear();
      setState(() => _editingMessage = null);
      return;
    }

    await actions.sendMessage(
      widget.chatId,
      text,
      type: MessageType.text,
      isViewOnce: _isViewOnce,
      replyToId: _replyMessage?.id,
      autoDeleteHours: _autoDeleteHours,
    );

    _textController.clear();
    setState(() {
      _isViewOnce = false;
      _replyMessage = null;
    });

    _scrollToBottom();
  }

  Future<void> _handleSendMedia(File file, MessageType type) async {
    try {
      final uploader = MediaUploadService(Supabase.instance.client);
      final url = await uploader.uploadChatMedia(file, widget.chatId);
      await ref
          .read(chatActionsProvider)
          .sendMessage(
            widget.chatId,
            '',
            mediaUrl: url,
            type: type,
            autoDeleteHours: _autoDeleteHours,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim media: $e')));
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
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
      }
    }
  }

  Future<void> _handleShareLiveLocation(int durationMinutes) async {
    try {
      await ref
          .read(chatActionsProvider)
          .shareLiveLocation(widget.chatId, durationMinutes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lokasi live dibagikan selama $durationMinutes menit',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan lokasi live: $e')),
        );
      }
    }
  }

  void _handleDeleteMessage(Message msg) {
    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Hapus Pesan?',
      message: widget.isGuardian
          ? 'Konten pesan akan hilang dari layar. Log sistem tetap mencatat snapshot penghapusan demi integritas bukti.'
          : 'Pesan akan disembunyikan untuk Anda dan tetap tercatat sebagai soft-delete.',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(chatActionsProvider).deleteMessage(msg.id);
            if (!mounted) return;
            Navigator.pop(context);
          },
          child: const Text(
            'Hapus',
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (targets.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tidak ada chat lain untuk meneruskan pesan.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Teruskan ke',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...targets.map((room) {
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
                  await ref
                      .read(chatActionsProvider)
                      .forwardMessage(msg, room['id'] as String);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Pesan diteruskan ke $name')),
                    );
                  }
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _toggleViewOnce() {
    setState(() => _isViewOnce = !_isViewOnce);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isViewOnce
              ? 'Mode Sekali Lihat Aktif (Media akan hilang setelah dibuka).'
              : 'Mode Sekali Lihat Dinonaktifkan.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _initiateCall(String callType) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null || widget.otherUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Panggilan tidak tersedia untuk obrolan ini.'),
        ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Riwayat obrolan dibersihkan.')),
            );
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
    final messagesStream = ref.watch(chatMessagesProvider(widget.chatId));
    final protectionAsync = ref.watch(
      roomScreenProtectionProvider(widget.chatId),
    );
    final protection = protectionAsync.valueOrNull;
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);

    return MekaarScaffold(
      appBar: CustomAppBar(
        title: widget.chatName,
        avatarInitial: widget.chatAvatar,
        isGuardian: widget.isGuardian,
        showOnlineIndicator: true,
        isOnline: _isCurrentlyOnline || _partnerIsTyping,
        subtitle: _buildPresenceSubtitle(),
        actions: [
          // Voice Call icon
          IconButton(
            icon: const Icon(
              SolarIconsOutline.phone,
              color: MekaarColors.softCoral,
            ),
            onPressed: () => _initiateCall('voice'),
            tooltip: 'Panggilan Suara',
          ),
          // Actions Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(
              SolarIconsOutline.menuDots,
              color: MekaarColors.softCoral,
            ),
            onSelected: (value) async {
              if (value == 'video') {
                _initiateCall('video');
              } else if (value == 'screen_protection') {
                final nextValue = !(protection?.callerEnabled ?? true);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(screenProtectionControllerProvider)
                      .setRoomPreference(widget.chatId, nextValue);
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pengaturan proteksi belum dapat disinkronkan',
                      ),
                    ),
                  );
                }
              } else if (value == 'clear') {
                _confirmClearHistory();
              } else if (value == 'delete') {
                _confirmDeleteChat();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'video',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.videocamera,
                      size: 20,
                      color: MekaarColors.textPrimary,
                    ),
                    SizedBox(width: 8),
                    Text('Panggilan Video'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'screen_protection',
                child: Row(
                  children: [
                    const Icon(
                      SolarIconsOutline.shieldCheck,
                      size: 20,
                      color: MekaarColors.safeTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      protection?.callerEnabled == true
                          ? 'Nonaktifkan preferensi saya'
                          : 'Aktifkan proteksi layar',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.trashBinMinimalistic,
                      size: 20,
                      color: MekaarColors.textPrimary,
                    ),
                    SizedBox(width: 8),
                    Text('Bersihkan Riwayat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.trashBinMinimalistic,
                      size: 20,
                      color: MekaarColors.sosRed,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Hapus Chat',
                      style: TextStyle(color: MekaarColors.sosRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          if (protection?.effective ?? true)
            ScreenProtectionStatusBadge(
              label: protection?.statusLabel ?? 'Proteksi ruang aktif',
            ),
          Expanded(
            child: messagesStream.when(
              data: (messages) {
                final reversed = messages.reversed.toList();
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: reversed.length,
                  itemBuilder: (context, index) {
                    final msg = reversed[index];
                    final isMe = msg.senderId == currentUserId;
                    final canEdit = actions.canEdit(
                      msg,
                      isGuardianRoom: widget.isGuardian,
                    );
                    return ChatBubble(
                      message: msg,
                      isMe: isMe,
                      canDelete: isMe,
                      canEdit: isMe && canEdit,
                      canForward: actions.canForward(msg),
                      otherLastReadAt: _otherLastRead,
                      showReadReceipts:
                          ref
                              .watch(authProvider)
                              .profile
                              ?.readReceiptsEnabled ??
                          true,
                      onDelete: () => _handleDeleteMessage(msg),
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
                      onForward: (forwardMsg) =>
                          _handleForwardMessage(forwardMsg),
                      onReact: (reactMsg, emoji) =>
                          _handleReactToMessage(reactMsg, emoji),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Gagal memuat pesan: $err')),
            ),
          ),
          if (_partnerIsTyping) const TypingIndicator(),
          ChatComposer(
            controller: _textController,
            replyMessage: _replyMessage,
            editingMessage: _editingMessage,
            isViewOnce: _isViewOnce,
            onSend: _handleSend,
            onToggleViewOnce: _toggleViewOnce,
            onCancelReply: () => setState(() => _replyMessage = null),
            onCancelEdit: () {
              setState(() => _editingMessage = null);
              _textController.clear();
            },
            onSendMedia: _handleSendMedia,
            onSendLocation: _handleSendLocation,
            onShareLiveLocation: _handleShareLiveLocation,
            autoDeleteHours: _autoDeleteHours,
            onAutoDeleteChanged: (hours) =>
                setState(() => _autoDeleteHours = hours),
          ),
        ],
      ),
    );
  }
}
