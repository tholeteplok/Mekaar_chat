import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';

/// Item avatar yang ditampilkan pada [NearbyOrbitalCanvas].
class OrbitalAvatarItem {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? distanceBadge;
  final bool isContact;
  final bool isRecent;
  final bool isVaultContact;
  final VoidCallback? onTap;

  const OrbitalAvatarItem({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.distanceBadge,
    this.isContact = true,
    this.isRecent = true,
    this.isVaultContact = false,
    this.onTap,
  });
}

/// Canvas orbit interaktif 2D dengan fisika pegas (spring-damper),
/// deteksi tubrukan elastis, dan adaptasi collapse saat scroll.
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
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _springController;

  // State seretan pengguna
  final Map<int, Offset> _dragOffsets = {};
  final Map<int, Offset> _springStartOffsets = {};
  int? _activeDragIndex;
  Offset _dragStartPos = Offset.zero;
  bool _didDragMove = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

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
    _breathController.dispose();
    _springController.dispose();
    super.dispose();
  }

  /// Menghitung posisi tengah avatar ke-i berdasarkan rasio collapse
  Offset _getAvatarCenter(int index, Offset center, double collapse) {
    final count = widget.items.length;
    final progress = collapse.clamp(0.0, 1.0);
    final timeVal = _breathController.value * 2 * math.pi;

    double rx = 100.0;
    double ry = 62.0 * (1.0 - 0.55 * progress);

    double baseAngle;
    if (count == 1) {
      baseAngle = -math.pi / 2;
      rx = 0;
      ry = 0;
    } else if (count == 2) {
      baseAngle = index == 0 ? -math.pi * 0.75 : -math.pi * 0.25;
      rx = 75.0;
      ry = 45.0 * (1.0 - 0.5 * progress);
    } else if (count == 3) {
      // Formasi segitiga asimetris estetik
      final angles = [-math.pi * 0.82, -math.pi * 0.18, math.pi * 0.5];
      final radiiX = [92.0, 96.0, 70.0];
      final radiiY = [
        54.0 * (1.0 - 0.6 * progress),
        58.0 * (1.0 - 0.6 * progress),
        48.0 * (1.0 - 0.6 * progress),
      ];
      baseAngle = angles[index % 3];
      rx = radiiX[index % 3];
      ry = radiiY[index % 3];
    } else {
      baseAngle = (2 * math.pi * index) / count - math.pi / 2;
    }

    // Sinusoidal floating wave per-avatar
    final floatX =
        math.sin(timeVal * 1.35 + index * 2.1) * 3.5 * (1.0 - 0.4 * progress);
    final floatY =
        math.cos(timeVal * 1.1 + index * 1.7) * 4.0 * (1.0 - 0.5 * progress);

    final restingPos = Offset(
      center.dx + rx * math.cos(baseAngle) + floatX,
      center.dy + ry * math.sin(baseAngle) + floatY,
    );

    final drag = _dragOffsets[index] ?? Offset.zero;
    return restingPos + drag;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, widget.height / 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, _) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // ── 1. Background Ambient Pulsing Radar Rings ──
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RadarBackgroundPainter(
                      center: center,
                      animationValue: _breathController.value,
                      collapseProgress: widget.collapseProgress,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),

              // ── 2. Floating Avatar Nodes ──
              ...List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final pos =
                    _getAvatarCenter(index, center, widget.collapseProgress);
                final isDragging = _activeDragIndex == index;

                return Positioned(
                  left: pos.dx - 32,
                  top: pos.dy - 38,
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
      },
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
    const avatarRadius = 25.0;

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
          children: [
            // Avatar Circle dengan Glow Guardian Teal Glass
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: avatarRadius * 2,
                  height: avatarRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MekaarColors.guardianTeal.withValues(
                          alpha: isDragging ? 0.45 : 0.20,
                        ),
                        blurRadius: isDragging ? 18 : 10,
                        spreadRadius: isDragging ? 3 : 1,
                      ),
                    ],
                    border: Border.all(
                      color: isDragging
                          ? MekaarColors.guardianTeal
                          : Colors.white
                              .withValues(alpha: isDark ? 0.35 : 0.65),
                      width: isDragging ? 2.2 : 1.8,
                    ),
                  ),
                  child: ClipOval(
                    child: item.avatarUrl != null
                        ? Avatar(
                            imageUrl: item.avatarUrl,
                            initial: item.displayName.isNotEmpty
                                ? item.displayName[0].toUpperCase()
                                : '?',
                            size: avatarRadius * 2,
                          )
                        : _buildStylizedPlaceholder(item, index, isDark),
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
                    constraints: const BoxConstraints(maxWidth: 80),
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

  /// Placeholder avatar bergaya siluet modern untuk mode preview
  Widget _buildStylizedPlaceholder(
    OrbitalAvatarItem item,
    int index,
    bool isDark,
  ) {
    final icons = [
      SolarIconsBold.user,
      SolarIconsBold.userCheck,
      SolarIconsBold.userHands,
    ];
    final icon = icons[index % icons.length];

    return Container(
      color: isDark
          ? const Color(0xFF192C44)
          : MekaarColors.lightBlue,
      child: Center(
        child: Icon(
          icon,
          size: 24,
          color: MekaarColors.guardianTeal.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// CustomPainter untuk menggambar gelombang radar melingkar konsentris di latar belakang
class _RadarBackgroundPainter extends CustomPainter {
  final Offset center;
  final double animationValue;
  final double collapseProgress;
  final bool isDark;

  _RadarBackgroundPainter({
    required this.center,
    required this.animationValue,
    required this.collapseProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final progress = collapseProgress.clamp(0.0, 1.0);
    final pulse = math.sin(animationValue * 2 * math.pi) * 3.0;

    final rings = [
      (radius: 46.0 + pulse * 0.5, alpha: 0.14),
      (radius: 88.0 + pulse, alpha: 0.10),
      (radius: 132.0 + pulse * 1.2, alpha: 0.06),
    ];

    for (final ring in rings) {
      final rx = ring.radius;
      final ry = ring.radius * (1.0 - 0.55 * progress);

      final paint = Paint()
        ..color = MekaarColors.guardianTeal.withValues(
          alpha: ring.alpha * (1.0 - 0.4 * progress),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: rx * 2,
          height: ry * 2,
        ),
        paint,
      );
    }

    // Pusat radar titik pendar halus
    final centerPaint = Paint()
      ..color = MekaarColors.guardianTeal.withValues(
        alpha: 0.35 * (1.0 - 0.5 * progress),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4.0, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.collapseProgress != collapseProgress ||
        oldDelegate.isDark != isDark;
  }
}
