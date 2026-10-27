import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../constants/colors.dart';
import '../constants/typography.dart';


/// Item indikator privasi obrolan aktif dengan ikon dan token warna semantik.
class RoomPrivacyIndicatorItem {
  final IconData icon;
  final Color color;

  const RoomPrivacyIndicatorItem({
    required this.icon,
    required this.color,
  });
}

/// Kapsul frosted glass tunggal adaptif untuk menampilkan icon-only indikator privasi obrolan aktif.
class RoomPrivacyIndicatorCapsule extends StatelessWidget {
  final List<RoomPrivacyIndicatorItem> items;
  final VoidCallback? onTap;

  const RoomPrivacyIndicatorCapsule({
    super.key,
    required this.items,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final capsuleContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.50)
            : Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Icon(
              items[i].icon,
              size: 14,
              color: items[i].color,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      label: 'Pengaturan Privasi Obrolan Aktif',
      button: true,
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: capsuleContent,
            ),
          ),
        ),
      ),
    );
  }
}

class ScreenProtectionStatusBadge extends StatelessWidget {
  final String label;
  final bool isFloating;
  final VoidCallback? onTap;

  const ScreenProtectionStatusBadge({
    super.key,
    required this.label,
    this.isFloating = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: MekaarColors.safeTeal.withValues(alpha: isDark ? 0.40 : 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            SolarIconsBold.shieldCheck,
            size: 13,
            color: MekaarColors.safeTeal,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MekaarTypography.caption.copyWith(
                fontSize: 11,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : MekaarColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: label,
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: badgeContent,
            ),
          ),
        ),
      ),
    );
  }
}

class ScreenCaptureProtectionOverlay extends StatelessWidget {
  final bool visible;
  final VoidCallback? onAcknowledged;

  const ScreenCaptureProtectionOverlay({
    super.key,
    required this.visible,
    this.onAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Konten disembunyikan karena perekaman layar terdeteksi',
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: ColoredBox(
              color: MekaarColors.canvasTop.withValues(alpha: 0.9),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: MekaarColors.cardDark.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: MekaarColors.safeTeal.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              SolarIconsOutline.screenShare,
                              size: 52,
                              color: MekaarColors.safeTeal,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Konten disembunyikan',
                              textAlign: TextAlign.center,
                              style: MekaarTypography.headingMD.copyWith(
                                color: MekaarColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Perekaman layar terdeteksi. Konten akan tampil kembali setelah perekaman dihentikan.',
                              textAlign: TextAlign.center,
                              style: MekaarTypography.bodyMD.copyWith(
                                color: MekaarColors.textSecondary,
                              ),
                            ),
                            if (onAcknowledged != null) ...[
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: onAcknowledged,
                                child: const Text('Mengerti'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
