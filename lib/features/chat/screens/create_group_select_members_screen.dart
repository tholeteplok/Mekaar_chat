import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../providers/chat_provider.dart';

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
  String _searchQuery = '';

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

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: CustomAppBar(
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
                    color: MekaarColors.border.withValues(alpha: 0.1),
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
                            backgroundColor: MekaarColors.softCoral.withValues(alpha: 0.2),
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: MekaarColors.softCoral,
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
                          onTap: () => _toggleMember(userId, profile),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: MekaarColors.sosRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
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
              hintText: 'Cari kontak...',
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // Contacts List
          Expanded(
            child: contactsAsync.when(
              data: (contacts) {
                final filtered = contacts.where((c) {
                  final name = ((c['display_name'] ?? c['full_name'] ?? c['username'] ?? '') as String).toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada kontak ditemukan.',
                      style: TextStyle(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
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
                            ? MekaarColors.softCoral
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
                            ? MekaarColors.softCoral
                            : MekaarColors.textMutedOf(context),
                        size: 22,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: MekaarColors.softCoral),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Gagal memuat kontak.',
                  style: TextStyle(color: MekaarColors.textMutedOf(context)),
                ),
              ),
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
              backgroundColor: MekaarColors.softCoral,
              foregroundColor: Colors.white,
              icon: const Icon(SolarIconsOutline.arrowRight),
              label: Text('Lanjut (${_selectedUserIds.length})'),
            )
          : null,
    );
  }
}
