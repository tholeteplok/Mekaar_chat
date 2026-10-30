import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/private_contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/message_search_provider.dart';
import '../providers/private_vault_provider.dart';
import '../utils/message_search_helper.dart';

/// Layar pencarian pesan lintas-chat (Cross-Chat Message Search).
///
/// Menyediakan akses pencarian pesan terenkripsi offline-first di semua room obrolan,
/// hasil dikelompokkan berdasarkan room, dengan cuplikan ber-highlight amber,
/// serta navigasi lompat langsung ke pesan di dalam layar obrolan target (`jumpToMessageId`).
class MessageSearchScreen extends ConsumerStatefulWidget {
  const MessageSearchScreen({super.key});

  @override
  ConsumerState<MessageSearchScreen> createState() =>
      _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _debounceTimer;
  Timer? _vaultDebounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    // Auto-focus ke kolom pencarian setelah render awal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _vaultDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(messageSearchQueryProvider.notifier).state = value;
      }
    });

    _vaultDebounceTimer?.cancel();
    if (value.trim().length >= 4) {
      _vaultDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        _checkVaultPasscode(value);
      });
    }
  }

  Future<void> _checkVaultPasscode(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final repo = ref.read(privateContactRepositoryProvider);
      final matchedSlot = await repo.checkAnySlotPasscode(query.trim());
      if (matchedSlot != null && mounted) {
        _searchController.clear();
        ref.read(messageSearchQueryProvider.notifier).state = '';
        _searchFocusNode.unfocus();
        HapticService.trigger(MekaarHapticIntent.success);
        ref.read(unlockedVaultSlotsProvider.notifier).state = {matchedSlot};
        ref.read(privateVaultUnlockedProvider.notifier).state = true;
        final slotName = await repo.getSlotName(matchedSlot);
        if (mounted) {
          MekaarSnackbar.success(context, '$slotName Terbuka');
        }
      }
    } catch (_) {}
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(messageSearchQueryProvider.notifier).state = '';
    HapticService.trigger(MekaarHapticIntent.selection);
  }

  String _formatTimestamp(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(localDt.year, localDt.month, localDt.day);

    if (msgDate == today) {
      return DateFormat('HH:mm').format(localDt);
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (msgDate == yesterday) {
      return 'Kemarin ${DateFormat('HH:mm').format(localDt)}';
    }
    if (now.difference(msgDate).inDays < 7) {
      return DateFormat('EEEE, HH:mm', 'id_ID').format(localDt);
    }
    return DateFormat('d MMM yyyy', 'id_ID').format(localDt);
  }

  void _navigateToChat({
    required RoomSearchResultGroup group,
    String? jumpToMessageId,
  }) {
    HapticService.trigger(MekaarHapticIntent.selection);
    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: {
        'chatId': group.roomId,
        'chatName': group.roomName,
        'chatAvatar': group.roomAvatar,
        'chatAvatarUrl': group.roomAvatarUrl,
        'otherUserId': group.otherUserId,
        'isGuardian': group.isGuardian,
        'jumpToMessageId': ?jumpToMessageId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(messageSearchQueryProvider).trim();
    final groupedResultsAsync = ref.watch(groupedSearchResultsProvider);
    final myUserId = ref.watch(authProvider).user?.id ?? '';

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: MekaarColors.surfaceOf(context),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(
            SolarIconsOutline.arrowLeft,
            color: MekaarColors.textPrimaryOf(context),
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: MekaarSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: 'Cari di semua obrolan...',
            onChanged: _onQueryChanged,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                SolarIconsOutline.closeCircle,
                color: MekaarColors.textMutedOf(context),
              ),
              onPressed: _clearSearch,
              tooltip: 'Hapus Pencarian',
            ),
        ],
      ),
      body: _buildBody(query, groupedResultsAsync, myUserId),
    );
  }

  Widget _buildBody(
    String query,
    AsyncValue<List<RoomSearchResultGroup>> groupedResultsAsync,
    String myUserId,
  ) {
    if (query.length < 2) {
      return Center(
        child: MekaarStateView(
          illustration: MikaIllustrationType.emptySearch,
          title: 'Cari Isi Pesan',
          message:
              'Ketik minimal 2 karakter untuk mencari pesan di semua percakapan aman Anda.',
        ),
      );
    }

    return groupedResultsAsync.when(
      loading: () =>
          const Padding(padding: EdgeInsets.all(20), child: ChatListSkeleton()),
      error: (err, _) => Center(
        child: MekaarStateView(
          stateIcon: SolarIconsOutline.dangerCircle,
          stateIconColor: MekaarColors.sosRed,
          title: 'Gagal Mencari',
          message: 'Terjadi kesalahan saat mencari pesan lokal: $err',
          actionLabel: 'Ulangi',
          onAction: () => ref.invalidate(messageSearchResultsProvider),
        ),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: MekaarStateView(
              illustration: MikaIllustrationType.emptySearch,
              title: 'Tidak Ditemukan',
              message: 'Tidak ada pesan yang cocok dengan "$query".',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _buildGroupCard(group, query, myUserId);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(
    RoomSearchResultGroup group,
    String query,
    String myUserId,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Room
            InkWell(
              onTap: () => _navigateToChat(group: group),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(MekaarRadius.md),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MekaarColors.surface2Of(
                    context,
                  ).withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(MekaarRadius.md),
                  ),
                ),
                child: Row(
                  children: [
                    Avatar(
                      initial: group.roomAvatar,
                      imageUrl: group.roomAvatarUrl,
                      size: 32,
                      isGuardian: group.isGuardian,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.roomName,
                        style: MekaarTypography.labelMD.copyWith(
                          fontWeight: FontWeight.bold,
                          color: MekaarColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MekaarColors.primaryOf(
                          context,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${group.messages.length} hasil',
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.primaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      SolarIconsOutline.altArrowRight,
                      size: 16,
                      color: MekaarColors.textMutedOf(context),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // Daftar Pesan Cocok
            ...group.messages.map((message) {
              final isMe = message.senderId == myUserId;
              final senderLabel = isMe ? 'Anda' : group.roomName;
              final displayContent = message.searchableText ?? message.content;

              final normalStyle = MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
              );
              final matchStyle = MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
                backgroundColor: MekaarColors.warnAmber.withValues(alpha: 0.35),
              );

              final snippetSpans = MessageSearchHelper.buildSearchSnippetSpans(
                text: displayContent,
                query: query,
                normalStyle: normalStyle,
                matchStyle: matchStyle,
              );

              return InkWell(
                onTap: () =>
                    _navigateToChat(group: group, jumpToMessageId: message.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: MekaarColors.dividerOf(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            senderLabel,
                            style: MekaarTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isMe
                                  ? MekaarColors.primaryOf(context)
                                  : MekaarColors.textPrimaryOf(context),
                            ),
                          ),
                          Text(
                            _formatTimestamp(message.createdAt),
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(children: snippetSpans),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
