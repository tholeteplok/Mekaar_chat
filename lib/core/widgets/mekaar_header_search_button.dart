import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/motion.dart';
import '../services/haptic_service.dart';

/// Tombol pencarian aksi header dengan efek transisi terbang (*choreographed flight*)
/// dan morphing spasial menuju Search Bar di bawah header.
///
/// Mengintegrasikan gestur tarikan overscroll ([pullProgress]) secara realtime
/// serta animasi kurva pegas saat ditekan ([isSearchActive]).
class MekaarHeaderSearchButton extends StatelessWidget {
  final bool isSearchActive;
  final double pullProgress;
  final VoidCallback onPressed;
  final String tooltip;

  const MekaarHeaderSearchButton({
    super.key,
    required this.isSearchActive,
    this.pullProgress = 0.0,
    required this.onPressed,
    this.tooltip = 'Cari',
  });

  @override
  Widget build(BuildContext context) {
    // Target progres: 1.0 jika aktif, atau nilai pullProgress jika sedang ditarik
    final targetProgress = isSearchActive ? 1.0 : pullProgress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetProgress),
      duration: isSearchActive
          ? context.motion(MekaarMotion.normal)
          : (pullProgress > 0 ? Duration.zero : context.motion(MekaarMotion.fast)),
      curve: MekaarMotion.standard,
      builder: (context, progress, child) {
        // Opasitas memudar halus dan menghilang sebelum progress mencapai 1.0
        final opacity = (1.0 - progress * 1.4).clamp(0.0, 1.0);
        // Translasi meluncur turun ke bawah dan sedikit ke kiri menuju posisi prefix search bar
        final translateY = 18.0 * progress;
        final translateX = -10.0 * progress;
        // Penciutan skala halus
        final scale = 1.0 - (0.28 * progress);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(translateX, translateY),
            child: Transform.scale(
              scale: scale,
              child: IgnorePointer(
                ignoring: progress > 0.1 || isSearchActive,
                child: child,
              ),
            ),
          ),
        );
      },
      child: IconButton(
        icon: Icon(
          SolarIconsOutline.magnifier,
          color: MekaarColors.primaryOf(context),
        ),
        tooltip: tooltip,
        onPressed: () {
          HapticService.trigger(MekaarHapticIntent.selection);
          onPressed();
        },
      ),
    );
  }
}
