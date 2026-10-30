import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/scroll_to_bottom_button.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/chat_date_separator.dart';
import '../../../core/utils/error_resolver.dart';
import '../../../data/models/call_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../../data/repositories/forwarding_protection_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/forwarding_protection_provider.dart';
import 'call_history_bubble.dart';
import 'chat_floating_reaction_pill.dart';
import 'message_flash.dart';
import 'chat_swipe_action_wrapper.dart';
import 'chat_unread_divider.dart';

/// Jenis entri tampilan dalam daftar obrolan.
enum ChatItemKind { message, call, dateSeparator, unreadDivider }

/// Model pembungkus entri daftar obrolan untuk rendering performan O(N).
class ChatItemEntry {
  final ChatItemKind kind;
  final Message? message;
  final CallModel? call;
  final DateTime? date;
  final int? unreadCount;

  const ChatItemEntry.message(this.message)
    : kind = ChatItemKind.message,
      unreadCount = null,
      call = null,
      date = null;

  const ChatItemEntry.call(this.call)
    : kind = ChatItemKind.call,
      unreadCount = null,
      message = null,
      date = null;

  const ChatItemEntry.dateSeparator(this.date)
    : kind = ChatItemKind.dateSeparator,
      unreadCount = null,
      message = null,
      call = null;

  const ChatItemEntry.unreadDivider(this.unreadCount, DateTime anchor)
    : kind = ChatItemKind.unreadDivider,
      message = null,
      call = null,
      date = anchor;

  DateTime get timestamp {
    if (kind == ChatItemKind.message) return message!.createdAt;
    if (kind == ChatItemKind.call) return call!.createdAt;
    return date ?? DateTime.now();
  }
}

/// Mode tampilan daftar pesan (murni, stale-while-revalidate).
enum ChatMessagesUiMode { data, error, loading }

/// Menentukan mode UI daftar pesan berdasarkan status stream.
ChatMessagesUiMode chatMessagesUiMode(AsyncValue<List<Message>> stream) {
  if (stream.hasValue) return ChatMessagesUiMode.data;
  if (stream.hasError) return ChatMessagesUiMode.error;
  return ChatMessagesUiMode.loading;
}

/// Widget feed pesan tengah untuk layar obrolan.
///
/// Mengisolasi:
/// 1. ListView.builder (reverse: true) dengan dynamic padding bottom (IME + emoji panel).
/// 2. Penyusunan entri dan pemisah tanggal cerdas (buildItemEntries).
/// 3. Routing lazy bubble: ChatDateSeparator, CallHistoryBubble, ChatBubble.
/// 4. Overlay tombol floating reaksi pesan terpilih (ChatFloatingReactionPill).
/// 5. Tombol scroll ke bawah dengan indikator pesan baru (ScrollToBottomButton).
/// 6. Penanganan state kosong, pencarian kosong, banner offline, dan error resolver.
class ChatMessageListView extends ConsumerWidget {
  final String chatId;
  final bool isGroup;
  final bool isGuardian;
  final double topAreaHeight;
  final String searchQuery;
  final ScrollController scrollController;
  final bool isEmojiPickerOpen;
  final Set<String> hiddenCallIds;
  final DateTime? otherLastRead;
  final Set<String> selectedMessageIds;
  final Set<String> selectedCallIds;
  final String? reactionAnchorMessageId;
  final Map<String, String> participantNames;
  final ValueNotifier<bool> showScrollButton;
  final ValueNotifier<int> newMessageCount;
  final VoidCallback onScrollToBottom;
  final void Function(String messageId) onToggleMessageSelection;
  final void Function(String messageId) onMessageLongPress;
  final void Function(String callId) onToggleCallSelection;
  final void Function(String callId) onCallLongPress;
  final void Function(String callType) onInitiateCall;
  final void Function(CallModel call) onDeleteSingleCall;
  final void Function(Message msg) onDeleteMessage;
  final void Function(Message msg) onSwipeDeleteMessage;
  final void Function(Message msg) onUnsendMessage;
  final void Function(Message? replyMsg) onReplyMessage;
  final void Function(Message msg) onForwardMessage;
  final void Function(Message msg, String emoji) onReactToMessage;
  final void Function(Message msg) onSaveToVault;
  final String Function(Message? msg) getSenderDisplayName;
  final ValueListenable<String?>? flashIdListenable;
  final void Function(String messageId)? onReplyTap;
  final DateTime? entryLastReadAt;
  final String? currentUserId;

  const ChatMessageListView({
    super.key,
    required this.chatId,
    required this.isGroup,
    required this.isGuardian,
    required this.topAreaHeight,
    required this.searchQuery,
    required this.scrollController,
    required this.isEmojiPickerOpen,
    required this.hiddenCallIds,
    required this.otherLastRead,
    required this.selectedMessageIds,
    required this.selectedCallIds,
    required this.reactionAnchorMessageId,
    required this.participantNames,
    required this.showScrollButton,
    required this.newMessageCount,
    required this.onScrollToBottom,
    required this.onToggleMessageSelection,
    required this.onMessageLongPress,
    required this.onToggleCallSelection,
    required this.onCallLongPress,
    required this.onInitiateCall,
    required this.onDeleteSingleCall,
    required this.onDeleteMessage,
    required this.onSwipeDeleteMessage,
    required this.onUnsendMessage,
    required this.onReplyMessage,
    required this.onForwardMessage,
    required this.onReactToMessage,
    required this.onSaveToVault,
    required this.getSenderDisplayName,
    this.flashIdListenable,
    this.onReplyTap,
    this.entryLastReadAt,
    this.currentUserId,
  });

  bool get isSelectionMode =>
      selectedMessageIds.isNotEmpty || selectedCallIds.isNotEmpty;

  /// Buat daftar data entri secara cepat (O(N) data pointer tanpa alokasi widget eager).
  static List<ChatItemEntry> buildItemEntries(
    List<Message> messages,
    List<CallModel> calls, {
    DateTime? entryLastReadAt,
    String? currentUserId,
  }) {
    final combinedRaw = <ChatItemEntry>[];
    for (final m in messages) {
      combinedRaw.add(ChatItemEntry.message(m));
    }
    for (final c in calls) {
      combinedRaw.add(ChatItemEntry.call(c));
    }

    // Urutkan berdasarkan timestamp descending (terbaru di index 0 karena reverse: true pada ListView)
    combinedRaw.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Sisipkan pemisah tanggal
    final entries = <ChatItemEntry>[];
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
        entries.add(ChatItemEntry.dateSeparator(localCreatedAt));
      } else {
        final nextLocalCreatedAt = combinedRaw[i + 1].timestamp.toLocal();
        final nextItemDate = DateTime(
          nextLocalCreatedAt.year,
          nextLocalCreatedAt.month,
          nextLocalCreatedAt.day,
        );
        if (itemDate != nextItemDate) {
          entries.add(ChatItemEntry.dateSeparator(localCreatedAt));
        }
      }
    }
    if (entryLastReadAt != null && currentUserId != null) {
      final unreadIncoming = messages
          .where(
            (m) =>
                m.senderId != currentUserId &&
                !m.isDeleted &&
                m.createdAt.isAfter(entryLastReadAt),
          )
          .toList();

      if (unreadIncoming.isNotEmpty) {
        final count = unreadIncoming.length;
        unreadIncoming.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final oldestUnread = unreadIncoming.first;

        final idx = entries.indexWhere(
          (e) =>
              e.kind == ChatItemKind.message &&
              e.message?.id == oldestUnread.id,
        );

        if (idx != -1) {
          entries.insert(
            idx + 1,
            ChatItemEntry.unreadDivider(count, oldestUnread.createdAt),
          );
        }
      }
    }

    return entries;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatPref =
        ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
      chatPref,
      context,
    );
    final messagesStream = ref.watch(chatMessagesProvider(chatId));
    final reconnecting =
        ref.watch(chatReconnectingProvider(chatId)).value ?? false;
    final forwardingProtectionAsync = ref.watch(
      roomForwardingProtectionProvider(chatId),
    );
    final forwardingProtection = forwardingProtectionAsync.valueOrNull;

    final readReceiptsEnabled =
        ref.watch(authProvider.select((a) => a.profile?.readReceiptsEnabled)) ??
        true;
    final currentUserId = ref.read(authProvider).user?.id;
    final actions = ref.read(chatActionsProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Feed Pesan Kolom Utama
        Column(
          children: [
            SizedBox(height: topAreaHeight),
            Expanded(
              child: Column(
                children: [
                  // Banner Stale-while-revalidate saat offline / reconnecting
                  if (messagesStream.hasValue && reconnecting)
                    MekaarBanner.offlineMode(),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        switch (chatMessagesUiMode(messagesStream)) {
                          case ChatMessagesUiMode.data:
                            final rawDbMessages = messagesStream.valueOrNull!;
                            final nowUtc = DateTime.now().toUtc();
                            final activeDbMessages = rawDbMessages.where((m) {
                              if (m.autoDeleteAt != null &&
                                  m.autoDeleteAt!.isBefore(nowUtc)) {
                                return false;
                              }
                              return true;
                            }).toList();
                            final pendingMessages = ref.watch(
                              pendingMessagesProvider(chatId),
                            );
                            final callsAsync = ref.watch(
                              chatCallsProvider(chatId),
                            );
                            final rawCallsUnfiltered =
                                callsAsync.valueOrNull ?? const [];
                            final rawCalls = hiddenCallIds.isEmpty
                                ? rawCallsUnfiltered
                                : rawCallsUnfiltered
                                      .where(
                                        (c) => !hiddenCallIds.contains(c.id),
                                      )
                                      .toList();
                            final dbIds = {
                              for (var m in activeDbMessages) m.id,
                            };
                            final activePending = pendingMessages
                                .where(
                                  (p) =>
                                      !dbIds.contains(p.id) &&
                                      (p.autoDeleteAt == null ||
                                          p.autoDeleteAt!.isAfter(nowUtc)),
                                )
                                .toList();
                            final rawMessages = [
                              ...activeDbMessages,
                              ...activePending,
                            ];

                            if (rawMessages.isEmpty && rawCalls.isEmpty) {
                              return const MekaarStateView(
                                pose: MikaPose.sleep,
                                title: 'Belum Ada Pesan',
                                message:
                                    'Belum ada pesan atau panggilan. Mulai percakapan pertama!',
                              );
                            }

                            final messages = searchQuery.isEmpty
                                ? rawMessages
                                : rawMessages
                                      .where(
                                        (m) => m.content.toLowerCase().contains(
                                          searchQuery.toLowerCase(),
                                        ),
                                      )
                                      .toList();

                            final calls = searchQuery.isEmpty
                                ? rawCalls
                                : rawCalls
                                      .where(
                                        (c) =>
                                            c.callType.toLowerCase().contains(
                                              searchQuery.toLowerCase(),
                                            ) ||
                                            c
                                                .getDisplayStatus(
                                                  c.callerId == currentUserId,
                                                )
                                                .toLowerCase()
                                                .contains(
                                                  searchQuery.toLowerCase(),
                                                ),
                                      )
                                      .toList();

                            if (messages.isEmpty && calls.isEmpty) {
                              return MekaarStateView(
                                pose: MikaPose.confused,
                                title: 'Tidak Ditemukan',
                                message:
                                    'Tidak ada pesan atau panggilan yang cocok dengan "$searchQuery".',
                              );
                            }

                            final itemEntries = buildItemEntries(
                              messages,
                              calls,
                              entryLastReadAt: entryLastReadAt,
                              currentUserId: currentUserId,
                            );
                            final messageMap = {
                              for (var m in rawMessages) m.id: m,
                            };

                            final emojiInset = isEmojiPickerOpen ? 270.0 : 0.0;
                            final keyboardHeight = MediaQuery.viewInsetsOf(
                              context,
                            ).bottom;

                            return ListView.builder(
                              controller: scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.manual,
                              reverse: true,
                              padding: EdgeInsets.only(
                                top: 8,
                                bottom:
                                    130 +
                                    math.max(
                                      keyboardHeight,
                                      MediaQuery.viewPaddingOf(context).bottom,
                                    ) +
                                    emojiInset,
                              ),
                              itemCount: itemEntries.length,
                              itemBuilder: (context, index) {
                                return _buildLazyMessageItem(
                                  context: context,
                                  ref: ref,
                                  entry: itemEntries[index],
                                  currentUserId: currentUserId,
                                  actions: actions,
                                  messageMap: messageMap,
                                  forwardingProtection: forwardingProtection,
                                  roomThemeSpec: roomThemeSpec,
                                  showReadReceipts: readReceiptsEnabled,
                                );
                              },
                            );

                          case ChatMessagesUiMode.error:
                            final isNetworkErr = ErrorResolver.isNetworkError(
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
                                  : ErrorResolver.resolve(messagesStream.error),
                              actionLabel: 'Coba Lagi',
                              onAction: () =>
                                  ref.invalidate(chatMessagesProvider(chatId)),
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
        ),

        // Scroll to Bottom Button Overlay
        Positioned(
          left: 0,
          right: 0,
          bottom:
              math.max(
                MediaQuery.viewInsetsOf(context).bottom,
                MediaQuery.viewPaddingOf(context).bottom,
              ) +
              120 +
              (isEmojiPickerOpen ? 270.0 : 0.0),
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: showScrollButton,
              builder: (context, showButton, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: newMessageCount,
                  builder: (context, newCount, _) {
                    return ScrollToBottomButton(
                      visible: showButton,
                      newMessageCount: newCount,
                      accentColor: roomThemeSpec.primaryAccentColor,
                      iconColor: roomThemeSpec.iconColor,
                      onTap: () {
                        onScrollToBottom();
                        newMessageCount.value = 0;
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Bangun widget pesan individual secara lazy pada index viewport yang sedang aktif.
  Widget _buildLazyMessageItem({
    required BuildContext context,
    required WidgetRef ref,
    required ChatItemEntry entry,
    required String? currentUserId,
    required ChatActionsNotifier actions,
    required Map<String, Message> messageMap,
    RoomForwardingProtection? forwardingProtection,
    ChatRoomThemeSpec? roomThemeSpec,
    bool showReadReceipts = true,
  }) {
    if (entry.kind == ChatItemKind.dateSeparator) {
      return ChatDateSeparator(
        date: entry.date!,
        accentColor: roomThemeSpec?.secondaryAccentColor,
        textColor: roomThemeSpec?.textColor,
      );
    }

    if (entry.kind == ChatItemKind.unreadDivider) {
      return ChatUnreadDivider(
        count: entry.unreadCount ?? 1,
        accentColor: roomThemeSpec?.primaryAccentColor,
      );
    }

    if (entry.kind == ChatItemKind.call) {
      final call = entry.call!;
      final isMe = call.callerId == currentUserId;
      final isSelected = selectedCallIds.contains(call.id);
      final callWidget = CallHistoryBubble(
        call: call,
        isMe: isMe,
        isSelected: isSelected,
        isSelectionMode: isSelectionMode,
        onSelectionTap: () => onToggleCallSelection(call.id),
        onSelectionLongPress: () => onCallLongPress(call.id),
        onCallBack: () => onInitiateCall(call.callType),
      );

      return RepaintBoundary(
        key: ValueKey('call_bubble_${call.id}'),
        child: isSelectionMode
            ? callWidget
            : ChatSwipeActionWrapper(
                onDelete: () => onDeleteSingleCall(call),
                child: callWidget,
              ),
      );
    }

    final msg = entry.message!;
    final isMe = msg.senderId == currentUserId;
    final canEdit = actions.canEdit(msg, isGuardianRoom: isGuardian);

    Message? replyToMsg;
    String? replyToSender;
    if (msg.replyToId != null) {
      replyToMsg = messageMap[msg.replyToId];
      if (replyToMsg != null) {
        replyToSender = getSenderDisplayName(replyToMsg);
      }
    }

    final isSelected = selectedMessageIds.contains(msg.id);

    final bubble = ChatBubble(
      message: msg,
      isMe: isMe,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
      onSelectionTap: () => onToggleMessageSelection(msg.id),
      onSelectionLongPress: () => onMessageLongPress(msg.id),
      canDelete: true, // Semua pesan bisa dihapus secara lokal (hide for me)
      canUnsend:
          isMe, // Hanya pengirim yang bisa tarik pesan (delete for everyone)
      canEdit: isMe && canEdit,
      canForward: actions.canForward(
        msg,
        forwardingProtectionActive: forwardingProtection?.effective ?? false,
      ),
      otherLastReadAt: otherLastRead,
      showReadReceipts: showReadReceipts,
      senderName: isGroup ? participantNames[msg.senderId] : null,
      replyToMessage: replyToMsg,
      replyToSenderName: replyToSender,
      onDelete: () => onDeleteMessage(msg),
      onUnsend: () => onUnsendMessage(msg),
      onReply: (replyMsg) => onReplyMessage(replyMsg),
      onReplyTap: onReplyTap,
      onEdit: (editMsg, newContent) {
        if (!actions.canEdit(editMsg, isGuardianRoom: isGuardian)) {
          return;
        }
        ref
            .read(chatActionsProvider)
            .editMessage(editMsg.id, newContent, isGuardianRoom: isGuardian);
      },
      onForward: (forwardingProtection?.effective ?? false)
          ? null
          : (forwardMsg) => onForwardMessage(forwardMsg),
      onReact: (reactMsg, emoji) => onReactToMessage(reactMsg, emoji),
      onSaveToVault: (saveMsg) => onSaveToVault(saveMsg),
    );

    final showFloatingReactions =
        isSelected && reactionAnchorMessageId == msg.id;

    final bubbleWithPill = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (showFloatingReactions)
          ChatFloatingReactionPill(
            isMe: isMe,
            onReact: (emoji) => onReactToMessage(msg, emoji),
          ),
        bubble,
      ],
    );

    // Bungkus dengan KeyedSubtree untuk jumpToKeyedItem, RepaintBoundary untuk isolasi repaint,
    // dan MessageFlash untuk sorotan pudar saat melompat ke pesan yang dibalas.
    final wrappedBubble = isSelectionMode
        ? bubbleWithPill
        : ChatSwipeActionWrapper(
            onReply: () => onReplyMessage(msg),
            onDelete: () => onSwipeDeleteMessage(msg),
            child: bubbleWithPill,
          );

    return KeyedSubtree(
      key: GlobalObjectKey('msg-${msg.id}'),
      child: RepaintBoundary(
        key: ValueKey('bubble_${msg.id}'),
        child: MessageFlash(
          messageId: msg.id,
          flashIdListenable: flashIdListenable,
          child: wrappedBubble,
        ),
      ),
    );
  }
}
