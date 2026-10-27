import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';

/// Komponen animasi perkenalan identitas MEKAAR:
/// 1. Babak 1: Konvergensi Harmonis (Balon Chat "Bicara Bebas" & Perisai "Perlindungan")
/// 2. Babak 2: The Genesis Bloom (Fusi Cahaya Radiant Glow & Logo Merekah Organik)
/// 3. Babak 3: Identitas & Kendali (Wordmark, Tagline, dan Tombol "Mulai Sekarang")
/// 4. Babak 4: The Docking Glide (Logo & Wordmark meluncur ke posisi header kiri atas LoginScreen)
class WelcomeAnimationView extends ConsumerStatefulWidget {
  const WelcomeAnimationView({
    super.key,
    this.isEmbedded = false,
    this.autoStart = true,
    this.showStandAloneControls = true,
    this.onDockingStarted,
    this.onDockingComplete,
    this.onSkip,
  });

  final bool isEmbedded;
  final bool autoStart;
  final bool showStandAloneControls;
  final VoidCallback? onDockingStarted;
  final VoidCallback? onDockingComplete;
  final VoidCallback? onSkip;

  @override
  ConsumerState<WelcomeAnimationView> createState() =>
      WelcomeAnimationViewState();
}

class WelcomeAnimationViewState extends ConsumerState<WelcomeAnimationView>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _dockingController;

  bool _hapticTriggered = false;
  bool _isDocking = false;
  bool _navigated = false;

  AnimationController get mainController => _mainController;
  AnimationController get dockingController => _dockingController;
  bool get isDocking => _isDocking;

  @override
  void initState() {
    super.initState();

    // Controller utama untuk Babak 1, 2, dan 3 (total durasi 3800ms)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Controller peluncuran / docking ke header LoginScreen (durasi 480ms)
    _dockingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _mainController.addListener(() {
      // Pemicu getaran haptic tepat saat kedua ikon bertabrakan di tengah (~1444ms)
      if (_mainController.value >= 0.38 && !_hapticTriggered) {
        _hapticTriggered = true;
        HapticService.trigger(MekaarHapticIntent.success);
      }
    });

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDocking && !_navigated) {
        if (!widget.isEmbedded) {
          // Auto-advance anggun setelah animasi Babak 3 selesai di standalone screen
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isDocking && !_navigated) {
              startDocking();
            }
          });
        }
      }
    });

    _dockingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completeNavigation();
      }
    });

    if (widget.autoStart) {
      _mainController.forward();
    }
  }

  void playAnimation() {
    _hapticTriggered = false;
    _mainController.forward(from: 0.0);
  }

  void resetAnimation() {
    _hapticTriggered = false;
    _mainController.reset();
    _dockingController.reset();
    _isDocking = false;
  }

  void startDocking() {
    if (_isDocking || _navigated) return;
    setState(() => _isDocking = true);
    widget.onDockingStarted?.call();
    HapticService.trigger(MekaarHapticIntent.selection);
    _dockingController.forward();
  }

  void _completeNavigation() {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (widget.onDockingComplete != null) {
      widget.onDockingComplete!();
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  void _finishDirectly() {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _dockingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);

    // Titik fokus Y terpadu (Unified Focal Center):
    // 0.38 x tinggi layar memastikan logo & efek fusi berada di posisi golden ratio vertikal,
    // menyisakan ruang ideal untuk Wordmark, Tagline, dan Tombol Mulai Sekarang di area bawah.
    final focalCenterX = screenSize.width / 2;
    final focalCenterY = screenSize.height * 0.38;

    // Koordinat target presisi di LoginScreen:
    // SingleChildScrollView padding horizontal: 24, vertical: 32 + SizedBox(height: 20)
    final targetX = 24.0;
    final targetY = safePadding.top + 52.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Ambient Radiant Glow Shockwave (Babak 2) ──
        AnimatedBuilder(
          animation: Listenable.merge([_mainController, _dockingController]),
          builder: (context, child) {
            final val = _mainController.value;
            final dockVal = _dockingController.value;

            if (val < 0.36 || dockVal > 0.0) return const SizedBox.shrink();

            // Gelombang cahaya merekah dari titik sentuh tengah (0.36 - 0.65)
            final t = ((val - 0.36) / 0.29).clamp(0.0, 1.0);
            final scale = Curves.easeOutQuad.transform(t);
            final opacity = (1.0 - t).clamp(0.0, 0.7);

            final radius = screenSize.width * (0.2 + 1.6 * scale);

            return Positioned(
              left: focalCenterX - (radius / 2),
              top: focalCenterY - (radius / 2),
              width: radius,
              height: radius,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.safeTeal.withValues(alpha: 0.35),
                        AppColors.blue.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // ── Layer 2: Dua Pilar Konvergensi (Babak 1: Chat & Shield) ──
        AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            final val = _mainController.value;
            if (val >= 0.40) return const SizedBox.shrink();

            // Fase Pendekatan Halus (0.00 - 0.38)
            final approachProgress = (val / 0.38).clamp(0.0, 1.0);
            final curvedApproach =
                Curves.easeInOutCubic.transform(approachProgress);

            // Jarak dari luar menuju pusat
            final distance = 130.0 * (1.0 - curvedApproach);

            // Opasitas muncul di awal dan memudar di detik tabrakan
            double elementOpacity = 1.0;
            if (val < 0.12) {
              elementOpacity = (val / 0.12).clamp(0.0, 1.0);
            } else if (val > 0.34) {
              elementOpacity = (1.0 - ((val - 0.34) / 0.04)).clamp(0.0, 1.0);
            }

            // Mikro-label memudar saat mendekati sentuhan
            final labelOpacity =
                (1.0 - approachProgress * 1.5).clamp(0.0, 1.0);

            // Efek melayang halus (bobbing)
            final bobbing = math.sin(val * math.pi * 4) * 3.0;

            const iconDiameter = 62.0;

            return Positioned(
              left: 0,
              right: 0,
              top: focalCenterY - (iconDiameter / 2),
              child: Opacity(
                opacity: elementOpacity,
                child: SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Pilar 1: Balon Obrolan E2EE (Kiri)
                      Transform.translate(
                        offset: Offset(-distance - 20, bobbing),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: iconDiameter,
                              height: iconDiameter,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.safeTeal.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.safeTeal,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.safeTeal
                                        .withValues(alpha: 0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  SolarIconsBold.chatRoundDots,
                                  color: AppColors.safeTeal,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: labelOpacity,
                              child: Text(
                                'Bicara Bebas',
                                style: MekaarTypography.caption.copyWith(
                                  color: AppColors.safeTeal,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Pilar 2: Perisai Guardian (Kanan)
                      Transform.translate(
                        offset: Offset(distance + 20, -bobbing),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: iconDiameter,
                              height: iconDiameter,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.blue,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.blue.withValues(alpha: 0.2),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  SolarIconsBold.shieldCheck,
                                  color: AppColors.blue,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: labelOpacity,
                              child: Text(
                                'Perlindungan',
                                style: MekaarTypography.caption.copyWith(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // ── Layer 3 & 4: Logo & Wordmark (Babak 2, 3, dan Docking Glide Babak 4) ──
        AnimatedBuilder(
          animation: Listenable.merge([_mainController, _dockingController]),
          builder: (context, child) {
            final mainVal = _mainController.value;
            final dockVal = _dockingController.value;

            if (mainVal < 0.38) return const SizedBox.shrink();

            // Kemunculan Logo di Pusat (0.38 - 0.62)
            final bloomProgress = ((mainVal - 0.38) / 0.24).clamp(0.0, 1.0);
            final bloomCurve = Curves.easeOutBack.transform(bloomProgress);
            final bloomOpacity = ((mainVal - 0.38) / 0.12).clamp(0.0, 1.0);

            // Kemunculan Wordmark di Pusat (0.60 - 0.82)
            final wordmarkProgress =
                ((mainVal - 0.60) / 0.22).clamp(0.0, 1.0);
            final wordmarkCurve =
                Curves.easeOutCubic.transform(wordmarkProgress);

            // ── Docking Glide Interpolation (Babak 4) ──
            final dockCurve = Curves.easeInOutCubic.transform(dockVal);

            // Parameter Logo
            final startLogoSize = 110.0;
            final targetLogoSize = 38.0;
            final currentLogoSize = lerpDouble(
              startLogoSize * (bloomProgress < 1.0 ? bloomCurve : 1.0),
              targetLogoSize,
              dockCurve,
            )!;

            // Pusat awal logo tepat di (focalCenterX, focalCenterY)
            final startLogoX = focalCenterX - (currentLogoSize / 2);
            final startLogoY = focalCenterY - (currentLogoSize / 2);

            final currentLogoX = lerpDouble(startLogoX, targetX, dockCurve)!;
            final currentLogoY = lerpDouble(startLogoY, targetY, dockCurve)!;

            final currentLogoRadius =
                lerpDouble(24.0, MekaarRadius.sm, dockCurve)!;

            // Parameter Wordmark
            final startWordmarkFontSize = 32.0;
            final targetWordmarkFontSize = 22.0;
            final currentWordmarkFontSize = lerpDouble(
              startWordmarkFontSize,
              targetWordmarkFontSize,
              dockCurve,
            )!;

            final startWordmarkX = focalCenterX;
            final startWordmarkY = startLogoY +
                currentLogoSize +
                20.0 +
                (18.0 * (1.0 - wordmarkCurve));

            final targetWordmarkX = targetX + targetLogoSize + 12.0;
            final targetWordmarkY = targetY + 6.0;

            final currentWordmarkX = lerpDouble(
              startWordmarkX,
              targetWordmarkX + 46.0,
              dockCurve,
            )!;
            final currentWordmarkY =
                lerpDouble(startWordmarkY, targetWordmarkY, dockCurve)!;

            return Stack(
              children: [
                // Logo MEKAAR
                Positioned(
                  left: currentLogoX,
                  top: currentLogoY,
                  child: Opacity(
                    opacity: bloomOpacity,
                    child: Container(
                      width: currentLogoSize,
                      height: currentLogoSize,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(currentLogoRadius),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue.withValues(
                              alpha: lerpDouble(0.25, 0.15, dockCurve)!,
                            ),
                            blurRadius: lerpDouble(20.0, 8.0, dockCurve)!,
                            offset:
                                Offset(0, lerpDouble(8.0, 3.0, dockCurve)!),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(currentLogoRadius),
                        child: Image.asset(
                          'assets/logo/app_icon.webp',
                          width: currentLogoSize,
                          height: currentLogoSize,
                          fit: BoxFit.cover,
                          semanticLabel: 'Logo MEKAAR',
                        ),
                      ),
                    ),
                  ),
                ),

                // Wordmark MEKAAR
                if (wordmarkProgress > 0.0)
                  Positioned(
                    left: currentWordmarkX -
                        (dockCurve < 0.5 ? 60.0 * (1.0 - dockCurve) : 46.0),
                    top: currentWordmarkY,
                    child: Opacity(
                      opacity: wordmarkCurve,
                      child: MekaarWordmark(
                        fontSize: currentWordmarkFontSize,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // ── Layer 5: Tagline & Standalone Action Button ──
        AnimatedBuilder(
          animation: Listenable.merge([_mainController, _dockingController]),
          builder: (context, child) {
            final mainVal = _mainController.value;
            final dockVal = _dockingController.value;

            final taglineProgress =
                ((mainVal - 0.68) / 0.20).clamp(0.0, 1.0);
            final taglineCurve = Curves.easeOut.transform(taglineProgress);

            final buttonProgress =
                ((mainVal - 0.76) / 0.19).clamp(0.0, 1.0);
            final buttonCurve = Curves.easeOutCubic.transform(buttonProgress);

            final exitOpacity = (1.0 - (dockVal * 3.0)).clamp(0.0, 1.0);

            if (taglineProgress <= 0.0 || exitOpacity <= 0.0) {
              return const SizedBox.shrink();
            }

            final taglineY = focalCenterY + (110.0 / 2) + 68.0;

            return Stack(
              children: [
                // Tagline Resmi MEKAAR
                Positioned(
                  top: taglineY,
                  left: 24,
                  right: 24,
                  child: Opacity(
                    opacity: (taglineCurve * exitOpacity).clamp(0.0, 1.0),
                    child: Text(
                      'Bicara bebas. Tetap aman.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: MekaarColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                // Tombol "Mulai Sekarang" untuk Standalone mode
                if (widget.showStandAloneControls && !widget.isEmbedded)
                  Positioned(
                    bottom: safePadding.bottom + 48,
                    left: 24,
                    right: 24,
                    child: Opacity(
                      opacity: exitOpacity,
                      child: buttonProgress > 0.0
                          ? Transform.translate(
                              offset: Offset(0, 16.0 * (1.0 - buttonCurve)),
                              child: Opacity(
                                opacity: buttonCurve,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: startDocking,
                                    icon: const Icon(
                                      SolarIconsOutline.altArrowRight,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Mulai Sekarang',
                                      style:
                                          MekaarTypography.labelLG.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          MekaarColors.accentOf(context),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          MekaarRadius.pill,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            );
          },
        ),

        // ── Layer 6: Tombol "Lewati" Standalone ──
        if (widget.showStandAloneControls && !widget.isEmbedded)
          Positioned(
            top: safePadding.top + 16,
            right: 16,
            child: AnimatedBuilder(
              animation: _dockingController,
              builder: (context, child) {
                final dockVal = _dockingController.value;
                final exitOpacity = (1.0 - dockVal * 4.0).clamp(0.0, 1.0);
                if (exitOpacity <= 0.0) return const SizedBox.shrink();

                return Opacity(
                  opacity: exitOpacity,
                  child: TextButton(
                    onPressed: _finishDirectly,
                    style: TextButton.styleFrom(
                      foregroundColor: MekaarColors.textSecondaryOf(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Lewati',
                      style: MekaarTypography.labelLG.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Standalone Screen wrapper untuk WelcomeAnimationView
class WelcomeAnimationScreen extends StatelessWidget {
  const WelcomeAnimationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MekaarScaffold(
      flat: true,
      body: WelcomeAnimationView(
        isEmbedded: false,
        showStandAloneControls: true,
      ),
    );
  }
}
