import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_composer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final bool isGuardian;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.isGuardian = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isViewOnce = false;
  Message? _replyMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chatActionsProvider).markRoomRead(widget.chatId),
    );
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

    // Scroll to bottom
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref.watch(chatMessagesProvider(widget.chatId));

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.chatName,
        avatarInitial: widget.chatAvatar,
        isGuardian: widget.isGuardian,
        showOnlineIndicator: true,
        isOnline: true,
        actions: [
          if (widget.isGuardian) ...[
            IconButton(
              icon: const Icon(
                Icons.phone_outlined,
                color: MekaarColors.softCoral,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(
                Icons.videocam_outlined,
                color: MekaarColors.softCoral,
              ),
              onPressed: () {},
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesStream.when(
              data: (messages) {
                // Reverse message order to align with bottom list
                final reversed = messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: reversed.length,
                  itemBuilder: (context, index) {
                    final msg = reversed[index];
                    final isMe =
                        msg.senderId == ref.read(authProvider).user?.id;
                    return ChatBubble(
                      message: msg,
                      isMe: isMe,
                      canDelete: isMe,
                      onDelete: () => _handleDeleteMessage(msg),
                      onReply: (replyMsg) {
                        setState(() => _replyMessage = replyMsg);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Gagal memuat pesan: $err')),
            ),
          ),
          ChatComposer(
            controller: _textController,
            replyMessage: _replyMessage,
            isViewOnce: _isViewOnce,
            onSend: _handleSend,
            onToggleViewOnce: _toggleViewOnce,
            onCancelReply: () => setState(() => _replyMessage = null),
          ),
        ],
      ),
    );
  }
}
