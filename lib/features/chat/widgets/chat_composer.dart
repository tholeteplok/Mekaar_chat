import 'package:flutter/material.dart';
import '../../../data/models/message_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';

class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final Message? replyMessage;
  final bool isViewOnce;
  final VoidCallback onSend;
  final VoidCallback onToggleViewOnce;
  final VoidCallback onCancelReply;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.replyMessage,
    required this.isViewOnce,
    required this.onSend,
    required this.onToggleViewOnce,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyMessage != null)
          _ReplyPreview(message: replyMessage!, onCancel: onCancelReply),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.lg,
            vertical: MekaarSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: MekaarColors.surface,
            border: Border(
              top: BorderSide(color: MekaarColors.borderLight, width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.visibility_outlined,
                  color: isViewOnce
                      ? MekaarColors.softCoral
                      : MekaarColors.textMuted,
                ),
                onPressed: onToggleViewOnce,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: MekaarColors.surface2,
                    borderRadius: BorderRadius.circular(MekaarRadius.xl),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: MekaarSpacing.lg,
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: MekaarSpacing.md,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: MekaarSpacing.sm),
              Semantics(
                button: true,
                label: 'Kirim pesan',
                child: GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: MekaarSizes.composerButton,
                    height: MekaarSizes.composerButton,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MekaarColors.textPrimary,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: MekaarSizes.iconSm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final Message message;
  final VoidCallback onCancel;

  const _ReplyPreview({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MekaarSpacing.lg,
        vertical: MekaarSpacing.sm,
      ),
      color: MekaarColors.surface2,
      child: Row(
        children: [
          const Icon(
            Icons.reply,
            size: MekaarSizes.iconSm,
            color: MekaarColors.textSecondary,
          ),
          const SizedBox(width: MekaarSpacing.sm),
          Expanded(
            child: Text(
              'Membalas: ${message.content}',
              style: const TextStyle(
                fontSize: 12,
                color: MekaarColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: MekaarSizes.iconSm),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
