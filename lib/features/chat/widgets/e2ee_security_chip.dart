import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../providers/e2ee_room_status_provider.dart';

/// Floating security pill chip placed right above the [ChatComposer]
/// in the thumb-zone. Provides contextual feedback for E2EE key status
/// and direct action triggers without obstructing the chat history.
class E2eeSecurityChip extends StatefulWidget {
  final E2eeRoomStatus status;
  final VoidCallback? onRetry;
  final VoidCallback? onRestore;
  final Duration autoDismissDelay;

  const E2eeSecurityChip({
    super.key,
    required this.status,
    this.onRetry,
    this.onRestore,
    this.autoDismissDelay = const Duration(milliseconds: 1500),
  });

  @override
  State<E2eeSecurityChip> createState() => _E2eeSecurityChipState();
}

class _E2eeSecurityChipState extends State<E2eeSecurityChip>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _evaluateDismissState();
  }

  @override
  void didUpdateWidget(E2eeSecurityChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status != E2eeRoomStatus.ready &&
          widget.status != E2eeRoomStatus.groupServerEncrypted) {
        _dismissTimer?.cancel();
        _dismissed = false;
      }
      _evaluateDismissState();
    }
  }

  void _evaluateDismissState() {
    if (widget.status == E2eeRoomStatus.ready ||
        widget.status == E2eeRoomStatus.groupServerEncrypted) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(widget.autoDismissDelay, () {
        if (mounted) {
          setState(() => _dismissed = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final IconData iconData;
    final Color accentColor;
    final String message;
    final bool showSpinner;
    Widget? actionWidget;
    VoidCallback? chipTapAction;

    switch (widget.status) {
      case E2eeRoomStatus.preparing:
        iconData = SolarIconsOutline.shieldKeyhole;
        accentColor = MekaarColors.accentTextOf(context);
        message = 'Percakapan privat sedang dipersiapkan...';
        showSpinner = true;
        break;

      case E2eeRoomStatus.negotiating:
        iconData = SolarIconsOutline.lockKeyhole;
        accentColor = MekaarColors.accentTextOf(context);
        message = 'Negosiasi kunci enkripsi Aegis...';
        showSpinner = true;
        break;

      case E2eeRoomStatus.peerMissingKey:
        iconData = SolarIconsOutline.dangerTriangle;
        accentColor = MekaarColors.warnAmber;
        message = 'Menunggu kunci penerima aktif';
        showSpinner = false;
        if (widget.onRetry != null) {
          actionWidget = _buildActionButton(
            label: 'Coba Lagi',
            icon: SolarIconsOutline.restart,
            color: accentColor,
            onPressed: () {
              HapticService.trigger(MekaarHapticIntent.selection);
              widget.onRetry!();
            },
          );
        }
        break;

      case E2eeRoomStatus.needsRestore:
        iconData = SolarIconsOutline.keyMinimalisticSquare;
        accentColor = MekaarColors.sosCoral;
        message = 'Kunci E2EE perlu dipulihkan via PIN';
        showSpinner = false;
        if (widget.onRestore != null) {
          chipTapAction = () {
            HapticService.trigger(MekaarHapticIntent.selection);
            widget.onRestore!();
          };
          actionWidget = _buildActionButton(
            label: 'Pulihkan',
            icon: SolarIconsOutline.lockUnlocked,
            color: accentColor,
            onPressed: chipTapAction,
          );
        }
        break;

      case E2eeRoomStatus.ready:
        iconData = SolarIconsBold.shieldCheck;
        accentColor = MekaarColors.safeTextOf(context);
        message = 'Terenkripsi End-to-End';
        showSpinner = false;
        break;

      case E2eeRoomStatus.groupServerEncrypted:
        iconData = SolarIconsOutline.shieldCheck;
        accentColor = MekaarColors.textSecondaryOf(context);
        message = 'Enkripsi Server & Transport Aktif';
        showSpinner = false;
        break;
    }

    final surfaceColor = MekaarColors.surfaceOf(context);
    final borderColor = accentColor.withValues(alpha: 0.35);

    return AnimatedSize(
      duration: MekaarMotion.normal,
      curve: Curves.easeInOut,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MekaarSpacing.md,
            vertical: 4,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: chipTapAction,
              borderRadius: BorderRadius.circular(MekaarRadius.pill),
              child: AnimatedContainer(
                duration: MekaarMotion.counter,
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  border: Border.all(color: borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSpinner) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Icon(iconData, size: 15, color: accentColor),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MekaarTypography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MekaarColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    if (actionWidget != null) ...[
                      const SizedBox(width: 8),
                      actionWidget,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(MekaarRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(MekaarRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: MekaarTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
