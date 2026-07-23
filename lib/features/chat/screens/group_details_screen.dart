import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../providers/chat_provider.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String groupName;
  final String? groupAvatarUrl;

  const GroupDetailsScreen({
    super.key,
    required this.roomId,
    required this.groupName,
    this.groupAvatarUrl,
  });

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  Map<String, dynamic>? _groupData;
  List<dynamic> _participants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final details = await chatRepo.getGroupDetails(widget.roomId);
      if (details != null && mounted) {
        setState(() {
          _groupData = details['room'] as Map<String, dynamic>?;
          _participants = (details['participants'] as List?) ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Grup'),
        content: Text('Apakah Anda yakin ingin keluar dari "${widget.groupName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: MekaarColors.sosRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticService.trigger(MekaarHapticIntent.selection);
      try {
        final chatRepo = ref.read(chatRepositoryProvider);
        await chatRepo.leaveGroup(widget.roomId);
        ref.invalidate(chatRoomsProvider);
        if (mounted) {
          MekaarSnackbar.info(context, 'Anda telah keluar dari grup.');
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (_) {
        if (mounted) MekaarSnackbar.error(context, 'Gagal keluar dari grup.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _groupData?['name'] as String? ?? widget.groupName;
    final description = _groupData?['description'] as String? ?? '';
    final avatarUrl = _groupData?['avatar_url'] as String? ?? widget.groupAvatarUrl;

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: CustomAppBar(
        title: name,
        subtitle: '${_participants.length} Anggota',
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MekaarColors.softCoral),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(MekaarSpacing.lg),
              child: Column(
                children: [
                  // Group Header Card
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor:
                              MekaarColors.softCoral.withValues(alpha: 0.15),
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'G',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: MekaarColors.softCoral,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: MekaarTypography.headingMD.copyWith(
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: MekaarTypography.bodySM.copyWith(
                              color: MekaarColors.textMutedOf(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members Section Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Daftar Anggota (${_participants.length})',
                      style: MekaarTypography.labelMD.copyWith(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: MekaarSpacing.sm),

                  // Members List
                  Container(
                    decoration: BoxDecoration(
                      color: MekaarColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MekaarColors.border.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _participants.length,
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1,
                        color: MekaarColors.border.withValues(alpha: 0.05),
                      ),
                      itemBuilder: (context, index) {
                        final p = _participants[index];
                        final role = p['role'] as String? ?? 'member';
                        final profile = p['public_profiles'] as Map<String, dynamic>? ?? {};
                        final memberName = (profile['display_name'] as String?)?.isNotEmpty == true
                            ? profile['display_name'] as String
                            : profile['full_name'] as String? ??
                                profile['username'] as String? ??
                                'Anggota';
                        final username = profile['username'] as String? ?? '';
                        final memberAvatar = profile['avatar_url'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: MekaarColors.surface2Of(context),
                            backgroundImage: memberAvatar != null && memberAvatar.isNotEmpty
                                ? NetworkImage(memberAvatar)
                                : null,
                            child: memberAvatar == null || memberAvatar.isEmpty
                                ? Text(
                                    memberName.isNotEmpty ? memberName[0].toUpperCase() : 'A',
                                    style: TextStyle(
                                      color: MekaarColors.textPrimaryOf(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            memberName,
                            style: MekaarTypography.bodyMD.copyWith(
                              color: MekaarColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w500,
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
                          trailing: role == 'owner' || role == 'admin'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: MekaarColors.softCoral.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    role == 'owner' ? 'Pembuat' : 'Admin',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: MekaarColors.softCoral,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Leave Group Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _leaveGroup,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MekaarColors.sosRed,
                        side: const BorderSide(color: MekaarColors.sosRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(SolarIconsOutline.logout, size: 20),
                      label: const Text(
                        'Keluar dari Grup',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
