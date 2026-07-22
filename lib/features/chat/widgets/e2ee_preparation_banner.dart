import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../providers/e2ee_room_status_provider.dart';

class E2eePreparationBanner extends StatefulWidget {
  final E2eeRoomStatus status;

  const E2eePreparationBanner({
    super.key,
    required this.status,
  });

  @override
  State<E2eePreparationBanner> createState() => _E2eePreparationBannerState();
}

class _E2eePreparationBannerState extends State<E2eePreparationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _dismissed = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _checkAutoDismiss();
  }

  @override
  void didUpdateWidget(E2eePreparationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      _checkAutoDismiss();
    }
  }

  void _checkAutoDismiss() {
    if (widget.status == E2eeRoomStatus.ready) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() => _dismissed = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData iconData;
    Color accentColor;
    String message;
    bool showSpinner = false;

    switch (widget.status) {
      case E2eeRoomStatus.preparing:
        iconData = SolarIconsOutline.shieldKeyhole;
        accentColor = MekaarColors.cyan;
        message = 'Sistem sedang menyiapkan percakapan yang aman untuk Anda';
        showSpinner = true;
        break;
      case E2eeRoomStatus.negotiating:
        iconData = SolarIconsOutline.lockKeyhole;
        accentColor = MekaarColors.yellow;
        message = 'Proses berjalan...';
        showSpinner = true;
        break;
      case E2eeRoomStatus.ready:
        iconData = SolarIconsBold.checkCircle;
        accentColor = MekaarColors.safeTeal;
        message = 'Selesai, percakapan aman sudah siap';
        showSpinner = false;
        break;
      case E2eeRoomStatus.peerMissingKey:
        iconData = SolarIconsOutline.infoCircle;
        accentColor = MekaarColors.warnAmber;
        message = 'Menunggu penerima mengaktifkan kunci keamanan E2EE';
        showSpinner = false;
        break;
      case E2eeRoomStatus.needsRestore:
        iconData = SolarIconsOutline.keyMinimalisticSquare;
        accentColor = MekaarColors.sosCoral;
        message = 'Kunci lokal perlu dipulihkan dengan PIN';
        showSpinner = false;
        break;
    }

    final bgColor = isDark
        ? MekaarColors.cardDark.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor = accentColor.withValues(alpha: 0.3);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(widget.status),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            FadeTransition(
              opacity: showSpinner
                  ? Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController)
                  : const AlwaysStoppedAnimation(1.0),
              child: Icon(
                iconData,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: MekaarTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : MekaarColors.canvasTop,
                ),
              ),
            ),
            if (showSpinner) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
