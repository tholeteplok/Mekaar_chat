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
import '../../../data/models/nearby_friend_model.dart';
import '../providers/chat_provider.dart';
import '../providers/nearby_friends_provider.dart';
import '../providers/private_vault_provider.dart';
import 'nearby_orbital_canvas.dart';
import 'nearby_teaser_card.dart';

class NearbyFriendsCanvas extends ConsumerWidget {
  final double collapseProgress;

  const NearbyFriendsCanvas({
    super.key,
    this.collapseProgress = 0.0,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVaultUnlocked = ref.watch(privateVaultUnlockedProvider);
    final hiddenRoomIds = ref.watch(hiddenRoomIdsProvider);
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull ?? [];

    final screenH = MediaQuery.sizeOf(context).height;
    // Default 50%-55% layar saat top, menyusut ke 28%-30% saat scroll kontak
    final maxH = (screenH * 0.44).clamp(240.0, 360.0);
    final minH = (screenH * 0.22).clamp(140.0, 190.0);
    final dynamicHeight =
        maxH - (maxH - minH) * collapseProgress.clamp(0.0, 1.0);

    // Kumpulkan userId dari room yang disembunyikan jika vault terkunci (anti-leak)
    final hiddenUserIds = <String>{};
    if (!isVaultUnlocked && hiddenRoomIds.isNotEmpty) {
      for (final r in chatRooms) {
        if (hiddenRoomIds.contains(r['id']) && r['otherUserId'] != null) {
          hiddenUserIds.add(r['otherUserId'] as String);
        }
      }
    }

    final displayList = state.filteredFriends.where((f) {
      if (hiddenUserIds.contains(f.userId)) return false;
      return true;
    }).toList();

    // ── 1. State Nonaktif: Tampilkan Teaser Card Interaktif ──
    if (!state.isEnabled) {
      return NearbyTeaserCard(
        collapseProgress: collapseProgress,
        canvasHeight: dynamicHeight,
        onActivate: () async {
          await ref
              .read(nearbyFriendsProvider.notifier)
              .toggleSharing(true);
        },
      );
    }

    // ── 2. State Aktif: Tampilkan Header + Orbital Physics Canvas ──
    final orbitalItems = displayList.map((friend) {
      final isVaultContact = isVaultUnlocked &&
          hiddenRoomIds.isNotEmpty &&
          chatRooms.any((r) =>
              hiddenRoomIds.contains(r['id']) &&
              r['otherUserId'] == friend.userId);
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

          // Canvas Body
          if (displayList.isEmpty && !state.isLoading) ...[
            // Empty State
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                      child: Icon(
                        SolarIconsOutline.userHands,
                        size: 24,
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.visibilityMode == 'contacts_only'
                          ? 'Belum ada kontak di sekitar'
                          : 'Belum ada teman di sekitar',
                      style: MekaarTypography.bodySM.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Jarak diperbarui otomatis saat aktif di radius < 10 km',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textMutedOf(context),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
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
              height: (dynamicHeight - 44).clamp(120.0, 320.0),
              isPreview: false,
            ),
          ],
        ],
      ),
    );
  }
}
