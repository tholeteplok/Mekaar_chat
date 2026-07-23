import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../providers/chat_provider.dart';

class CreateGroupDetailsScreen extends ConsumerStatefulWidget {
  final List<String> selectedUserIds;
  final List<Map<String, dynamic>> selectedUserProfiles;

  const CreateGroupDetailsScreen({
    super.key,
    required this.selectedUserIds,
    required this.selectedUserProfiles,
  });

  @override
  ConsumerState<CreateGroupDetailsScreen> createState() =>
      _CreateGroupDetailsScreenState();
}

class _CreateGroupDetailsScreenState
    extends ConsumerState<CreateGroupDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  File? _avatarFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _avatarFile = File(image.path));
    }
  }

  Future<void> _createGroup() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      MekaarSnackbar.error(context, 'Nama grup tidak boleh kosong.');
      return;
    }

    setState(() => _isLoading = true);
    HapticService.trigger(MekaarHapticIntent.selection);

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final roomId = await chatRepo.createGroupRoom(
        name: groupName,
        description: _descController.text.trim(),
        participantIds: widget.selectedUserIds,
      );

      // Refresh list obrolan
      ref.invalidate(chatRoomsProvider);

      if (mounted) {
        MekaarSnackbar.success(context, 'Grup "$groupName" berhasil dibuat!');
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.pushNamed(
          context,
          AppRoutes.chat,
          arguments: {
            'roomId': roomId,
            'userName': groupName,
            'avatar': groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
            'isGuardian': false,
            'isGroup': true,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal membuat grup. Silakan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: const CustomAppBar(
        title: 'Info Grup',
        subtitle: 'Lengkapi nama & foto grup',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MekaarSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            // Avatar Picker
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: MekaarColors.softCoral.withValues(alpha: 0.15),
                    backgroundImage:
                        _avatarFile != null ? FileImage(_avatarFile!) : null,
                    child: _avatarFile == null
                        ? const Icon(
                            SolarIconsOutline.usersGroupTwoRounded,
                            size: 42,
                            color: MekaarColors.softCoral,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: MekaarColors.softCoral,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        SolarIconsOutline.camera,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MekaarSpacing.xl),

            // Group Name Input
            TextField(
              controller: _nameController,
              autofocus: true,
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
              ),
              decoration: InputDecoration(
                labelText: 'Nama Grup *',
                hintText: 'Misal: Keluarga Mekaar, Tim SOS...',
                prefixIcon: const Icon(SolarIconsOutline.usersGroupTwoRounded, size: 20),
                filled: true,
                fillColor: MekaarColors.surface2Of(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: MekaarSpacing.md),

            // Description Input
            TextField(
              controller: _descController,
              maxLines: 2,
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
              ),
              decoration: InputDecoration(
                labelText: 'Deskripsi Grup (Opsional)',
                hintText: 'Tambahkan catatan atau topik grup...',
                prefixIcon: const Icon(SolarIconsOutline.documentText, size: 20),
                filled: true,
                fillColor: MekaarColors.surface2Of(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: MekaarSpacing.xl),

            // Summary of Members
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Anggota (${widget.selectedUserProfiles.length + 1})',
                style: MekaarTypography.labelMD.copyWith(
                  color: MekaarColors.textMutedOf(context),
                ),
              ),
            ),
            const SizedBox(height: MekaarSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: MekaarColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MekaarColors.border.withValues(alpha: 0.1),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.selectedUserProfiles.length,
                separatorBuilder: (ctx, idx) => Divider(
                  height: 1,
                  color: MekaarColors.border.withValues(alpha: 0.05),
                ),
                itemBuilder: (context, index) {
                  final profile = widget.selectedUserProfiles[index];
                  final name = (profile['display_name'] as String?)?.isNotEmpty == true
                      ? profile['display_name'] as String
                      : profile['full_name'] as String? ??
                          profile['username'] as String? ??
                          'Anggota';
                  final username = profile['username'] as String? ?? '';
                  final avatarUrl = profile['avatar_url'] as String?;

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: MekaarColors.surface2Of(context),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'A',
                              style: TextStyle(
                                fontSize: 12,
                                color: MekaarColors.textPrimaryOf(context),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: MekaarTypography.bodyMD.copyWith(
                        color: MekaarColors.textPrimaryOf(context),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MekaarColors.softCoral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(SolarIconsOutline.checkCircle, size: 20),
                label: Text(
                  _isLoading ? 'Membuat Grup...' : 'Buat Grup',
                  style: const TextStyle(
                    fontSize: 16,
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
