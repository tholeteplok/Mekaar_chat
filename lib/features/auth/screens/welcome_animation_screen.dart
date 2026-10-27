import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';

/// Layar animasi perkenalan identitas MEKAAR:
/// 1. Babak 1: Konvergensi Harmonis (Balon Chat "Bicara Bebas" & Perisai "Perlindungan")
/// 2. Babak 2: The Genesis Bloom (Fusi Cahaya Radiant Glow & Logo Merekah Organik)
/// 3. Babak 3: Identitas & Kendali (Wordmark, Tagline, dan Tombol "Mulai Sekarang")
/// 4. Babak 4: The Docking Glide (Logo & Wordmark meluncur ke posisi header kiri atas LoginScreen)
class WelcomeAnimationScreen extends ConsumerStatefulWidget {
  const WelcomeAnimationScreen({super.key});

  @override
  ConsumerState<WelcomeAnimationScreen> createState() =>
      _WelcomeAnimationScreenState();
}

class _WelcomeAnimationScreenState extends ConsumerState<WelcomeAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _dockingController;

  bool _hapticTriggered = false;
  bool _isDocking = false;
  bool _navigated = false;

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
        // Auto-advance anggun setelah animasi Babak 3 selesai
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isDocking && !_navigated) {
            _startDocking();
          }
        });
      }
    });

    _dockingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completeNavigation();
      }
    });

    _mainController.forward();
  }

  void _startDocking() {
    if (_isDocking || _navigated) return;
    setState(() => _isDocking = true);
    HapticService.trigger(MekaarHapticIntent.selection);
    _dockingController.forward();
  }

  Future<void> _completeNavigation() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome_animation', true);
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  Future<void> _finishDirectly() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome_animation', true);
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
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

    // Koordinat target presisi di LoginScreen:
    // SingleChildScrollView padding horizontal: 24, vertical: 32 + SizedBox(height: 20)
    final targetX = 24.0;
    final targetY = safePadding.top + 52.0;

    return MekaarScaffold(
      flat: true,
      body: Stack(
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

              return Center(
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: radius,
                    height: radius,
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
              final labelOpacity = (1.0 - approachProgress * 1.5).clamp(0.0, 1.0);

              // Efek melayang halus (bobbing)
              final bobbing = math.sin(val * math.pi * 4) * 3.0;

              return Center(
                child: Opacity(
                  opacity: elementOpacity,
                  child: SizedBox(
                    width: 320,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pilar 1: Balon Obrolan E2EE (Kiri)
                        Transform.translate(
                          offset: Offset(-distance - 20, bobbing),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 62,
                                height: 62,
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
                                      color:
                                          AppColors.safeTeal.withValues(alpha: 0.2),
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
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.blue,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.blue.withValues(alpha: 0.2),
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
              final wordmarkProgress = ((mainVal - 0.60) / 0.22).clamp(0.0, 1.0);
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

              final startLogoX = (screenSize.width - currentLogoSize) / 2;
              final startLogoY = (screenSize.height * 0.38) - (currentLogoSize / 2);

              final currentLogoX = lerpDouble(startLogoX, targetX, dockCurve)!;
              final currentLogoY = lerpDouble(startLogoY, targetY, dockCurve)!;

              // Border radius logo: dari halus rounded saat besar ke MekaarRadius.sm (8.0) di header
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

              // Posisi Wordmark:
              // Saat dockVal = 0: berada di bawah logo di tengah (centerX, centerY + logoSize/2 + 20)
              // Saat dockVal = 1: berada di samping kanan logo (targetX + targetLogoSize + 12, targetY + centerOffset)
              final startWordmarkX = screenSize.width / 2;
              final startWordmarkY =
                  startLogoY + currentLogoSize + 20.0 + (18.0 * (1.0 - wordmarkCurve));

              final targetWordmarkX = targetX + targetLogoSize + 12.0;
              final targetWordmarkY = targetY + 6.0; // Alignment vertikal teks 22px terhadap logo 38px

              // Untuk perpindahan horizontal, interpolasikan posisi X dengan offset teks
              final currentWordmarkX = lerpDouble(
                startWordmarkX,
                targetWordmarkX + 46.0, // Mengimbangi anchor alignment tengah vs kiri
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
                              offset: Offset(0, lerpDouble(8.0, 3.0, dockCurve)!),
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

          // ── Layer 5: Tagline & Tombol Aksi "Mulai Sekarang" (Babak 3) ──
          AnimatedBuilder(
            animation: Listenable.merge([_mainController, _dockingController]),
            builder: (context, child) {
              final mainVal = _mainController.value;
              final dockVal = _dockingController.value;

              // Tagline muncul pada (0.68 - 0.88)
              final taglineProgress = ((mainVal - 0.68) / 0.20).clamp(0.0, 1.0);
              final taglineCurve = Curves.easeOut.transform(taglineProgress);

              // Tombol "Mulai Sekarang" muncul pada (0.76 - 0.95)
              final buttonProgress = ((mainVal - 0.76) / 0.19).clamp(0.0, 1.0);
              final buttonCurve = Curves.easeOutCubic.transform(buttonProgress);

              // Saat docking berjalan, elemen pendukung memudar cepat (0 - 0.3)
              final exitOpacity = (1.0 - (dockVal * 3.0)).clamp(0.0, 1.0);

              if (taglineProgress <= 0.0 || exitOpacity <= 0.0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                bottom: safePadding.bottom + 48,
                left: 24,
                right: 24,
                child: Opacity(
                  opacity: exitOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tagline Resmi
                      Opacity(
                        opacity: taglineCurve,
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
                      const SizedBox(height: 36),

                      // Tombol Aksi Pil "Mulai Sekarang"
                      if (buttonProgress > 0.0)
                        Transform.translate(
                          offset: Offset(0, 16.0 * (1.0 - buttonCurve)),
                          child: Opacity(
                            opacity: buttonCurve,
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _startDocking,
                                icon: const Icon(
                                  SolarIconsOutline.altArrowRight,
                                  size: 18,
                                ),
                                label: Text(
                                  'Mulai Sekarang',
                                  style: MekaarTypography.labelLG.copyWith(
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
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Layer 6: Tombol "Lewati" di Pojok Kanan Atas ──
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
      ),
    );
  }
}
