import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/forwarding_protection_repository.dart';
import '../../../data/services/local_message_database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/chat_theme_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_selection_app_bar.dart';

/// Sub-komponen modular untuk Floating App Bar pada ChatScreen.
/// Mendukung 3 mode tampilan:
/// 1. [ChatSelectionAppBar] saat mode seleksi pesan aktif (_isSelectionMode).
/// 2. In-Chat Search Bar saat pencarian pesan aktif (_isSearching).
/// 3. [CustomAppBar] normal dengan indikator presence real-time, status mengetik,
///    tombol panggilan langsung, dan popup menu tindakan.
class ChatAppBar extends ConsumerWidget {
  final String chatId;
  final String chatName;
  final String avatarInitial;
  final String? avatarUrl;
  final bool isGuardian;
  final bool isGroup;
  final String? otherUserId;
  final int participantCount;
  final ValueNotifier<DateTime?> otherLastSeenNotifier;
  final bool isMuted;

  // Mode Seleksi Pesan
  final bool isSelectionMode;
  final int totalSelectedCount;
  final Set<String> selectedMessageIds;
  final Set<String> selectedCallIds;
  final List<Message> rawMessages;
  final RoomForwardingProtection? forwardingProtection;
  final VoidCallback onClearSelection;
  final VoidCallback onReplySelectedMessage;
  final void Function(Message msg) onEditSelectedMessage;
  final VoidCallback onCopySelectedMessages;
  final VoidCallback onForwardSelectedMessages;
  final void Function(List<Message> files) onDownloadSelectedFiles;
  final void Function(List<Message> media) onSaveSelectedToVault;
  final void Function(List<Message> allMessages) onDeleteSelectedMessages;

  // Mode Pencarian Dalam Obrolan
  final bool isSearching;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode inChatSearchFocusNode;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearchQuery;
  final int? searchResultCount;

  // Aksi Header & Menu
  final VoidCallback onAvatarTap;
  final void Function(String callType) onInitiateCall;
  final ValueChanged<String> onMenuActionSelected;

  const ChatAppBar({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.avatarInitial,
    this.avatarUrl,
    required this.isGuardian,
    required this.isGroup,
    this.otherUserId,
    this.participantCount = 0,
    required this.otherLastSeenNotifier,
    required this.isMuted,
    // Selection
    required this.isSelectionMode,
    required this.totalSelectedCount,
    required this.selectedMessageIds,
    required this.selectedCallIds,
    required this.rawMessages,
    this.forwardingProtection,
    required this.onClearSelection,
    required this.onReplySelectedMessage,
    required this.onEditSelectedMessage,
    required this.onCopySelectedMessages,
    required this.onForwardSelectedMessages,
    required this.onDownloadSelectedFiles,
    required this.onSaveSelectedToVault,
    required this.onDeleteSelectedMessages,
    // Search
    required this.isSearching,
    required this.searchQuery,
    required this.searchController,
    required this.inChatSearchFocusNode,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onClearSearchQuery,
    this.searchResultCount,
    // Actions
    required this.onAvatarTap,
    required this.onInitiateCall,
    required this.onMenuActionSelected,
  });

  bool _isCurrentlyOnline(DateTime? otherLastSeen) {
    if (otherLastSeen == null) return false;
    return DateTime.now().difference(otherLastSeen).inMinutes < 2;
  }

  String _formatPresenceSubtitle(DateTime? otherLastSeen) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatPref =
        ref.watch(chatThemeProvider).valueOrNull ?? const ChatThemePreference();
    final roomThemeSpec = ChatPresetResolver.getRoomThemeSpec(
      chatPref,
      context,
    );

    // ──────────────────────────────────────────
    // 1. Mode Seleksi Pesan (Contextual Action Bar)
    // ──────────────────────────────────────────
    if (isSelectionMode) {
      final isSingle = totalSelectedCount == 1;
      final isForwardProtected = forwardingProtection?.effective ?? false;
      // Resolusi ID pengguna saat ini: gunakan fallback ke Supabase auth langsung
      // agar tombol edit tidak menghilang saat state Riverpod belum sinkron penuh.
      final currentUserId =
          ref.watch(authProvider).user?.id ??
          (SupabaseService.isInitialized
              ? Supabase.instance.client.auth.currentUser?.id
              : null);

      final canReply = isSingle && selectedMessageIds.length == 1;
      final singleSelectedMsg = isSingle && selectedMessageIds.length == 1
          ? rawMessages.cast<Message?>().firstWhere(
              (m) => m?.id == selectedMessageIds.first,
              orElse: () => null,
            )
          : null;
      // Tampilkan tombol edit untuk pesan teks milik pengirim sendiri.
      // Pembatasan Guardian & batas waktu 30 menit ditangani secara transparan
      // melalui snackbar edukasi saat tombol diketuk (bukan disembunyikan).
      final canEdit =
          singleSelectedMsg != null &&
          currentUserId != null &&
          singleSelectedMsg.senderId == currentUserId &&
          singleSelectedMsg.type == MessageType.text &&
          !singleSelectedMsg.isDeleted;
      final hasCopyableText = rawMessages.any(
        (m) =>
            selectedMessageIds.contains(m.id) &&
            m.type == MessageType.text &&
            !m.isDeleted &&
            m.content.trim().isNotEmpty,
      );
      final canForward =
          !isForwardProtected &&
          selectedCallIds.isEmpty &&
          selectedMessageIds.isNotEmpty;

      final savableMediaMessages = rawMessages
          .where(
            (m) =>
                selectedMessageIds.contains(m.id) &&
                !m.isDeleted &&
                !m.isSilentDeleted &&
                (m.type == MessageType.image ||
                    m.type == MessageType.video ||
                    m.type == MessageType.voice ||
                    m.type == MessageType.file ||
                    (m.mediaUrl != null && m.mediaUrl!.isNotEmpty)),
          )
          .toList();
      final canSaveToVault =
          savableMediaMessages.isNotEmpty && selectedCallIds.isEmpty;

      final downloadableFileMessages = rawMessages
          .where(
            (m) =>
                selectedMessageIds.contains(m.id) &&
                !m.isDeleted &&
                !m.isSilentDeleted &&
                (m.type == MessageType.file ||
                    m.type == MessageType.image ||
                    m.type == MessageType.video ||
                    m.type == MessageType.voice) &&
                m.mediaUrl != null &&
                m.mediaUrl!.isNotEmpty,
          )
          .toList();
      final canDownload =
          downloadableFileMessages.isNotEmpty && selectedCallIds.isEmpty;

      return ChatSelectionAppBar(
        selectedCount: totalSelectedCount,
        canReply: canReply,
        canEdit: canEdit,
        hasCopyableText: hasCopyableText,
        canForward: canForward,
        canDownload: canDownload,
        canSaveToVault: canSaveToVault,
        surfaceColor: roomThemeSpec.glassBackgroundColor,
        textColor: roomThemeSpec.textColor,
        iconColor: roomThemeSpec.iconColor,
        onClose: onClearSelection,
        onReply: onReplySelectedMessage,
        onEdit: canEdit ? () => onEditSelectedMessage(singleSelectedMsg) : null,
        onCopy: onCopySelectedMessages,
        onForward: onForwardSelectedMessages,
        onDownload: () => onDownloadSelectedFiles(downloadableFileMessages),
        onSaveToVault: () => onSaveSelectedToVault(savableMediaMessages),
        onDelete: () => onDeleteSelectedMessages(rawMessages),
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

    // ──────────────────────────────────────────
    // 2. Mode Pencarian Dalam Obrolan
    // ──────────────────────────────────────────
    if (isSearching) {
      final topPadding = MediaQuery.of(context).padding.top;
      return Padding(
        padding: EdgeInsets.only(top: topPadding + 4, left: 12, right: 12),
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
                onPressed: onCloseSearch,
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('in_chat_search_input'),
                  controller: searchController,
                  focusNode: inChatSearchFocusNode,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari dalam obrolan...',
                    hintStyle: TextStyle(
                      color: MekaarColors.textMutedOf(context),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              if (searchQuery.isNotEmpty && searchResultCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: roomThemeSpec.primaryAccentColor.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$searchResultCount hasil',
                    style: MekaarTypography.labelSM.copyWith(
                      color: roomThemeSpec.textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(
                    SolarIconsOutline.closeCircle,
                    color: MekaarColors.textMutedOf(context),
                    size: 18,
                  ),
                  onPressed: onClearSearchQuery,
                ),
            ],
          ),
        ),
      );
    }

    // ──────────────────────────────────────────
    // 3. CustomAppBar Normal (Floating Glass)
    // ──────────────────────────────────────────
    final isTyping = ref.watch(typingStateProvider(chatId));

    return ValueListenableBuilder<DateTime?>(
      valueListenable: otherLastSeenNotifier,
      builder: (context, lastSeen, _) {
        final isOnline = _isCurrentlyOnline(lastSeen);
        final showCalls =
            !LocalMessageDatabase.instance.isDecoy &&
            chatId != 'room_welcome_mekaar';

        return CustomAppBar(
          isMaterialHeader: true,
          title: chatName,
          avatarInitial: avatarInitial,
          avatarUrl: avatarUrl,
          avatarHeroTag: 'avatar-room-$chatId',
          isGuardian: isGuardian,
          showOnlineIndicator: true,
          isOnline: isOnline || isTyping,
          subtitle: isGroup
              ? '${participantCount > 0 ? '$participantCount anggota • ' : ''}Enkripsi Server'
              : (isTyping
                    ? 'sedang mengetik...'
                    : _formatPresenceSubtitle(lastSeen)),
          glassBorder: roomThemeSpec.glassBorder,
          glassBackgroundColor: roomThemeSpec.glassBackgroundColor,
          iconColor: roomThemeSpec.iconColor,
          textColor: roomThemeSpec.textColor,
          subtitleColor: roomThemeSpec.subtitleColor,
          onAvatarTap: onAvatarTap,
          actions: [
            if (showCalls) ...[
              IconButton(
                icon: Icon(
                  SolarIconsOutline.videocamera,
                  color: roomThemeSpec.iconColor,
                  size: 22,
                ),
                tooltip: 'Panggilan Video',
                onPressed: () => onInitiateCall('video'),
              ),
              IconButton(
                icon: Icon(
                  SolarIconsOutline.phoneRounded,
                  color: roomThemeSpec.iconColor,
                  size: 22,
                ),
                tooltip: 'Panggilan Suara',
                onPressed: () => onInitiateCall('voice'),
              ),
            ],
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
                side: BorderSide(color: frostedBorder, width: 1),
              ),
              color: frostedBg,
              surfaceTintColor: Colors.transparent,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
              padding: EdgeInsets.zero,
              icon: Icon(
                SolarIconsOutline.menuDots,
                color: roomThemeSpec.iconColor,
              ),
              onSelected: onMenuActionSelected,
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
                        isMuted
                            ? SolarIconsOutline.volumeLoud
                            : SolarIconsOutline.volumeCross,
                        size: 20,
                        color: textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMuted ? 'Bunyikan Notifikasi' : 'Bisukan Notifikasi',
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
  }
}
