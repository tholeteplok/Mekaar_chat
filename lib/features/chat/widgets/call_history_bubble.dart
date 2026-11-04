import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/theme/chat_preset_resolver.dart';
import '../../../core/widgets/bubbles/themed_bubble_container.dart';
import '../../../data/models/call_model.dart';
import '../../../data/models/chat_theme_model.dart';
import '../../settings/providers/chat_theme_provider.dart';

/// Bubble riwayat panggilan suara/video di timeline chat room.
/// Menampilkan tipe panggilan, status (terhubung+durasi, ditolak, tidak terjawab, batal),
/// serta tombol panggil balik yang mengikuti bentuk tema aktif secara dinamis (Opsi B).
class CallHistoryBubble extends ConsumerWidget {
  final CallModel call;
  final bool isMe;
  final VoidCallback? onCallBack;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onSelectionTap;
  final VoidCallback? onSelectionLongPress;
  final ChatBubbleSpec? bubbleSpec;

  const CallHistoryBubble({
    super.key,
    required this.call,
    required this.isMe,
    this.onCallBack,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onSelectionTap,
    this.onSelectionLongPress,
    this.bubbleSpec,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = MekaarColors.isDarkContext(context);
    final isVideo = call.isVideo;
    final isConnected = call.isConnected;

    final chatPref = ref.watch(chatThemeProvider).valueOrNull ??
        const ChatThemePreference();
    final baseSpec = bubbleSpec ??
        ChatPresetResolver.getBubbleSpec(
          chatPref,
          context,
          isMe: isMe,
        );

    // Tentukan warna status dan teks status sesuai konteks panggilan
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (isConnected) {
      statusColor = MekaarColors.successTextOf(context);
      statusText = call.durationSeconds > 0
          ? 'Terhubung • ${call.formattedDuration}'
          : 'Terhubung';
      statusIcon = isMe
          ? SolarIconsOutline.arrowRightUp
          : SolarIconsOutline.arrowLeftDown;
    } else if (call.status == 'declined') {
      statusColor = MekaarColors.sosCoral;
      statusText = isMe ? 'Panggilan ditolak' : 'Ditolak';
      statusIcon = SolarIconsOutline.closeCircle;
    } else if (call.status == 'busy') {
      statusColor = MekaarColors.warning;
      statusText = 'Sedang sibuk';
      statusIcon = SolarIconsOutline.closeCircle;
    } else if (call.status == 'missed') {
      statusColor = isMe
          ? MekaarColors.textSecondaryOf(context)
          : MekaarColors.sosCoral;
      statusText = isMe ? 'Panggilan dibatalkan' : 'Panggilan tak terjawab';
      statusIcon = isMe
          ? SolarIconsOutline.arrowRightUp
          : SolarIconsOutline.arrowLeftDown;
    } else if (call.status == 'failed') {
      statusColor = MekaarColors.sosRed;
      statusText = 'Panggilan gagal';
      statusIcon = SolarIconsOutline.closeCircle;
    } else if (call.status == 'calling') {
      statusColor = MekaarColors.textSecondaryOf(context);
      statusText = isMe ? 'Memanggil...' : 'Panggilan masuk...';
      statusIcon = isMe
          ? SolarIconsOutline.arrowRightUp
          : SolarIconsOutline.arrowLeftDown;
    } else if (call.status == 'ringing') {
      statusColor = MekaarColors.textSecondaryOf(context);
      statusText = isMe ? 'Berdering...' : 'Panggilan masuk...';
      statusIcon = isMe
          ? SolarIconsOutline.arrowRightUp
          : SolarIconsOutline.arrowLeftDown;
    } else {
      statusColor = MekaarColors.textSecondaryOf(context);
      statusText = call.getDisplayStatus(isMe);
      statusIcon = SolarIconsOutline.phoneRounded;
    }

    final title = isVideo ? 'Panggilan video' : 'Panggilan suara';
    final timeStr = DateFormat('HH:mm').format(call.createdAt.toLocal());

    // Opsi B: Mengadopsi bentuk (shape, tail, border, shadow) tema,
    // namun latar belakang tetap menggunakan tint netral lembut
    // agar warna semantik status panggilan (hijau/merah/amber) tetap kontras dan terbaca optimal.
    final normalBg = isMe
        ? (isDark
            ? MekaarColors.blue.withValues(alpha: 0.22)
            : MekaarColors.blue.withValues(alpha: 0.12))
        : MekaarColors.surfaceOf(context);

    final bubbleBg = isSelected
        ? Color.alphaBlend(
            MekaarColors.blue.withValues(
              alpha: isDark ? 0.35 : 0.22,
            ),
            normalBg,
          )
        : normalBg;

    final effectiveBorder = baseSpec.border ??
        Border.all(
          color: isMe
              ? MekaarColors.blue.withValues(alpha: isDark ? 0.4 : 0.25)
              : (isDark ? MekaarColors.borderDark : MekaarColors.borderLight),
          width: 1,
        );

    final effectiveSpec = baseSpec.copyWith(
      backgroundColor: bubbleBg,
      gradient: null, // Tanpa gradien agar tint netral tetap bersih & kontras
      border: effectiveBorder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: GestureDetector(
          onTap: () {
            if (isSelectionMode) {
              onSelectionTap?.call();
            } else {
              HapticService.trigger(MekaarHapticIntent.selection);
              onCallBack?.call();
            }
          },
          onLongPress: onSelectionLongPress != null
              ? () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  onSelectionLongPress!();
                }
              : null,
          child: Tooltip(
            message: isSelectionMode ? '' : 'Ketuk untuk memanggil balik',
            child: ThemedBubbleContainer(
              spec: effectiveSpec,
              isMe: isMe,
              isSelected: isSelected,
              selectionColor: MekaarColors.blue,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge icon bulat dengan warna status (36x36)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isVideo ? MekaarIcons.videocam : MekaarIcons.phone,
                        size: 18,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Kolom teks: Judul & Subtitle status / durasi
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MekaarColors.textPrimaryOf(context),
                            letterSpacing: -0.1,
                            fontFamily: effectiveSpec.fontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 3.5),
                            Flexible(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                  fontFamily: effectiveSpec.fontFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Jam (Timestamp) menempel di kanan bawah
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? MekaarColors.textSecondaryOf(context)
                              : MekaarColors.textMutedOf(context),
                          fontFamily: effectiveSpec.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
