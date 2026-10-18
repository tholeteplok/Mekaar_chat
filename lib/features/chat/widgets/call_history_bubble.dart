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

    // Bubble background styling mengikuti token warna resmi Mekaar
    final bubbleBg = isMe
        ? (isDark
            ? MekaarColors.blue.withValues(alpha: 0.22)
            : MekaarColors.blue.withValues(alpha: 0.12))
        : MekaarColors.surfaceOf(context);

    final bubbleBorder = isMe
        ? MekaarColors.blue.withValues(alpha: isDark ? 0.4 : 0.25)
        : (isDark ? MekaarColors.borderDark : MekaarColors.borderLight);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: borderRadius,
          border: Border.all(color: bubbleBorder, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              onCallBack?.call();
            },
            child: Tooltip(
              message: 'Ketuk untuk memanggil balik',
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: 7,
                  bottom: 6,
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
      ),
    );
  }
}
