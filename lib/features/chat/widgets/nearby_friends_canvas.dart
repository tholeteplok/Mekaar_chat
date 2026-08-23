import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/bounce_interactive.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_sliding_segment_bar.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/models/nearby_friend_model.dart';
import '../providers/chat_provider.dart';
import '../providers/nearby_friends_provider.dart';
import 'nearby_consent_dialog.dart';

class NearbyFriendsCanvas extends ConsumerWidget {
  const NearbyFriendsCanvas({super.key});

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
    final displayList = state.filteredFriends;

    // ── 1. State Nonaktif: Tampilkan CTA Flat Ramping di Canvas ──
    if (!state.isEnabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                SolarIconsBold.radar2,
                color: MekaarColors.guardianTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teman Sekitar',
                    style: MekaarTypography.bodyMD.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Lihat teman yang aktif di radius dekat',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textMutedOf(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final accept = await NearbyConsentDialog.show(context);
                if (accept) {
                  await ref
                      .read(nearbyFriendsProvider.notifier)
                      .toggleSharing(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.guardianTeal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Aktifkan',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    // ── 2. State Aktif: Tampilkan Langsung pada Canvas (Tanpa Kartu) ──
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
                      .setVisibilityMode(index == 0 ? 'everyone' : 'contacts_only');
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
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Canvas Body (Flat di atas background)
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
            // Floating Avatar Horizontal Scroll List langsung pada canvas
            SizedBox(
              height: 114,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final friend = displayList[index];
                  return _buildFloatingAvatarItem(
                    context,
                    ref,
                    friend,
                    isDark,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingAvatarItem(
    BuildContext context,
    WidgetRef ref,
    NearbyFriendModel friend,
    bool isDark,
  ) {
    final size = friend.band.avatarSize;
    final neutralBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    Widget avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: neutralBorder,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Avatar(
          imageUrl: friend.avatarUrl,
          initial: friend.displayName.isNotEmpty
              ? friend.displayName[0].toUpperCase()
              : '?',
          size: size,
        ),
      ),
    );

    // Jika idle/offline < 1 jam, terapkan efek desaturasi (grayscale)
    if (!friend.isRecent) {
      avatarWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.65, 0,
        ]),
        child: avatarWidget,
      );
    }

    return BounceInteractive(
      onTap: () => _handleFriendTap(context, ref, friend),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Container
            SizedBox(
              height: 68,
              child: Center(child: avatarWidget),
            ),
            const SizedBox(height: 4),

            // Distance Band Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                friend.band.shortLabel,
                style: MekaarTypography.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: friend.isRecent
                      ? MekaarColors.textSecondaryOf(context)
                      : MekaarColors.textMutedOf(context),
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 3),

            // Display Name
            Text(
              friend.displayName,
              style: MekaarTypography.labelSM.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: friend.isRecent
                    ? MekaarColors.textPrimaryOf(context)
                    : MekaarColors.textMutedOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
