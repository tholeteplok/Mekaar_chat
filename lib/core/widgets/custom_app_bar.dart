import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/icons.dart';
import 'avatar.dart';
import 'mekaar_glass_blur_container.dart';

/// CustomAppBar — AppBar terpusat Mekaar.
/// Mendukung dua mode:
/// - [isFloating] = true  → 3 Floating Glass Containers (Back | Kontak | Aksi)
///                          untuk ChatScreen (dirender manual sebagai widget biasa di Stack).
/// - [isFloating] = false → AppBar standar dengan GlassBlur background.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? avatarInitial;
  final String? avatarUrl;
  final bool isGuardian;
  final bool showOnlineIndicator;
  final bool isOnline;
  final List<Widget>? actions;
  final VoidCallback? onBackPress;
  final VoidCallback? onAvatarTap;
  final bool enableGlassBlur;
  final bool isFloating;
  final BoxBorder? glassBorder;
  final Color? glassBackgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final Color? subtitleColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarInitial,
    this.avatarUrl,
    this.isGuardian = false,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.actions,
    this.onBackPress,
    this.onAvatarTap,
    this.enableGlassBlur = true,
    this.isFloating = false,
    this.glassBorder,
    this.glassBackgroundColor,
    this.iconColor,
    this.textColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    if (isFloating) {
      return _buildFloating(context, canPop);
    }

    return _buildStandard(context, canPop);
  }

  // ── Mode Floating: 3 Floating Glass Containers ──────────────────────────
  Widget _buildFloating(BuildContext context, bool canPop) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding + 4,
        left: 8,
        right: 8,
        bottom: 6,
      ),
      child: Row(
        children: [
          // ── Container 1 (Kiri): Tombol Back ──
          if (canPop) ...[
            MekaarGlassBlurContainer(
              isFloating: true,
              shape: BoxShape.circle,
              width: 50,
              height: 50,
              border: glassBorder,
              customColor: glassBackgroundColor,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  MekaarIcons.arrowBackIosNew,
                  size: 18,
                  color: iconColor ?? MekaarColors.textPrimaryOf(context),
                ),
                onPressed: onBackPress ?? () => Navigator.pop(context),
                tooltip: 'Kembali',
              ),
            ),
            const SizedBox(width: 6),
          ],

          // ── Container 2 (Tengah): Informasi Kontak (Avatar, Nama, Status) ──
          Expanded(
            child: Semantics(
              header: true,
              label: '$title, ${subtitle ?? (isOnline ? 'Online' : 'Offline')}',
              hint: onAvatarTap != null ? 'Ketuk untuk membuka profil' : null,
              child: MekaarGlassBlurContainer(
                isFloating: true,
                height: 50,
                borderRadius: BorderRadius.circular(25),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                border: glassBorder,
                customColor: glassBackgroundColor,
                child: InkWell(
                  onTap: onAvatarTap,
                  borderRadius: BorderRadius.circular(25),
                  child: Row(
                    children: [
                      if (avatarInitial != null || avatarUrl != null) ...[
                        Avatar(
                          initial: avatarInitial,
                          imageUrl: avatarUrl,
                          size: 38,
                          isGuardian: isGuardian,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textColor ?? MekaarColors.textPrimaryOf(context),
                                    letterSpacing: -0.2,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (showOnlineIndicator || subtitle != null) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showOnlineIndicator) ...[
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOnline
                                            ? MekaarColors.success
                                            : (subtitleColor ?? MekaarColors.textMutedOf(context)),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      subtitle ?? (isOnline ? 'Online' : 'Offline'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isOnline && showOnlineIndicator
                                            ? MekaarColors.success
                                            : (subtitleColor ?? MekaarColors.textMutedOf(context)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Container 3 (Kanan): Aksi & Menu Dots ──
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 6),
            MekaarGlassBlurContainer(
              isFloating: true,
              shape: actions!.length == 1 ? BoxShape.circle : BoxShape.rectangle,
              width: actions!.length == 1 ? 50 : null,
              height: 50,
              borderRadius: actions!.length == 1 ? null : BorderRadius.circular(25),
              padding: EdgeInsets.symmetric(horizontal: actions!.length == 1 ? 0 : 6),
              border: glassBorder,
              customColor: glassBackgroundColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: actions!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Mode Standard: AppBar biasa dengan GlassBlur ─────────────────────────
  Widget _buildStandard(BuildContext context, bool canPop) {
    return AppBar(
      titleSpacing: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: enableGlassBlur
          ? const MekaarGlassBlurContainer(
              position: BlurPosition.top,
              child: SizedBox.expand(),
            )
          : null,
      leading: canPop
          ? Center(
              child: IconButton(
                tooltip: 'Kembali',
                icon: const Icon(SolarIconsOutline.altArrowLeft, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor:
                      MekaarColors.surface2Of(context).withValues(alpha: 0.85),
                  side: BorderSide(
                    color: MekaarColors.cardBorderOf(context)
                        .withValues(alpha: 0.8),
                    width: 1.0,
                  ),
                  shape: const CircleBorder(),
                ),
                onPressed: onBackPress ?? () => Navigator.pop(context),
              ),
            )
          : null,
      title: Row(
        children: [
          if (avatarInitial != null || avatarUrl != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAvatarTap,
              child: Avatar(
                initial: avatarInitial,
                imageUrl: avatarUrl,
                size: 38,
                isGuardian: isGuardian,
              ),
            ),
            const SizedBox(width: 12),
          ] else if (canPop) ...[
            const SizedBox(width: 8),
          ] else ...[
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (showOnlineIndicator || subtitle != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showOnlineIndicator) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline
                                ? MekaarColors.success
                                : MekaarColors.textMutedOf(context),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        subtitle ?? (isOnline ? 'Online' : 'Offline'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOnline && showOnlineIndicator
                              ? MekaarColors.success
                              : MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(isFloating ? (kToolbarHeight + 20.0) : kToolbarHeight);
}
