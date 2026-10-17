import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/services/haptic_service.dart';
import '../../../data/models/call_model.dart';

/// Bubble riwayat panggilan suara/video di timeline chat room.
/// Menampilkan tipe panggilan, status (terhubung+durasi, ditolak, tidak terjawab, batal),
/// serta tombol panggil balik yang tersentralisasi.
class CallHistoryBubble extends StatelessWidget {
  final CallModel call;
  final bool isMe;
  final VoidCallback? onCallBack;

  const CallHistoryBubble({
    super.key,
    required this.call,
    required this.isMe,
    this.onCallBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MekaarColors.isDarkContext(context);
    final isVideo = call.isVideo;
    final isConnected = call.isConnected;

    // Tentukan warna status dan teks status
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
    } else {
      statusColor = MekaarColors.textSecondaryOf(context);
      statusText = call.getDisplayStatus(isMe);
      statusIcon = SolarIconsOutline.phoneRounded;
    }

    final title = isVideo
        ? (isMe ? 'Panggilan Video Keluar' : 'Panggilan Video Masuk')
        : (isMe ? 'Panggilan Suara Keluar' : 'Panggilan Suara Masuk');

    final timeStr = DateFormat('HH:mm').format(call.createdAt.toLocal());

    // Bubble background styling mengikuti token warna resmi Mekaar
    final bubbleBg = isMe
        ? (isDark
            ? MekaarColors.blue.withValues(alpha: 0.22)
            : MekaarColors.blue.withValues(alpha: 0.12))
        : MekaarColors.surfaceOf(context);

    final bubbleBorder = isMe
        ? MekaarColors.blue.withValues(alpha: isDark ? 0.4 : 0.25)
        : (isDark ? MekaarColors.borderDark : MekaarColors.borderLight);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
          minWidth: 220,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(color: bubbleBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon badge dengan warna status
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isVideo ? MekaarIcons.videocam : MekaarIcons.phone,
                        size: 20,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Judul dan status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              statusIcon,
                              size: 13,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
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
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? MekaarColors.borderDark : MekaarColors.borderLight,
              ),
              const SizedBox(height: 6),
              // Footer: Tombol Panggil Balik & Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol Panggil Balik
                  InkWell(
                    onTap: () {
                      HapticService.trigger(MekaarHapticIntent.selection);
                      onCallBack?.call();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVideo ? MekaarIcons.videocam : MekaarIcons.phone,
                            size: 14,
                            color: MekaarColors.blue,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Panggil Balik',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: MekaarColors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
