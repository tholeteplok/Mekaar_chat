import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_search_field.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/services/share_intent_service.dart';
import '../../settings/providers/block_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/private_vault_provider.dart';

/// Modal terpusat untuk memilih ruang obrolan target saat menerima share intent
class MekaarShareTargetDialog extends ConsumerStatefulWidget {
  final SharedPayload payload;

  const MekaarShareTargetDialog({
    super.key,
    required this.payload,
  });

  /// Buka modal share target picker secara terpusat
  static Future<void> show(BuildContext context, SharedPayload payload) {
    return MekaarBottomSheet.show(
      context: context,
      title: 'Kirim ke...',
      builder: (ctx) => MekaarShareTargetDialog(payload: payload),
    );
  }

  @override
  ConsumerState<MekaarShareTargetDialog> createState() =>
      _MekaarShareTargetDialogState();
}

class _MekaarShareTargetDialogState
    extends ConsumerState<MekaarShareTargetDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fileNameOf(String path) {
    try {
      final sep = Platform.pathSeparator;
      final idx = path.lastIndexOf(sep);
      if (idx != -1 && idx < path.length - 1) {
        return path.substring(idx + 1);
      }
      final slashIdx = path.lastIndexOf('/');
      if (slashIdx != -1 && slashIdx < path.length - 1) {
        return path.substring(slashIdx + 1);
      }
    } catch (_) {}
    return path;
  }

  Widget _buildPreviewCard(BuildContext context) {
    final payload = widget.payload;
    final hasFiles = payload.hasFiles;
    final hasText = payload.hasText;

    return Container(
      margin: const EdgeInsets.only(bottom: MekaarSpacing.md),
      padding: const EdgeInsets.all(MekaarSpacing.md),
      decoration: BoxDecoration(
        color: MekaarColors.surface2Of(context),
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(
          color: MekaarColors.cardBorderOf(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFiles
                    ? SolarIconsOutline.gallery
                    : SolarIconsOutline.notes,
                size: 18,
                color: MekaarColors.accentOf(context),
              ),
              const SizedBox(width: MekaarSpacing.xs),
              Text(
                hasFiles
                    ? (hasText ? 'Berkas & Pesan Teks' : 'Berkas Terlampir')
                    : 'Pesan Teks',
                style: MekaarTypography.labelSM.copyWith(
                  color: MekaarColors.accentOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: MekaarSpacing.xs),
          if (hasFiles) ...[
            Text(
              payload.filePaths.length == 1
                  ? _fileNameOf(payload.filePaths.first)
                  : '${payload.filePaths.length} berkas dipilih',
              style: MekaarTypography.bodySM.copyWith(
                fontWeight: FontWeight.w600,
                color: MekaarColors.textPrimaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasText) const SizedBox(height: 4),
          ],
          if (hasText)
            Text(
              payload.text!,
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);
    final blockedIds = ref
        .watch(blockProvider)
        .maybeWhen(
          data: (list) => list.map((b) => b.blockedId).toSet(),
          orElse: () => <String>{},
        );

    final cloakedRoomIds = ref.watch(cloakedRoomIdsProvider);
    final cloakedContactUserIds = ref.watch(cloakedContactUserIdsProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final contactsList =
        ref.watch(userContactsProvider).value ?? const <ContactItem>[];
    final vaultedContactIds = contactsList
        .where((c) => c.isVaulted)
        .map((c) => c.contactUserId)
        .toSet();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPreviewCard(context),
          MekaarSearchField(
            controller: _searchController,
            hintText: 'Cari percakapan atau kontak...',
          ),
          const SizedBox(height: MekaarSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: roomsAsync.when(
              data: (rooms) {
                // Saring kontak/ruang yang dilindungi privasi/blokir
                final filtered = rooms.where((room) {
                  final roomId = room['id'] as String? ?? '';
                  final otherUserId = room['otherUserId'] as String?;
                  final name = (room['name'] as String? ?? '').toLowerCase();

                  if (hiddenRoomIds.contains(roomId) ||
                      cloakedRoomIds.contains(roomId)) {
                    return false;
                  }
                  if (otherUserId != null) {
                    if (blockedIds.contains(otherUserId) ||
                        cloakedContactUserIds.contains(otherUserId) ||
                        hiddenContactUserIds.contains(otherUserId) ||
                        vaultedContactIds.contains(otherUserId)) {
                      return false;
                    }
                  }

                  if (_searchQuery.isNotEmpty) {
                    return name.contains(_searchQuery);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: MekaarSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Tidak ada obrolan yang cocok'
                            : 'Belum ada obrolan aktif',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: MekaarColors.cardBorderOf(context),
                  ),
                  itemBuilder: (context, index) {
                    final room = filtered[index];
                    final name = room['name'] as String? ?? 'Percakapan';
                    final avatar = room['avatar'] as String? ?? '';
                    final avatarUrl = room['avatarUrl'] as String?;
                    final isGuardian = room['isGuardian'] as bool? ?? false;
                    final isGroup = room['isGroup'] as bool? ?? false;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MekaarSpacing.xs,
                        vertical: 2,
                      ),
                      leading: Avatar(
                        initial: avatar.isNotEmpty ? avatar : name,
                        imageUrl: avatarUrl,
                        size: 42,
                        isGuardian: isGuardian,
                      ),
                      title: Text(
                        name,
                        style: MekaarTypography.bodyMD.copyWith(
                          fontWeight: FontWeight.w600,
                          color: MekaarColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        isGroup
                            ? 'Grup'
                            : (isGuardian ? 'Guardian' : 'Kontak Pribadi'),
                        style: MekaarTypography.caption.copyWith(
                          color: isGuardian
                              ? MekaarColors.safeTextOf(context)
                              : MekaarColors.textSecondaryOf(context),
                        ),
                      ),
                      trailing: Icon(
                        SolarIconsOutline.arrowRight,
                        size: 18,
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                      onTap: () {
                        final payload = widget.payload;
                        Navigator.of(context).pop();
                        ref.read(sharedPayloadProvider.notifier).clear();

                        Navigator.of(context).pushNamed(
                          AppRoutes.chat,
                          arguments: {
                            'chatId': room['id'] as String? ?? '',
                            'chatName': name,
                            'chatAvatar': avatar,
                            'chatAvatarUrl': avatarUrl,
                            'isGuardian': isGuardian,
                            'isGroup': isGroup,
                            'otherUserId': room['otherUserId'] as String?,
                            'initialSharedText': payload.text,
                            'initialSharedFiles': payload.filePaths,
                          },
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(MekaarSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(MekaarSpacing.lg),
                child: Center(
                  child: Text(
                    'Gagal memuat obrolan',
                    style: MekaarTypography.bodySM.copyWith(
                      color: MekaarColors.sosRed,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MekaarSpacing.md),
        ],
      ),
    );
  }
}
