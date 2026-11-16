import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';

/// WelcomeAnimation â€” â€œDua Sinyal, Satu Ruang Amanâ€ (v2, lebih mulus)
///
/// Ide baru dibanding v1:
/// Dua pilar MEKAAR (balon chat = â€œBicara Bebasâ€, perisai = â€œPerlindunganâ€)
/// tidak lagi *bertabrakan lalu hilang*, melainkan *saling tertarik seperti
/// magnet, menyatu, dan melebur* menjadi logo. Tidak ada satu frame pun
/// yang kosong / pop / potong kasar â€” setiap elemen keluar tepat saat
/// elemen berikutnya masuk (crossfade tumpang-tindih).
///
/// Babak (total tetap 3800ms agar ritme & tes lama tidak berubah):
/// 1. Babak 1 â€” Magnet Approach (0.00â€“0.44)
///    Ikon meluncur mengikuti busur halus (bukan garis lurus), dihubungkan
///    â€œbenang cahayaâ€ yang menegang di tengah perjalanan, melambat dengan
///    kurva magnet (cepat di awal, sangat lembut saat menyentuh), lalu
///    menyusut kecil sambil melebur ke titik inti â€” bukan hilang mendadak.
/// 2. Babak 2 â€” Genesis Bloom v2 (0.34â€“0.70)
///    Titik inti cahaya muncul lebih dulu, disusul DUA cincin shockwave
///    berjenjang + 8 partikel percik, lalu logo mekar dari skala 0.55
///    dengan overshoot easeOutBack yang *dijinakkan* (maks Â±4%) dan
///    diakhiri osilasi teredam (damped settle) â€” terasa â€œmendaratâ€,
///    bukan berhenti mati.
/// 3. Babak 3 â€” Identitas & Kendali (0.58â€“0.95)
///    Wordmark naik + membesar halus, tagline masuk dengan letter-spacing
///    yang menyempit ke posisi normal, tombol naik dengan stagger.
///    Semua dihitung dari SATU AnimatedBuilder (satu sumber kebenaran
///    per frame) agar tidak ada layer yang beda fase / jitter.
/// 4. Babak 4 â€” Docking Arc (480ms, tetap)
///    Logo & wordmark tidak lagi meluncur garis lurus diagonal ke header
///    LoginScreen, melainkan mengikuti busur angkat (arc lift Â±28px di
///    tengah jalan) â€” terasa melayang & mendarat, bukan terseret.
///
/// Aksesibilitas: menghormati reduce-motion sistem (MediaQuery
/// disableAnimations) â€” animasi dilompati ke keadaan akhir yang statis,
/// tanpa putaran / osilasi, dan tanpa auto-docking.
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

/// Kurva pendekatan â€œmagnetâ€: berangkat mantap, melambat sangat halus
/// tepat sebelum menyentuh titik fusi (tanpa hentakan easeInOut di akhir).
const Curve _magnetCurve = Cubic(0.25, 0.80, 0.25, 1.0);

/// Potongan timeline: memetakan progres global 0..1 ke segmen [start, end].
double _seg(double v, double start, double end) =>
    ((v - start) / (end - start)).clamp(0.0, 1.0);

class WelcomeAnimationViewState extends ConsumerState<WelcomeAnimationView>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _dockingController;

  bool _hapticTriggered = false;
  bool _isDocking = false;
  bool _navigated = false;
  bool _reducedMotion = false;
  bool _reduceMotionHandled = false;

  AnimationController get mainController => _mainController;
  AnimationController get dockingController => _dockingController;
  bool get isDocking => _isDocking;

  @override
  void initState() {
    super.initState();

    // Controller utama untuk Babak 1, 2, dan 3 (total durasi tetap 3800ms)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    // Controller docking ke header LoginScreen (tetap 480ms)
    _dockingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _mainController.addListener(() {
      // Haptic tepat saat dua ikon menyatu di tengah (~0.39 / Â±1480ms)
      if (_mainController.value >= 0.39 && !_hapticTriggered) {
        _hapticTriggered = true;
        HapticService.trigger(MekaarHapticIntent.success);
      }
    });

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDocking && !_navigated) {
        if (!widget.isEmbedded && !_reducedMotion) {
          // Auto-advance anggun setelah Babak 3 selesai (standalone)
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotionHandled) return;
    _reduceMotionHandled = true;

    // Hormati preferensi reduce-motion: tampilkan keadaan akhir secara
    // statis, tanpa haptic, tanpa auto-docking. Pengguna tetap bisa
    // menekan â€œMulai Sekarangâ€ / â€œLewatiâ€ sendiri.
    if (MediaQuery.disableAnimationsOf(context)) {
      _reducedMotion = true;
      _hapticTriggered = true; // cegah haptic dari listener
      if (widget.autoStart) {
        _mainController.value = 1.0;
      }
    }
  }

  void playAnimation() {
    _hapticTriggered = false;
    if (_reducedMotion) {
      _mainController.value = 1.0;
      return;
    }
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

    // Titik fokus terpadu: 0.38 Ã— tinggi layar (golden ratio vertikal)
    final focalCenterX = screenSize.width / 2;
    final focalCenterY = screenSize.height * 0.38;

    // Koordinat target presisi di LoginScreen (tetap seperti v1)
    final targetX = 24.0;
    final targetY = safePadding.top + 52.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // â”€â”€ SATU AnimatedBuilder untuk seluruh panggung â”€â”€
        // v1 memakai 4 AnimatedBuilder terpisah yang masing-masing
        // menghitung ulang kurva & memotong layer dengan SizedBox.shrink
        // di ambang berbeda â€” sumber utama kesan â€œpopâ€. Di v2 semua layer
        // dihitung dari nilai (val, dock) yang sama dalam satu frame.
        AnimatedBuilder(
          animation: Listenable.merge([_mainController, _dockingController]),
          builder: (context, child) {
            final val = _mainController.value;
            final dockVal = _dockingController.value;
            final dockCurve = MekaarMotion.emphasized.transform(dockVal);
            final exitOpacity = (1.0 - (dockVal * 3.0)).clamp(0.0, 1.0);

            // â•â•â• Babak 1: Magnet Approach â•â•â•
            final appearCurve =
                MekaarMotion.standard.transform(_seg(val, 0.0, 0.07));
            final approach = _seg(val, 0.04, 0.36);
            final approachCurve = _magnetCurve.transform(approach);

            final startDistance = math.min(130.0, screenSize.width * 0.34);
            final distance = startDistance * (1.0 - approachCurve); // 130 â†’ 0
            final centerGap = distance + 20.0; // jarak pusat ikon ke tengah

            // Busur: ikon terangkat di tengah perjalanan, kembali 0 saat fusi
            final arcLift = math.sin(approach * math.pi) * 10.0;
            // Bobbing teredam: makin dekat fusi, makin tenang
            final bobbing =
                math.sin(approach * math.pi * 3) * 3.0 * (1.0 - approach);

            final fuseShrink = 1.0 - 0.18 * _seg(val, 0.30, 0.38);
            final iconScale = (0.80 + 0.20 * appearCurve) * fuseShrink;
            final iconOpacity = appearCurve * (1.0 - _seg(val, 0.36, 0.44));
            final labelOpacity = appearCurve * (1.0 - _seg(val, 0.10, 0.30));

            // Benang cahaya antar-ikon: menegang di tengah, lepas saat fusi
            final beamOpacity =
                (math.sin(approach * math.pi) * 0.55).clamp(0.0, 1.0) *
                    (1.0 - _seg(val, 0.36, 0.42));

            // â•â•â• Babak 2: Genesis Bloom v2 â•â•â•
            // Titik inti (muncul sebelum logo, menjembatani ikon â†’ logo)
            final coreProgress = _seg(val, 0.34, 0.46);
            final coreOpacity = coreProgress * (1.0 - _seg(val, 0.44, 0.52));
            final coreDiameter = lerpDouble(
                10, 46, MekaarMotion.standard.transform(coreProgress))!;

            // Glow utama (memudar halus juga saat docking, bukan dipotong)
            final glowProgress = _seg(val, 0.38, 0.70);
            final glowRadius = screenSize.width *
                (0.25 + 1.35 * MekaarMotion.standard.transform(glowProgress));
            final glowOpacity = (1.0 - glowProgress) * 0.55 * (1.0 - dockCurve);

            // Logo
            final bloomProgress = _seg(val, 0.40, 0.64);
            // easeOutBack dijinakkan: skala 0.55 â†’ maks Â±1.045 â†’ 1.00
            final bloomScale =
                0.55 + 0.45 * MekaarMotion.bounce.transform(bloomProgress);
            final logoOpacity = _seg(val, 0.40, 0.50);
            // Damped settle + napas akhir yang *berakhir* (bukan loop,
            // agar layar tetap bisa settle & hemat baterai)
            final settleY = math.sin(bloomProgress * math.pi * 2.2) *
                (1.0 - bloomProgress) *
                4.0 *
                bloomProgress;
            final breathProgress = _seg(val, 0.64, 1.0);
            final breathY = math.sin(breathProgress * math.pi * 2) *
                1.5 *
                _seg(val, 0.64, 0.75);

            const startLogoSize = 110.0;
            const targetLogoSize = 38.0;
            final currentLogoSize = lerpDouble(
              startLogoSize * bloomScale,
              targetLogoSize,
              dockCurve,
            )!;
            final startLogoX = focalCenterX - (currentLogoSize / 2);
            final startLogoY =
                focalCenterY - (currentLogoSize / 2) + settleY + breathY;
            // Docking Arc: lurus di X, melengkung naik di Y
            final currentLogoX = lerpDouble(startLogoX, targetX, dockCurve)!;
            final currentLogoY = lerpDouble(startLogoY, targetY, dockCurve)! -
                math.sin(dockCurve * math.pi) * 28.0;
            final currentLogoRadius =
                lerpDouble(24.0, MekaarRadius.sm, dockCurve)!;

            // â•â•â• Babak 3: Wordmark, Tagline, Tombol â•â•â•
            final wordmarkProgress = _seg(val, 0.58, 0.80);
            final wordmarkCurve =
                MekaarMotion.standard.transform(wordmarkProgress);

            const startWordmarkFontSize = 32.0;
            const targetWordmarkFontSize = 22.0;
            final currentWordmarkFontSize = lerpDouble(
              startWordmarkFontSize,
              targetWordmarkFontSize,
              dockCurve,
            )!;

            final startWordmarkX = focalCenterX;
            final startWordmarkY = startLogoY +
                currentLogoSize +
                20.0 +
                (14.0 * (1.0 - wordmarkCurve));
            final targetWordmarkX = targetX + targetLogoSize + 12.0;
            final targetWordmarkY = targetY + 6.0;
            final currentWordmarkX =
                lerpDouble(startWordmarkX, targetWordmarkX, dockCurve)!;
            final currentWordmarkY =
                lerpDouble(startWordmarkY, targetWordmarkY, dockCurve)! -
                    math.sin(dockCurve * math.pi) * 20.0;

            final taglineProgress = _seg(val, 0.66, 0.86);
            final taglineCurve =
                MekaarMotion.standard.transform(taglineProgress);
            final taglineY = focalCenterY + (110.0 / 2) + 68.0;

            final buttonProgress = _seg(val, 0.76, 0.95);
            final buttonCurve = MekaarMotion.standard.transform(buttonProgress);

            // Builder pilar ikon Babak 1 (dipakai dua kali: chat & shield)
            Widget buildPillar({
              required IconData icon,
              required Color color,
              required String label,
              required double xOffset,
              required double yOffset,
              required double tilt,
            }) {
              return Positioned(
                left: focalCenterX + xOffset - 50,
                top: focalCenterY - 31 + yOffset,
                width: 100,
                child: Opacity(
                  opacity: iconOpacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: tilt,
                    child: Transform.scale(
                      scale: iconScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(icon, color: color, size: 32),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: labelOpacity.clamp(0.0, 1.0),
                            child: Text(
                              label,
                              style: MekaarTypography.caption.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // â”€â”€ Glow (Babak 2) â”€â”€
                if (glowOpacity > 0.01)
                  Positioned(
                    left: focalCenterX - (glowRadius / 2),
                    top: focalCenterY - (glowRadius / 2),
                    width: glowRadius,
                    height: glowRadius,
                    child: Opacity(
                      opacity: glowOpacity.clamp(0.0, 1.0),
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
                  ),

                // â”€â”€ Dua cincin shockwave berjenjang (Babak 2) â”€â”€
                for (var ring = 0; ring < 2; ring++)
                  Builder(
                    builder: (context) {
                      final ringStart = 0.38 + ring * 0.05;
                      final ringProgress =
                          _seg(val, ringStart, ringStart + 0.27);
                      if (ringProgress <= 0.0 || ringProgress >= 1.0) {
                        return const SizedBox.shrink();
                      }
                      final radius = lerpDouble(
                        30,
                        screenSize.width * 0.85,
                        MekaarMotion.standard.transform(ringProgress),
                      )!;
                      return Positioned(
                        left: focalCenterX - (radius / 2),
                        top: focalCenterY - (radius / 2),
                        width: radius,
                        height: radius,
                        child: Opacity(
                          opacity:
                              ((1.0 - ringProgress) * 0.35).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ring == 0
                                    ? AppColors.safeTeal
                                    : AppColors.blue,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // â”€â”€ Benang cahaya antar-ikon (Babak 1) â”€â”€
                if (beamOpacity > 0.01)
                  Positioned(
                    left: focalCenterX - centerGap,
                    top: focalCenterY - 1,
                    width: centerGap * 2,
                    height: 2,
                    child: Opacity(
                      opacity: beamOpacity.clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.safeTeal, AppColors.blue],
                          ),
                        ),
                      ),
                    ),
                  ),

                // â”€â”€ 8 partikel percik (Babak 2) â”€â”€
                for (var i = 0; i < 8; i++)
                  Builder(
                    builder: (context) {
                      final sparkProgress = _seg(val, 0.38, 0.62);
                      if (sparkProgress <= 0.0 || sparkProgress >= 1.0) {
                        return const SizedBox.shrink();
                      }
                      final angle = (i * math.pi / 4) + 0.35;
                      final sparkDistance =
                          MekaarMotion.standard.transform(sparkProgress) *
                              (54.0 + (i % 3) * 16.0);
                      final sparkSize = 5.0 - (i % 2) * 2.0;
                      return Positioned(
                        left: focalCenterX +
                            math.cos(angle) * sparkDistance -
                            (sparkSize / 2),
                        top: focalCenterY +
                            math.sin(angle) * sparkDistance -
                            (sparkSize / 2),
                        width: sparkSize,
                        height: sparkSize,
                        child: Opacity(
                          opacity: (1.0 - sparkProgress).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i.isEven
                                  ? AppColors.safeTeal
                                  : AppColors.blue,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // â”€â”€ Titik inti fusi (jembatan ikon â†’ logo) â”€â”€
                if (coreOpacity > 0.01)
                  Positioned(
                    left: focalCenterX - (coreDiameter / 2),
                    top: focalCenterY - (coreDiameter / 2),
                    width: coreDiameter,
                    height: coreDiameter,
                    child: Opacity(
                      opacity: coreOpacity.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Colors.white,
                              AppColors.safeTeal,
                              AppColors.blue,
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // â”€â”€ Dua pilar konvergensi (Babak 1) â”€â”€
                if (val < 0.44) ...[
                  buildPillar(
                    icon: SolarIconsBold.chatRoundDots,
                    color: AppColors.safeTeal,
                    label: 'Bicara Bebas',
                    xOffset: -centerGap,
                    yOffset: -arcLift + bobbing,
                    tilt: 0.06 * (1.0 - approach),
                  ),
                  buildPillar(
                    icon: SolarIconsBold.shieldCheck,
                    color: AppColors.blue,
                    label: 'Perlindungan',
                    xOffset: centerGap,
                    yOffset: -arcLift - bobbing,
                    tilt: -0.06 * (1.0 - approach),
                  ),
                ],

                // â”€â”€ Logo MEKAAR (Babak 2, 3, Docking Arc Babak 4) â”€â”€
                if (bloomProgress > 0.0 || dockVal > 0.0)
                  Positioned(
                    left: currentLogoX,
                    top: currentLogoY,
                    child: Opacity(
                      opacity: logoOpacity.clamp(0.0, 1.0),
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

                // â”€â”€ Wordmark MEKAAR â”€â”€
                if (wordmarkProgress > 0.0)
                  Positioned(
                    left: currentWordmarkX,
                    top: currentWordmarkY,
                    child: FractionalTranslation(
                      translation: Offset(-0.5 * (1.0 - dockCurve), 0.0),
                      child: Opacity(
                        opacity: wordmarkCurve.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.96 + 0.04 * wordmarkCurve,
                          child: MekaarWordmark(
                            fontSize: currentWordmarkFontSize,
                          ),
                        ),
                      ),
                    ),
                  ),

                // â”€â”€ Tagline resmi MEKAAR â”€â”€
                if (taglineProgress > 0.0 && exitOpacity > 0.0)
                  Positioned(
                    top: taglineY + (10.0 * (1.0 - taglineCurve)),
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
                          // Menyempit dari 1.2 â†’ 0.3: terasa â€œmengunciâ€
                          letterSpacing: 0.3 + 0.9 * (1.0 - taglineCurve),
                        ),
                      ),
                    ),
                  ),

                // â”€â”€ Tombol â€œMulai Sekarangâ€ (standalone) â”€â”€
                if (widget.showStandAloneControls &&
                    !widget.isEmbedded &&
                    buttonProgress > 0.0 &&
                    exitOpacity > 0.0)
                  Positioned(
                    bottom: safePadding.bottom + 48,
                    left: 24,
                    right: 24,
                    child: Opacity(
                      opacity: (buttonCurve * exitOpacity).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 20.0 * (1.0 - buttonCurve)),
                        child: Transform.scale(
                          scale: 0.97 + 0.03 * buttonCurve,
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
                                style: MekaarTypography.labelLG.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MekaarColors.accentOf(context),
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
                    ),
                  ),
              ],
            );
          },
        ),

        // â”€â”€ Tombol â€œLewatiâ€ Standalone (tetap seperti v1) â”€â”€
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
