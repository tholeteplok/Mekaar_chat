import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/motion.dart';
import '../constants/shadows.dart';
import '../constants/typography.dart';
import '../navigation/app_navigator.dart';
import '../services/haptic_service.dart';
import 'avatar.dart';

/// Banner notifikasi in-app mengapung di bagian atas layar (ala WhatsApp / Telegram).
///
/// Digunakan saat notifikasi sistem Android dimatikan di pengaturan HP sehingga
/// statusbar tidak menampilkan notifikasi native, namun pengguna tetap mendapatkan
/// indikator visual senyap saat sedang aktif menggunakan aplikasi.
class MekaarInAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarInitial;
  final String? avatarUrl;
  final bool isGroup;
  final String? groupName;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const MekaarInAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.avatarInitial,
    this.avatarUrl,
    this.isGroup = false,
    this.groupName,
    this.onTap,
    required this.onDismiss,
  });

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  /// Memunculkan banner notifikasi in-app pada overlay teratas.
  /// Jika ada banner sebelumnya yang sedang aktif, banner lama akan ditutup seketika.
  static void show({
    BuildContext? context,
    required String title,
    required String body,
    String? avatarInitial,
    String? avatarUrl,
    bool isGroup = false,
    String? groupName,
    VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    final targetContext = context ?? AppNavigator.currentContext;
    if (targetContext == null) return;

    final overlayState =
        Overlay.maybeOf(targetContext) ??
        AppNavigator.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    dismiss();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return MekaarInAppNotificationBanner(
          title: title,
          body: body,
          avatarInitial: avatarInitial,
          avatarUrl: avatarUrl,
          isGroup: isGroup,
          groupName: groupName,
          onTap: () {
            dismiss();
            onTap?.call();
          },
          onDismiss: dismiss,
        );
      },
    );

    _activeEntry = entry;
    overlayState.insert(entry);

    _activeTimer = Timer(duration, () {
      dismiss();
    });
  }

  /// Menutup banner notifikasi in-app yang sedang aktif.
  static void dismiss() {
    _activeTimer?.cancel();
    _activeTimer = null;
    try {
      _activeEntry?.remove();
    } catch (_) {}
    _activeEntry = null;
  }

  @override
  State<MekaarInAppNotificationBanner> createState() =>
      _MekaarInAppNotificationBannerState();
}

class _MekaarInAppNotificationBannerState
    extends State<MekaarInAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MekaarMotion.normal,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Dismissible(
              key: const Key('mekaar_in_app_banner_dismissible'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: GestureDetector(
                onTap: () {
                  HapticService.trigger(MekaarHapticIntent.selection);
                  widget.onTap?.call();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: MekaarColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MekaarColors.borderOf(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                    boxShadow: MekaarShadows.cardDynamic(context),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Avatar(
                        initial: widget.avatarInitial,
                        imageUrl: widget.avatarUrl,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (widget.isGroup) ...[
                                  Icon(
                                    SolarIconsBold.usersGroupTwoRounded,
                                    size: 14,
                                    color: MekaarColors.accentOf(context),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: MekaarTypography.bodyMD.copyWith(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          MekaarColors.textPrimaryOf(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.body,
                              style: MekaarTypography.caption.copyWith(
                                fontSize: 12.5,
                                color: MekaarColors.textSecondaryOf(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Indikator swipe up / close
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: MekaarColors.borderOf(
                            context,
                          ).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
