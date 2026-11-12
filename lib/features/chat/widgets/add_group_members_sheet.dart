import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_top_bar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';

class AddGroupMembersSheet extends ConsumerStatefulWidget {
  final String roomId;
  final Set<String> existingMemberUserIds;

  const AddGroupMembersSheet({
    super.key,
    required this.roomId,
    required this.existingMemberUserIds,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String roomId,
    required Set<String> existingMemberUserIds,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.90,
        child: AddGroupMembersSheet(
          roomId: roomId,
          existingMemberUserIds: existingMemberUserIds,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddGroupMembersSheet> createState() =>
      _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends ConsumerState<AddGroupMembersSheet> {
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  bool _isSubmitting = false;

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

  void _toggleMember(String userId) {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _submitAddMembers() async {
    if (_selectedUserIds.isEmpty) return;
    setState(() => _isSubmitting = true);
    HapticService.trigger(MekaarHapticIntent.selection);

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.addGroupParticipants(
        widget.roomId,
        _selectedUserIds.toList(),
      );
      if (mounted) {
        MekaarSnackbar.success(
          context,
          '${_selectedUserIds.length} anggota berhasil ditambahkan.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal menambahkan anggota ke grup.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isGuest = authState.isGuestActive || authState.isDuressActive;
    final contactsAsync = ref.watch(userContactsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);

    return Container(
      decoration: BoxDecoration(
        color: MekaarColors.backgroundOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MekaarRadius.xl),
        ),
      ),
      child: Column(
        children: [
          MekaarTopBar(
            title: 'Tambah Anggota',
            subtitle: _selectedUserIds.isEmpty
                ? 'Pilih dari kontak Anda'
                : '${_selectedUserIds.length} dipilih',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MekaarSpacing.md,
              vertical: MekaarSpacing.sm,
            ),
            child: MekaarSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Cari kontak...',
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
          Expanded(
            child: contactsAsync.when(
              loading: () => const MekaarStateView(
                pose: MikaPose.neutral,
                title: 'Memuat Kontak',
                message: 'Mengambil daftar kontak Anda...',
                semanticLabel: 'Memuat kontak',
              ),
              error: (err, stack) => MekaarStateView(
                pose: MikaPose.thinking,
                title: 'Gagal Memuat Kontak',
                message: 'Terjadi kesalahan saat memuat kontak.',
                actionLabel: 'Coba Lagi',
                onAction: () => ref
                    .read(userContactsProvider.notifier)
                    .refreshContacts(forceLoading: true),
              ),
              data: (contacts) {
                final currentUserId = authState.user?.id;
                final availableContacts = contacts.where((c) {
                  final contactUserId = c.contactUserId;
                  if (contactUserId.isEmpty || contactUserId == currentUserId) {
                    return false;
                  }
                  if (isGuest && hiddenContactUserIds.contains(contactUserId)) {
                    return false;
                  }
                  if (widget.existingMemberUserIds.contains(contactUserId)) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final name = c.effectiveName.toLowerCase();
                    final username = c.username.toLowerCase();
                    return name.contains(_searchQuery) ||
                        username.contains(_searchQuery);
                  }
                  return true;
                }).toList();

                if (availableContacts.isEmpty) {
                  return const MekaarStateView(
                    pose: MikaPose.thinking,
                    title: 'Tidak Ada Kontak',
                    message:
                        'Semua kontak Anda sudah menjadi anggota grup ini, atau tidak ada kontak yang cocok dengan pencarian.',
                    semanticLabel: 'Tidak ada kontak untuk ditambahkan',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MekaarSpacing.md,
                    vertical: MekaarSpacing.sm,
                  ),
                  itemCount: availableContacts.length,
                  separatorBuilder: (ctx, idx) => Divider(
                    height: 1,
                    thickness: 0.6,
                    indent: 64,
                    color: MekaarColors.borderOf(context).withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final item = availableContacts[index];
                    final contactUserId = item.contactUserId;
                    final name = item.effectiveName;
                    final username = item.username;
                    final avatarUrl = item.avatarUrl;
                    final isSelected = _selectedUserIds.contains(contactUserId);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MekaarSpacing.xs,
                        vertical: 2,
                      ),
                      leading: Avatar(
                        size: 44,
                        imageUrl: avatarUrl,
                        initial: name.isNotEmpty ? name[0] : 'K',
                      ),
                      title: Text(
                        name,
                        style: MekaarTypography.bodyMD.copyWith(
                          color: MekaarColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
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
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (_) => _toggleMember(contactUserId),
                      ),
                      onTap: () => _toggleMember(contactUserId),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(MekaarSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _selectedUserIds.isEmpty || _isSubmitting
                      ? null
                      : _submitAddMembers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(SolarIconsOutline.userPlus, size: 20),
                  label: Text(
                    _selectedUserIds.isEmpty
                        ? 'Pilih Kontak'
                        : 'Tambahkan (${_selectedUserIds.length}) Anggota',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
