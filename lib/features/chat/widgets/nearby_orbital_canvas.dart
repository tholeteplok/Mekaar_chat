import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/models/nearby_friend_model.dart';

/// Item avatar yang ditampilkan pada [NearbyOrbitalCanvas].
class OrbitalAvatarItem {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? distanceBadge;
  final NearbyBand band;
  final double avatarSize;
  final bool isContact;
  final bool isRecent;
  final bool isVaultContact;
  final VoidCallback? onTap;

  const OrbitalAvatarItem({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.distanceBadge,
    this.band = NearbyBand.close,
    double? avatarSize,
    this.isContact = true,
    this.isRecent = true,
    this.isVaultContact = false,
    this.onTap,
  }) : avatarSize = avatarSize ??
            (band == NearbyBand.veryClose
                ? 64.0
                : (band == NearbyBand.close ? 52.0 : 42.0));
}

/// Canvas teman sekitar 2D interaktif dengan layout Static Bubble-Packing
/// dan interaksi Momentary Magnet-Drag (pegas kembali ke posisi resting statis).
///
/// Layar diam total saat tidak disentuh (zero ambient loop / zero perpetual ticker).
class NearbyOrbitalCanvas extends StatefulWidget {
  final List<OrbitalAvatarItem> items;
  final double collapseProgress; // 0.0 = full expanded, 1.0 = full collapsed
  final double height;
  final bool isPreview;

  const NearbyOrbitalCanvas({
    super.key,
    required this.items,
    this.collapseProgress = 0.0,
    required this.height,
    this.isPreview = false,
  });

  @override
  State<NearbyOrbitalCanvas> createState() => _NearbyOrbitalCanvasState();
}

class _NearbyOrbitalCanvasState extends State<NearbyOrbitalCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;

  // State seretan pengguna (momentary)
  final Map<int, Offset> _dragOffsets = {};
  final Map<int, Offset> _springStartOffsets = {};
  int? _activeDragIndex;
  Offset _dragStartPos = Offset.zero;
  bool _didDragMove = false;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(() {
        final t = _springController.value;
        // Curve elastic out interpolasi: f(t) = 1.0 -> 0.0
        final factor = (1.0 - Curves.elasticOut.transform(t)).clamp(0.0, 1.0);
        setState(() {
          for (final idx in _springStartOffsets.keys) {
            _dragOffsets[idx] = _springStartOffsets[idx]! * factor;
          }
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  /// Menghitung posisi resting statis avatar (Bubble-Packing terpusat)
  Offset _getStaticRestingPosition(
    int index,
    Offset center,
    double collapse,
    Size canvasSize,
  ) {
    final count = widget.items.length;
    final progress = collapse.clamp(0.0, 1.0);
    final maxH = (widget.height / 2) - 40;
    final maxW = (canvasSize.width / 2) - 46;

    if (count == 1) {
      return center;
    }

    if (count == 2) {
      final double spreadX = 64.0.clamp(0.0, maxW);
      final double offsetY = 10.0 * (1.0 - progress);
      if (index == 0) {
        return Offset(center.dx - spreadX, center.dy - offsetY);
      } else {
        return Offset(center.dx + spreadX, center.dy + offsetY);
      }
    }

    if (count == 3) {
      // Kluster segitiga harmonis bubble-map
      final double rx = 74.0.clamp(0.0, maxW);
      final double ry = (44.0 * (1.0 - 0.55 * progress)).clamp(0.0, maxH);
      if (index == 0) {
        return Offset(center.dx - rx, center.dy - ry * 0.75);
      } else if (index == 1) {
        return Offset(center.dx + rx, center.dy - ry * 0.75);
      } else {
        return Offset(center.dx, center.dy + ry);
      }
    }

    // Count >= 4: Distribusi Circle-Packing statis deterministik (Golden Angle)
    final double angle = (index * 2.39996323) - (math.pi / 2);
    final double dist = 44.0 * math.sqrt(index + 1);
    final double rx = dist.clamp(0.0, maxW);
    final double ry = (dist * (1.0 - 0.55 * progress)).clamp(0.0, maxH);
    return Offset(
      center.dx + rx * math.cos(angle),
      center.dy + ry * math.sin(angle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, widget.height / 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const nodeWidth = 92.0;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ...List.generate(widget.items.length, (index) {
            final item = widget.items[index];
            final resting = _getStaticRestingPosition(
              index,
              center,
              widget.collapseProgress,
              size,
            );
            final drag = _dragOffsets[index] ?? Offset.zero;
            final pos = resting + drag;
            final isDragging = _activeDragIndex == index;
            final avatarRadius = item.avatarSize / 2;

            return Positioned(
              left: pos.dx - (nodeWidth / 2),
              top: pos.dy - avatarRadius,
              width: nodeWidth,
              child: _buildAvatarNode(
                context,
                index,
                item,
                isDragging,
                isDark,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvatarNode(
    BuildContext context,
    int index,
    OrbitalAvatarItem item,
    bool isDragging,
    bool isDark,
  ) {
    final scale = isDragging ? 1.14 : 1.0;
    final avatarDiameter = item.avatarSize;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        HapticService.trigger(MekaarHapticIntent.selection);
        _springController.stop();
        _springStartOffsets.remove(index);
        setState(() {
          _activeDragIndex = index;
          _dragStartPos = details.globalPosition;
          _didDragMove = false;
        });
      },
      onPanUpdate: (details) {
        final totalDelta = details.globalPosition - _dragStartPos;
        if (totalDelta.distance > 4.0) {
          _didDragMove = true;
        }
        setState(() {
          final current = _dragOffsets[index] ?? Offset.zero;
          _dragOffsets[index] = current + details.delta;
        });
      },
      onPanEnd: (details) {
        final currentOffset = _dragOffsets[index] ?? Offset.zero;
        setState(() {
          _activeDragIndex = null;
          if (currentOffset != Offset.zero) {
            _springStartOffsets[index] = currentOffset;
            _springController.forward(from: 0.0);
          }
        });
        if (!_didDragMove) {
          item.onTap?.call();
        }
      },
      onTap: () {
        HapticService.trigger(MekaarHapticIntent.selection);
        item.onTap?.call();
      },
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Circle dengan Glow Guardian Teal HANYA saat di-drag
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: avatarDiameter,
                  height: avatarDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isDragging
                        ? [
                            BoxShadow(
                              color: MekaarColors.guardianTeal.withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ]
                        : const [],
                    border: Border.all(
                      color: isDragging
                          ? MekaarColors.guardianTeal
                          : Colors.white
                              .withValues(alpha: isDark ? 0.35 : 0.65),
                      width: isDragging ? 2.2 : 1.8,
                    ),
                  ),
                  child: ClipOval(
                    child: _buildAvatarImage(item, index, isDark),
                  ),
                ),
                if (item.isVaultContact)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: MekaarColors.accentOf(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MekaarColors.surfaceOf(context),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        SolarIconsOutline.lock,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),

            // Distance Pill Badge & Display Name
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.distanceBadge != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? const Color(0xFF1B2A42)
                              : Colors.white)
                          .withValues(alpha: 0.90),
                      borderRadius:
                          BorderRadius.circular(MekaarRadius.pill),
                      border: Border.all(
                        color: MekaarColors.guardianTeal
                            .withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      item.distanceBadge!,
                      style: MekaarTypography.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? MekaarColors.guardianTeal
                            : MekaarColors.safeTealInk,
                      ),
                    ),
                  ),
                if (item.displayName.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 86),
                    child: Text(
                      item.displayName,
                      style: MekaarTypography.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? MekaarColors.textPrimaryDark
                            : MekaarColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Memuat avatar pengguna atau ilustrasi maskot resmi MEKAAR (Mika, Salma, Croo)
  Widget _buildAvatarImage(
    OrbitalAvatarItem item,
    int index,
    bool isDark,
  ) {
    if (item.avatarUrl != null && item.avatarUrl!.isNotEmpty) {
      return Avatar(
        imageUrl: item.avatarUrl,
        initial: item.displayName.isNotEmpty
            ? item.displayName[0].toUpperCase()
            : '?',
        size: item.avatarSize,
      );
    }

    final mascotAssets = [
      'assets/mascot/avatar/mika.png',
      'assets/mascot/avatar/salma.png',
      'assets/mascot/avatar/croo.png',
    ];
    final assetPath = mascotAssets[index % mascotAssets.length];

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      width: item.avatarSize,
      height: item.avatarSize,
      errorBuilder: (context, error, stackTrace) => Container(
        color: isDark ? const Color(0xFF192C44) : MekaarColors.lightBlue,
        child: Center(
          child: Text(
            item.displayName.isNotEmpty
                ? item.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: item.avatarSize * 0.38,
              color: MekaarColors.guardianTeal,
            ),
          ),
        ),
      ),
    );
  }
}
