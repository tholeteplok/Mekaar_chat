import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
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
      duration: MekaarMotion.loop,
    );
    _checkAutoDismiss();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: pulse dimatikan, ikon tampil solid.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
      _pulseController.value = 1;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
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

    IconData iconData;
    Color accentColor;
    String message;
    bool showSpinner = false;

    switch (widget.status) {
      case E2eeRoomStatus.preparing:
        iconData = SolarIconsOutline.shieldKeyhole;
        accentColor = MekaarColors.safeTextOf(context);
        message = 'Mekaar Aegis: Menyiapkan jalur percakapan privat...';
        showSpinner = true;
        break;
      case E2eeRoomStatus.negotiating:
        iconData = SolarIconsOutline.lockKeyhole;
        accentColor = MekaarColors.accentTextOf(context);
        message = 'Mekaar Aegis: Negosiasi kunci kriptografi...';
        showSpinner = true;
        break;
      case E2eeRoomStatus.ready:
        iconData = SolarIconsBold.checkCircle;
        accentColor = MekaarColors.safeTextOf(context);
        message = 'Mekaar Aegis: Percakapan terlindungi E2EE';
        showSpinner = false;
        break;
      case E2eeRoomStatus.peerMissingKey:
        iconData = SolarIconsOutline.infoCircle;
        accentColor = MekaarColors.warnAmber;
        message = 'Menunggu penerima mengaktifkan kunci keamanan Mekaar Aegis';
        showSpinner = false;
        break;
      case E2eeRoomStatus.needsRestore:
        iconData = SolarIconsOutline.keyMinimalisticSquare;
        accentColor = MekaarColors.sosCoral;
        message = 'Kunci Mekaar Aegis perlu dipulihkan dengan PIN';
        showSpinner = false;
        break;
    }

    final borderColor = accentColor.withValues(alpha: 0.3);

    return AnimatedSwitcher(
      duration: MekaarMotion.counter,
      child: Container(
        key: ValueKey(widget.status),
        margin: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.lg, vertical: MekaarSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MekaarColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(MekaarRadius.md),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            FadeTransition(
              opacity: showSpinner && !MediaQuery.disableAnimationsOf(context)
                  ? Tween<double>(begin: 0.4, end: 1.0)
                      .animate(_pulseController)
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
                  color: MekaarColors.textPrimaryOf(context),
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
