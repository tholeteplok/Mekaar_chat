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
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
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
  Timer? _searchDebounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
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
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuestActive || authState.isDuressActive;
    final contactsAsync = ref.watch(userContactsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: MekaarTopBar(
        title: 'Grup Baru',
        subtitle: _selectedUserIds.isEmpty
            ? (isGuest ? 'Pilih kontak (Mode Tamu)' : 'Pilih anggota grup')
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
                  final name = (profile['alias_name'] as String?)?.isNotEmpty == true
                      ? profile['alias_name'] as String
                      : (profile['display_name'] as String?)?.isNotEmpty == true
                          ? profile['display_name'] as String
                          : profile['full_name'] as String? ??
                              profile['username'] as String? ??
                              'Kontak';
                  final avatarUrl = profile['avatar_url'] as String?;

                  return Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(
                            size: 44,
                            imageUrl: avatarUrl,
                            initial: name.isNotEmpty ? name[0] : 'K',
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
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: MekaarColors.sosRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              MekaarIcons.close,
                              size: 14,
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
              hintText: 'Cari kontak Anda...',
              onChanged: (val) {
                _searchDebounceTimer?.cancel();
                _searchDebounceTimer =
                    Timer(const Duration(milliseconds: 120), () {
                  if (mounted && _searchQuery != val.trim().toLowerCase()) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  }
                });
              },
            ),
          ),

          // Contacts List (Milik Sendiri: Mode Master vs Mode Guest)
          Expanded(
            child: contactsAsync.when(
              loading: () => const MekaarStateView(
                pose: MikaPose.neutral,
                title: 'Memuat Kontak',
                message: 'Mengambil daftar kontak Anda...',
                semanticLabel: 'Memuat daftar kontak',
              ),
              error: (err, stack) => MekaarStateView(
                pose: MikaPose.thinking,
                title: 'Gagal Memuat Kontak',
                message: 'Terjadi kesalahan saat memuat kontak Anda.',
                actionLabel: 'Coba Lagi',
                onAction: () => ref
                    .read(userContactsProvider.notifier)
                    .refreshContacts(forceLoading: true),
              ),
              data: (items) {
                // Mode Master: Semua kontak sendiri
                // Mode Guest: Hanya kontak terbuka (isVaulted == false && !hiddenUserIds)
                final availableContacts = items.where((c) {
                  if (isGuest) {
                    if (c.isVaulted) return false;
                    if (hiddenContactUserIds.contains(c.contactUserId)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                final filtered = availableContacts.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery;
                  final name = c.effectiveName.toLowerCase();
                  final username = c.username.toLowerCase();
                  final email = (c.email ?? '').toLowerCase();
                  return name.contains(q) ||
                      username.contains(q) ||
                      email.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        items.isEmpty
                            ? (isGuest
                                ? 'Tidak ada kontak terbuka yang tersedia di Mode Tamu.'
                                : 'Belum ada kontak tersimpan di akun Anda.')
                            : 'Tidak ada kontak yang cocok dengan "$_searchQuery".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final userId = contact.contactUserId;
                    final isSelected = _selectedUserIds.contains(userId);
                    final name = contact.effectiveName;
                    final username = contact.username;
                    final avatarUrl = contact.avatarUrl;

                    final profileMap = {
                      'id': contact.contactUserId,
                      'username': contact.username,
                      'display_name': contact.displayName,
                      'full_name': contact.fullName,
                      'alias_name': contact.aliasName,
                      'avatar_url': contact.avatarUrl,
                    };

                    return ListTile(
                      onTap: () => _toggleMember(userId, profileMap),
                      leading: Avatar(
                        size: 40,
                        imageUrl: avatarUrl,
                        initial: name.isNotEmpty ? name[0] : 'K',
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
                            ? MekaarColors.primaryOf(context)
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
                    'selectedUserProfiles':
                        _selectedUserProfiles.values.toList(),
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
