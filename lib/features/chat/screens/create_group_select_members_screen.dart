import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';

class CreateGroupSelectMembersScreen extends ConsumerStatefulWidget {
  const CreateGroupSelectMembersScreen({super.key});

  @override
  ConsumerState<CreateGroupSelectMembersScreen> createState() =>
      _CreateGroupSelectMembersScreenState();
}

class _CreateGroupSelectMembersScreenState
    extends ConsumerState<CreateGroupSelectMembersScreen> {
  final Set<String> _selectedUserIds = {};
  final Map<String, Map<String, dynamic>> _selectedUserProfiles = {};
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  late final ScrollController _scrollController;
  Timer? _searchDebounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedContactsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMember(String userId, Map<String, dynamic> profile) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        _selectedUserProfiles.remove(userId);
      } else {
        _selectedUserIds.add(userId);
        _selectedUserProfiles[userId] = profile;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final cloakedContacts = ref.watch(cloakedContactUserIdsProvider);
    final cloakedRooms = ref.watch(cloakedRoomIdsProvider);
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull ?? [];

    final hiddenUserIds = <String>{...cloakedContacts};
    for (final r in chatRooms) {
      if (cloakedRooms.contains(r['id']) && r['otherUserId'] != null) {
        hiddenUserIds.add(r['otherUserId'] as String);
      }
    }

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: MekaarTopBar(
        title: 'Grup Baru',
        subtitle: _selectedUserIds.isEmpty
            ? 'Pilih anggota grup'
            : '${_selectedUserIds.length} dipilih',
      ),
      body: Column(
        children: [
          // Selected Members Horizontal Chip Bar
          if (_selectedUserIds.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(
                horizontal: MekaarSpacing.md,
                vertical: MekaarSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: MekaarColors.surfaceOf(context),
                border: Border(
                  bottom: BorderSide(
                    color: MekaarColors.borderOf(context).withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUserIds.length,
                separatorBuilder: (ctx, idx) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final userId = _selectedUserIds.elementAt(index);
                  final profile = _selectedUserProfiles[userId] ?? {};
                  final name = (profile['display_name'] as String?)?.isNotEmpty == true
                      ? profile['display_name'] as String
                      : profile['full_name'] as String? ??
                          profile['username'] as String? ??
                          'User';
                  final avatarUrl = profile['avatar_url'] as String?;

                  return Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.blue.withValues(alpha: 0.2),
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: AppColors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 50,
                            child: Text(
                              name,
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.textSecondaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleMember(userId, profile),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: MekaarColors.sosRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              MekaarIcons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(MekaarSpacing.md),
            child: MekaarSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Cari kontak...',
              onChanged: (val) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer =
                    Timer(const Duration(milliseconds: 180), () {
                  if (mounted && _searchQuery != val.toLowerCase()) {
                    setState(() => _searchQuery = val.toLowerCase());
                    ref.read(paginatedContactsProvider.notifier).search(val);
                  }
                });
              },
            ),
          ),

          // Contacts List (Paginated & Infinite Scroll)
          Expanded(
            child: Builder(
              builder: (context) {
                final paginatedState = ref.watch(paginatedContactsProvider);

                if (paginatedState.isLoading && paginatedState.items.isEmpty) {
                  return const MekaarStateView(
                    pose: MikaPose.neutral,
                    title: 'Memuat Kontak',
                    message: 'Mengambil daftar kontak untuk dipilih...',
                    semanticLabel: 'Memuat daftar kontak',
                  );
                }

                final contacts = paginatedState.items.isNotEmpty
                    ? paginatedState.items
                    : (contactsAsync.valueOrNull ?? const []);

                final filtered = contacts.where((c) {
                  final userId = c['id'] as String?;
                  if (userId != null && hiddenUserIds.contains(userId)) {
                    return false;
                  }
                  final name = ((c['display_name'] ??
                          c['full_name'] ??
                          c['username'] ??
                          '') as String)
                      .toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty && !paginatedState.isLoading) {
                  return Center(
                    child: Text(
                      'Tidak ada kontak ditemukan.',
                      style: TextStyle(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  );
                }

                final hasExtraLoadingTile = paginatedState.isLoadingMore;
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: filtered.length + (hasExtraLoadingTile ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: MekaarSpacing.md),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final contact = filtered[index];
                    final userId = contact['id'] as String;
                    final isSelected = _selectedUserIds.contains(userId);
                    final name = (contact['display_name'] as String?)?.isNotEmpty == true
                        ? contact['display_name'] as String
                        : contact['full_name'] as String? ??
                            contact['username'] as String? ??
                            'Kontak';
                    final username = contact['username'] as String? ?? '';
                    final avatarUrl = contact['avatar_url'] as String?;

                    return ListTile(
                      onTap: () => _toggleMember(userId, contact),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: isSelected
                            ? AppColors.blue
                            : MekaarColors.surface2Of(context),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'K',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : MekaarColors.textPrimaryOf(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: MekaarTypography.bodyMD.copyWith(
                          color: MekaarColors.textPrimaryOf(context),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: username.isNotEmpty
                          ? Text(
                              '@$username',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.textMutedOf(context),
                              ),
                            )
                          : null,
                      trailing: Icon(
                        isSelected
                            ? SolarIconsBold.checkCircle
                            : SolarIconsOutline.checkCircle,
                        color: isSelected
                            ? AppColors.blue
                            : MekaarColors.textMutedOf(context),
                        size: 22,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                Navigator.pushNamed(
                  context,
                  AppRoutes.createGroupDetails,
                  arguments: {
                    'selectedUserIds': _selectedUserIds.toList(),
                    'selectedUserProfiles': _selectedUserProfiles.values.toList(),
                  },
                );
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(SolarIconsOutline.arrowRight),
              label: Text('Lanjut (${_selectedUserIds.length})'),
            )
          : null,
    );
  }
}
