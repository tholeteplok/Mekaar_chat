import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/models/contact_model.dart';
import '../../../data/models/nearby_friend_model.dart';
import '../../../data/repositories/contact_repository.dart';
import '../providers/chat_provider.dart';
import '../providers/nearby_friends_provider.dart';
import '../providers/private_vault_provider.dart';
import 'nearby_orbital_canvas.dart';
import 'nearby_teaser_card.dart';
import '../utils/nearby_permission_helper.dart';

class NearbyFriendsCanvas extends ConsumerWidget {
  final double collapseProgress;
  final VoidCallback? onSettingsOpened;
  final bool showInternalHeader;

  const NearbyFriendsCanvas({
    super.key,
    this.collapseProgress = 0.0,
    this.onSettingsOpened,
    this.showInternalHeader = true,
  });

  Future<void> _handleFriendTap(
    BuildContext context,
    WidgetRef ref,
    NearbyFriendModel friend,
  ) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    if (!friend.isContact) {
      if (friend.chatInvitationMode == 'qr_only') {
        MekaarDialog.show(
          context: context,
          title: 'Proteksi Undangan QR',
          body:
              '${friend.displayName} hanya menerima pesan baru melalui pemindaian QR Code kontak langsung.',
        );
        return;
      }

      if (friend.chatInvitationMode == 'approved_only') {
        final confirm = await MekaarDialog.showConfirmation<bool>(
          context: context,
          title: 'Kirim Permintaan Obrolan',
          message:
              '${friend.displayName} berada di sekitar Anda. Kirim permintaan obrolan untuk mulai bertukar pesan?',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.guardianTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kirim Permintaan'),
            ),
          ],
        );
        if (confirm != true) return;
      }
    }

    // Buka atau buat room obrolan
    try {
      final roomId = await ref
          .read(chatRoomsProvider.notifier)
          .getOrCreateRoom(friend.userId, 'direct');

      if (!context.mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: {
          'chatId': roomId,
          'chatName': friend.displayName,
          'chatAvatar': friend.displayName.isNotEmpty
              ? friend.displayName[0].toUpperCase()
              : 'U',
          'chatAvatarUrl': friend.avatarUrl,
          'isGuardian': false,
          'otherUserId': friend.userId,
        },
      );
    } catch (_) {
      if (context.mounted) {
        MekaarSnackbar.error(context, 'Gagal membuka ruang obrolan.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyFriendsProvider);
    final showPreview = ref.watch(nearbyPreviewPreferenceProvider);
    final cloakedContacts = ref.watch(cloakedContactUserIdsProvider);
    final cloakedRooms = ref.watch(cloakedRoomIdsProvider);
    final hiddenContactUserIds = ref.watch(hiddenContactUserIdsProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final contactsList = ref.watch(userContactsProvider).value ?? const <ContactItem>[];
    final vaultedContactUserIds = contactsList.where((c) => c.isVaulted).map((c) => c.contactUserId).toSet();
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull ?? [];

    final screenH = MediaQuery.sizeOf(context).height;
    // Default 50%-55% layar saat top, menyusut ke 28%-30% saat scroll kontak
    final maxH = (screenH * 0.44).clamp(240.0, 360.0);
    final minH = (screenH * 0.22).clamp(140.0, 190.0);
    final dynamicHeight =
        maxH - (maxH - minH) * collapseProgress.clamp(0.0, 1.0);

    // Kumpulkan userId dari room dan kontak yang disembunyikan jika vault terkunci (anti-leak terisolasi per-slot)
    final hiddenUserIds = <String>{...cloakedContacts};
    if (cloakedRooms.isNotEmpty) {
      for (final r in chatRooms) {
        if (cloakedRooms.contains(r['id']) && r['otherUserId'] != null) {
          hiddenUserIds.add(r['otherUserId'] as String);
        }
      }
    }

    final displayList = state.filteredFriends.where((f) {
      if (hiddenUserIds.contains(f.userId)) return false;
      return true;
    }).toList();

    // ── 1. State Nonaktif: Tampilkan Teaser Card Interaktif (jika preview on) atau Empty State Mika (jika preview off) ──
    if (!state.isEnabled) {
      if (showPreview) {
        return NearbyTeaserCard(
          collapseProgress: collapseProgress,
          canvasHeight: dynamicHeight,
          onActivate: () async {
            await NearbyPermissionHelper.activateWithPermissionCheck(
              context,
              ref,
              onSettingsOpened: onSettingsOpened,
            );
          },
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              const MikaIllustration(
                type: MikaIllustrationType.emptyContacts,
                size: 160,
              ),
              const SizedBox(height: 20),
              Text(
                'Teman Sekitar Dinonaktifkan',
                style: MekaarTypography.headingMD.copyWith(
                  color: MekaarColors.textPrimaryOf(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Aktifkan fitur ini untuk mendeteksi teman atau kontak yang berada di sekitar Anda secara aman.',
                style: MekaarTypography.bodyMD.copyWith(
                  color: MekaarColors.textSecondaryOf(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(SolarIconsOutline.radar2, size: 18),
                label: const Text('Aktifkan Teman Sekitar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MekaarColors.guardianTeal,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                onPressed: () async {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  await NearbyPermissionHelper.activateWithPermissionCheck(
                    context,
                    ref,
                    onSettingsOpened: onSettingsOpened,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // ── 2. State Aktif: Tampilkan Header + Orbital Physics Canvas ──
    final orbitalItems = displayList.map((friend) {
      final isVaultContact = vaultedContactUserIds.contains(friend.userId) ||
          hiddenContactUserIds.contains(friend.userId) ||
          (hiddenRoomIds.isNotEmpty &&
              chatRooms.any((r) =>
                  hiddenRoomIds.contains(r['id']) &&
                  r['otherUserId'] == friend.userId));
      return OrbitalAvatarItem(
        id: friend.userId,
        displayName: friend.displayName,
        avatarUrl: friend.avatarUrl,
        distanceBadge: friend.band.label,
        band: friend.band,
        avatarSize: friend.band.avatarSize,
        isContact: friend.isContact,
        isRecent: friend.isRecent,
        isVaultContact: isVaultContact,
        onTap: () => _handleFriendTap(context, ref, friend),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showInternalHeader) ...[
            // Header Section: Teman Sekitar
            Row(
              children: [
                const Icon(
                  SolarIconsBold.radar2,
                  color: MekaarColors.guardianTeal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Teman Sekitar',
                  style: MekaarTypography.bodyMD.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Filter Segmen: [Semua] [Kontak]
                MekaarSlidingSegmentBar(
                  tabs: const ['Semua', 'Kontak'],
                  selectedIndex: state.visibilityMode == 'everyone' ? 0 : 1,
                  onTabSelected: (index) {
                    ref
                        .read(nearbyFriendsProvider.notifier)
                        .setVisibilityMode(
                            index == 0 ? 'everyone' : 'contacts_only');
                  },
                  height: 28,
                  width: 135,
                  margin: EdgeInsets.zero,
                  activeColor: MekaarColors.guardianTeal,
                ),
                const SizedBox(width: 6),
                // Refresh Action
                IconButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                          .read(nearbyFriendsProvider.notifier)
                          .refreshNearby(force: true),
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MekaarColors.guardianTeal,
                          ),
                        )
                      : Icon(
                          SolarIconsOutline.refreshCircle,
                          size: 18,
                          color: MekaarColors.textMutedOf(context),
                        ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Canvas Body
          if (displayList.isEmpty && !state.isLoading) ...[
            // Empty State (Selaras dengan Kontak Kosong)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    const MikaIllustration(
                      type: MikaIllustrationType.emptyContacts,
                      size: 160,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      state.visibilityMode == 'contacts_only'
                          ? 'Belum Ada Kontak di Sekitar'
                          : 'Belum Ada Teman di Sekitar',
                      style: MekaarTypography.headingMD.copyWith(
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.visibilityMode == 'contacts_only'
                          ? 'Tidak ada kontak Anda yang aktif dalam radius < 10 km. Jarak akan diperbarui otomatis saat mereka daring.'
                          : 'Belum ada pengguna di sekitar Anda dalam radius < 10 km. Jarak akan diperbarui otomatis saat mereka daring.',
                      style: MekaarTypography.bodyMD.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(SolarIconsOutline.restart, size: 18),
                      label: const Text('Pindai Ulang'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MekaarColors.guardianTeal,
                        side:
                            const BorderSide(color: MekaarColors.guardianTeal),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        ref
                            .read(nearbyFriendsProvider.notifier)
                            .refreshNearby(force: true);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Orbital Physics Canvas untuk data teman aktif
            NearbyOrbitalCanvas(
              items: orbitalItems,
              collapseProgress: collapseProgress,
              height: showInternalHeader
                  ? (dynamicHeight - 44).clamp(120.0, 320.0)
                  : dynamicHeight.clamp(200.0, 360.0),
              isPreview: false,
            ),
          ],
        ],
      ),
    );
  }
}
