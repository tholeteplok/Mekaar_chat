import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart' as loc;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_composer.dart';
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


  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    Future.microtask(() async {
      ref.read(chatActionsProvider).markRoomRead(widget.chatId);
      final repo = ref.read(chatRepositoryProvider);
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

  /// Build presence subtitle: typing > online (< 5 min) > last seen > empty
  String _buildPresenceSubtitle() {
    if (_partnerIsTyping) return 'sedang mengetik...';
    if (_otherLastSeen == null) return 'Online';
    final diff = DateTime.now().difference(_otherLastSeen!);
    if (diff.inMinutes < 5) return 'Online';
    if (diff.inMinutes < 60) return 'Terakhir dilihat ${diff.inMinutes} menit lalu';
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
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final actions = ref.read(chatActionsProvider);

    if (_editingMessage != null) {
      await actions.editMessage(_editingMessage!.id, text);
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
      await ref.read(chatActionsProvider).sendMessage(
        widget.chatId,
        '',
        mediaUrl: url,
        type: type,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim media: $e')),
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

      await ref.read(chatActionsProvider).sendMessage(
        widget.chatId,
        '$lat, $lng',
        type: MessageType.location,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
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
        const SnackBar(content: Text('Panggilan tidak tersedia untuk obrolan ini.')),
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
      message: 'Apakah Anda yakin ingin menghapus seluruh obrolan ini? Obrolan akan hilang dari daftar chat Anda.',
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
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);

    return Scaffold(
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
              Icons.phone_outlined,
              color: MekaarColors.softCoral,
            ),
            onPressed: () => _initiateCall('voice'),
            tooltip: 'Panggilan Suara',
          ),
          // Actions Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: MekaarColors.softCoral,
            ),
            onSelected: (value) {
              if (value == 'video') {
                _initiateCall('video');
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
                    Icon(Icons.videocam_outlined, size: 20, color: MekaarColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Panggilan Video'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20, color: MekaarColors.textPrimary),
                    SizedBox(width: 8),
                    Text('Bersihkan Riwayat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: MekaarColors.sosRed),
                    SizedBox(width: 8),
                    Text('Hapus Chat', style: TextStyle(color: MekaarColors.sosRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
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
                      onDelete: () => _handleDeleteMessage(msg),
                      onReply: (replyMsg) {
                        setState(() {
                          _replyMessage = replyMsg;
                          _editingMessage = null;
                        });
                      },
                      onEdit: (editMsg, newContent) {
                        ref
                            .read(chatActionsProvider)
                            .editMessage(editMsg.id, newContent);
                      },
                      onForward: (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Fitur teruskan segera hadir!')),
                        );
                      },
                      onReact: (reactMsg, emoji) =>
                          _handleReactToMessage(reactMsg, emoji),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Gagal memuat pesan: $err')),
            ),
          ),
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
          ),
        ],
      ),
    );
  }
}
