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

/// WelcomeAnimation — “Dua User, Satu Ruang Aman” (v3)
///
/// Menggantikan koreografi v2. Ceritanya kini harfiah menggambarkan
/// produknya — ruang obrolan privat antara dua orang:
///
/// Babak (total 7000ms — layar ini tampil sekali saat instalasi baru
/// sebagai bagian onboarding, jadi durasinya bebas bernapas seperti
/// referensi logo-animation 6–10 detik; ia BUKAN splash berulang):
/// 1. Babak 1 — Dua User (0.0–1.4 dtk)
///    Dua figur user (mint = safeTeal, biru = AppColors.blue) muncul di
///    kiri & kanan bawah. Dari masing-masing user *keluar* satu gelembung
///    percakapan yang tumbuh dari arah kepalanya (easeOutBack jinak).
/// 2. Babak 2 — Percakapan (1.3–2.7 dtk)
///    Titik ketikan kedua gelembung menyala BERGANTIAN — seperti dua
///    orang sungguhan sedang chatting. Gelembung berayun halus (bobbing).
/// 3. Babak 3 — Fokus & Penggabungan (2.6–4.4 dtk)
///    Gelembung saling mendekat (kurva magnet). Bersamaan: kedua user
///    MEMUDAR dan tenggelam, kamera mendorong masuk (zoom 1.0 → 1.28 ke
///    titik fokus), dan lingkaran “ruang aman” tergambar mengelilingi
///    gelembung. Di puncak zoom kedua gelembung docking melebur jadi
///    SATU gelembung di dalam lingkaran yang menutup + satu denyut.
/// 4. Babak 4 — Jembatan ke Logo (4.4–5.8 dtk)
///    Kamera mundur ke 1.0. Gelembung tunggal memudar bersilangan
///    (crossfade) menjadi logo MEKAAR resmi — posisi & ukuran akhir
///    sama persis dengan v2 — lalu wordmark resmi naik, tagline masuk.
/// 5. Babak 5 — Kendali (6.0–7.0 dtk)
///    Tombol “Mulai Sekarang” naik; “Lewati” tersedia sejak awal.
///
/// Routing TIDAK berubah dari v2: layar ini menyatu dengan onboarding
/// (mode isEmbedded + callback) dan menjadi jembatan ke auth screen —
/// docking arc 480ms ke header LoginScreen lalu navigasi ke
/// AppRoutes.login, persis seperti sebelumnya.
///
/// Teknis: seluruh adegan (user, gelembung, titik, lingkaran) digambar
/// SATU CustomPainter dari satu AnimatedBuilder — transform & path saja,
/// tanpa rebuild pohon widget per frame. Zoom kamera adalah Transform
/// matriks pada layer adegan saja.
///
/// Aksesibilitas: menghormati reduce-motion sistem — animasi dilompati
/// ke keadaan akhir statis, tanpa auto-docking.
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

/// Kurva pendekatan “magnet”: berangkat mantap, melambat sangat halus
/// tepat sebelum menyentuh titik fusi.
const Curve _magnetCurve = Cubic(0.25, 0.80, 0.25, 1.0);

/// Potongan timeline: memetakan progres global 0..1 ke segmen [start, end].
double _seg(double v, double start, double end) =>
    ((v - start) / (end - start)).clamp(0.0, 1.0);

/// Sama seperti [_seg], tetapi dalam detik (garis waktu adegan = 7 dtk).
double _segS(double s, double start, double end) =>
    ((s - start) / (end - start)).clamp(0.0, 1.0);

double _easeOutCubicS(double x) {
  final t = x.clamp(0.0, 1.0);
  return 1.0 - math.pow(1.0 - t, 3).toDouble();
}

double _easeInOutCubicS(double x) {
  final t = x.clamp(0.0, 1.0);
  return t < 0.5
      ? 4.0 * t * t * t
      : 1.0 - (math.pow(-2.0 * t + 2.0, 3) / 2).toDouble();
}

/// easeOutBack yang dijinakkan (c1 = 1.2, overshoot maks ±5%).
double _easeOutBackTamed(double x) {
  final t = x.clamp(0.0, 1.0);
  const c1 = 1.2;
  return 1.0 + (c1 + 1.0) * math.pow(t - 1.0, 3) + c1 * math.pow(t - 1.0, 2);
}

/// Zoom kamera adegan: dorong masuk 2.6–3.9 dtk (→1.28), tahan,
/// mundur 4.45–5.1 dtk (→1.0).
double _cameraZoom(double s) {
  if (s < 2.6) return 1.0;
  if (s < 3.9) return lerpDouble(1.0, 1.28, _easeInOutCubicS((s - 2.6) / 1.3))!;
  if (s < 4.45) return 1.28;
  if (s < 5.1) {
    return lerpDouble(1.28, 1.0, _easeInOutCubicS((s - 4.45) / 0.65))!;
  }
  return 1.0;
}

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

    // Controller utama v3: 7000ms (dulu 3800ms di v2 — kini bebas
    // karena layar ini hanya tampil sekali saat instalasi baru).
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );

    // Controller docking ke header LoginScreen (tetap 480ms)
    _dockingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _mainController.addListener(() {
      // Haptic tepat saat dua gelembung melebur (~3.92 dtk / 0.56)
      if (_mainController.value >= 0.56 && !_hapticTriggered) {
        _hapticTriggered = true;
        HapticService.trigger(MekaarHapticIntent.success);
      }
    });

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDocking && !_navigated) {
        if (!widget.isEmbedded && !_reducedMotion) {
          // Auto-advance anggun setelah babak akhir selesai (standalone)
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
    // menekan “Mulai Sekarang” / “Lewati” sendiri.
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

    // Titik fokus terpadu: 0.38 × tinggi layar (sama seperti v2)
    final focalCenterX = screenSize.width / 2;
    final focalCenterY = screenSize.height * 0.38;
    final focal = Offset(focalCenterX, focalCenterY);

    // Skala adegan: ruang gambar konsep 720pt dipetakan ke layar.
    final sceneK = (math.min(screenSize.width, screenSize.height) / 720).clamp(
      0.70,
      1.15,
    );

    // Koordinat target presisi di LoginScreen (tetap seperti v1/v2)
    final targetX = 24.0;
    final targetY = safePadding.top + 52.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── SATU AnimatedBuilder untuk seluruh panggung ──
        AnimatedBuilder(
          animation: Listenable.merge([_mainController, _dockingController]),
          builder: (context, child) {
            final val = _mainController.value;
            final s = val * 7.0; // posisi garis waktu adegan (detik)
            final dockVal = _dockingController.value;
            final dockCurve = MekaarMotion.emphasized.transform(dockVal);
            final exitOpacity = (1.0 - (dockVal * 3.0)).clamp(0.0, 1.0);
            final zoom = _cameraZoom(s);

            // ═══ Babak 4: Jembatan gelembung → logo resmi ═══
            final bridge = _seg(val, 0.650, 0.721); // 4.55–5.05 dtk
            final bridgeCurve = MekaarMotion.standard.transform(bridge);
            final logoOpacity = _seg(val, 0.657, 0.714);
            // Damped settle + napas akhir yang berakhir (bukan loop)
            final settleY =
                math.sin(bridge * math.pi * 2.2) *
                (1.0 - bridge) *
                4.0 *
                bridge;
            final breathProgress = _seg(val, 0.72, 1.0);
            final breathY =
                math.sin(breathProgress * math.pi * 2) *
                1.5 *
                _seg(val, 0.72, 0.79);

            // Glow lembut di balik logo saat jembatan berlangsung
            final glowProgress = _seg(val, 0.63, 0.80);
            final glowRadius =
                screenSize.width *
                (0.30 + 0.90 * MekaarMotion.standard.transform(glowProgress));
            final glowOpacity =
                (math.sin(glowProgress * math.pi) * 0.50 * (1.0 - dockCurve))
                    .clamp(0.0, 1.0);

            const startLogoSize = 110.0;
            const targetLogoSize = 38.0;
            final bridgeScale = 0.90 + 0.10 * bridgeCurve;
            final currentLogoSize = lerpDouble(
              startLogoSize * bridgeScale,
              targetLogoSize,
              dockCurve,
            )!;
            final startLogoX = focalCenterX - (currentLogoSize / 2);
            final startLogoY =
                focalCenterY - (currentLogoSize / 2) + settleY + breathY;
            // Docking Arc: lurus di X, melengkung naik di Y (tetap)
            final currentLogoX = lerpDouble(startLogoX, targetX, dockCurve)!;
            final currentLogoY =
                lerpDouble(startLogoY, targetY, dockCurve)! -
                math.sin(dockCurve * math.pi) * 28.0;
            final currentLogoRadius = lerpDouble(
              24.0,
              MekaarRadius.sm,
              dockCurve,
            )!;

            // ═══ Babak 4–5: Wordmark, Tagline, Tombol ═══
            final wordmarkProgress = _seg(val, 0.679, 0.821); // 4.75–5.75 dtk
            final wordmarkCurve = MekaarMotion.standard.transform(
              wordmarkProgress,
            );

            const startWordmarkFontSize = 32.0;
            const targetWordmarkFontSize = 22.0;
            final currentWordmarkFontSize = lerpDouble(
              startWordmarkFontSize,
              targetWordmarkFontSize,
              dockCurve,
            )!;

            final startWordmarkX = focalCenterX;
            final startWordmarkY =
                startLogoY +
                currentLogoSize +
                20.0 +
                (14.0 * (1.0 - wordmarkCurve));
            final targetWordmarkX = targetX + targetLogoSize + 12.0;
            final targetWordmarkY = targetY + 6.0;
            final currentWordmarkX = lerpDouble(
              startWordmarkX,
              targetWordmarkX,
              dockCurve,
            )!;
            final currentWordmarkY =
                lerpDouble(startWordmarkY, targetWordmarkY, dockCurve)! -
                math.sin(dockCurve * math.pi) * 20.0;

            final taglineProgress = _seg(val, 0.800, 0.886); // 5.60–6.20 dtk
            final taglineCurve = MekaarMotion.standard.transform(
              taglineProgress,
            );
            final taglineY = focalCenterY + (110.0 / 2) + 68.0;

            final buttonProgress = _seg(val, 0.864, 0.971); // 6.05–6.80 dtk
            final buttonCurve = MekaarMotion.standard.transform(buttonProgress);

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Glow (Babak 4) ──
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

                // ── Adegan: dua user, gelembung, lingkaran ruang aman ──
                // Digambar satu painter; kamera = Transform pada layer ini.
                if (dockVal == 0.0)
                  Positioned.fill(
                    // Alignment (0, -0.24) = titik fokus (0.5, 0.38) layar.
                    child: Transform.scale(
                      scale: zoom,
                      alignment: const Alignment(0, -0.24),
                      child: CustomPaint(
                        painter: _ScenePainter(
                          seconds: s,
                          focal: focal,
                          k: sceneK,
                          colorA: AppColors.safeTeal,
                          colorB: AppColors.blue,
                        ),
                      ),
                    ),
                  ),

                // ── Logo MEKAAR resmi (Babak 4, 5, Docking Arc) ──
                if (bridge > 0.0 || dockVal > 0.0)
                  Positioned(
                    left: currentLogoX,
                    top: currentLogoY,
                    child: Opacity(
                      opacity: logoOpacity.clamp(0.0, 1.0),
                      child: Container(
                        width: currentLogoSize,
                        height: currentLogoSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            currentLogoRadius,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(
                                alpha: lerpDouble(0.25, 0.15, dockCurve)!,
                              ),
                              blurRadius: lerpDouble(20.0, 8.0, dockCurve)!,
                              offset: Offset(
                                0,
                                lerpDouble(8.0, 3.0, dockCurve)!,
                              ),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            currentLogoRadius,
                          ),
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

                // ── Wordmark MEKAAR ──
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

                // ── Tagline resmi MEKAAR ──
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
                          letterSpacing: 0.3 + 0.9 * (1.0 - taglineCurve),
                        ),
                      ),
                    ),
                  ),

                // ── Tombol “Mulai Sekarang” (standalone) ──
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

        // ── Tombol “Lewati” Standalone (tersedia sejak awal, tetap) ──
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

/// Painter adegan v3: dua user, dua gelembung percakapan, gelembung
/// gabungan, dan lingkaran “ruang aman”. Semua dihitung dari [seconds]
/// (0–7) — satu sumber kebenaran per frame, tanpa widget per elemen.
///
/// Koordinat mengikuti ruang konsep 720pt yang diskalakan oleh [k];
/// titik fokus adegan adalah [focal] (gelembung beristirahat di sana).
class _ScenePainter extends CustomPainter {
  const _ScenePainter({
    required this.seconds,
    required this.focal,
    required this.k,
    required this.colorA,
    required this.colorB,
  });

  final double seconds;
  final Offset focal;
  final double k;
  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    final s = seconds;

    // ── Posisi dasar user ──
    final userBaseY = math.min(focal.dy + 268 * k, size.height - 84);
    final userAX = focal.dx - 210 * k;
    final userBX = focal.dx + 210 * k;

    // ── Dua user (memudar & tenggelam di Babak 3) ──
    final userIn = _easeOutCubicS(_segS(s, 0.05, 0.55));
    final userFade = 1.0 - _segS(s, 2.70, 3.60);
    final userAlpha = userIn * userFade;
    if (userAlpha > 0.01) {
      final sink = 30 * k * _segS(s, 2.70, 3.60);
      final uScale = 0.85 + 0.15 * userIn;
      _drawUser(canvas, userAX, userBaseY + sink, uScale, colorA, userAlpha);
      _drawUser(canvas, userBX, userBaseY + sink, uScale, colorB, userAlpha);
    }

    // ── Lingkaran ruang aman (tergambar saat pendekatan) ──
    final ringFade = 1.0 - _segS(s, 4.55, 5.05);
    if (s >= 2.85 && ringFade > 0.01) {
      final sweepDeg = s < 3.85
          ? 330 * _easeInOutCubicS(_segS(s, 2.85, 3.85))
          : 360.0;
      double ringAlpha;
      if (s < 3.85) {
        ringAlpha = 170 * _segS(s, 2.85, 3.25);
      } else if (s > 4.4) {
        // Napas halus setelah ruang terbentuk
        ringAlpha =
            150 * (0.35 + 0.3 * (0.5 + 0.5 * math.sin((s - 4.4) * 2.0))) + 40;
      } else {
        ringAlpha = 175;
      }
      if (sweepDeg > 0 && ringAlpha > 1) {
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.5, 5 * k)
          ..color = colorA.withValues(alpha: (ringAlpha / 255) * ringFade);
        canvas.drawArc(
          Rect.fromCircle(center: focal, radius: 148 * k),
          -math.pi / 2,
          sweepDeg * math.pi / 180,
          false,
          ringPaint,
        );
      }
      // Satu denyut tepat setelah penggabungan
      final pp = _segS(s, 3.98, 4.68);
      if (pp > 0.0 && pp < 1.0) {
        final pulsePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * k
          ..color = colorA.withValues(alpha: 0.47 * (1.0 - pp) * ringFade);
        canvas.drawCircle(
          focal,
          (148 + 42 * _easeOutCubicS(pp)) * k,
          pulsePaint,
        );
      }
    }

    // ── Dua gelembung sinyal (hingga melebur ~4.08 dtk) ──
    if (s < 4.08) {
      _drawSignalBubble(
        canvas,
        s: s,
        sign: -1,
        userX: userAX,
        userBaseY: userBaseY,
        color: colorA,
        emergeStart: 0.50,
        talkStart: 1.30,
        talkEnd: 1.95,
        bobPhase: 0,
      );
      _drawSignalBubble(
        canvas,
        s: s,
        sign: 1,
        userX: userBX,
        userBaseY: userBaseY,
        color: colorB,
        emergeStart: 0.70,
        talkStart: 2.00,
        talkEnd: 2.65,
        bobPhase: math.pi,
      );
    }

    // ── Gelembung gabungan (3.85 dtk → memudar ke logo 5.05 dtk) ──
    final mp = _easeOutBackTamed(_segS(s, 3.85, 4.30));
    final mergedAlpha = 1.0 - _segS(s, 4.55, 5.05);
    if (mp > 0.01 && mergedAlpha > 0.01) {
      final pop = mp.clamp(0.0, 1.06);
      _drawBubble(
        canvas,
        center: focal,
        w: 196 * k * pop,
        h: 138 * k * pop,
        color: colorA,
        tail: _BubbleTail.center,
        dotPhase: s * 5.2,
        dotAmp: (s > 4.9 ? 4.5 : 6.0) * k,
        alpha: mergedAlpha,
      );
    }
  }

  void _drawSignalBubble(
    Canvas canvas, {
    required double s,
    required double sign,
    required double userX,
    required double userBaseY,
    required Color color,
    required double emergeStart,
    required double talkStart,
    required double talkEnd,
    required double bobPhase,
  }) {
    final emerge = _easeOutBackTamed(_segS(s, emergeStart, emergeStart + 0.65));
    if (emerge <= 0.0) return;

    // Keluar dari arah kepala user → posisi istirahat → titik pendekatan
    final startPos = Offset(userX - sign * 22 * k, userBaseY - 114 * k);
    final restPos = Offset(focal.dx + sign * 148 * k, focal.dy);
    final targetPos = Offset(focal.dx + sign * 54 * k, focal.dy);
    final approach = _magnetCurve.transform(_segS(s, 2.60, 3.75));
    final emerged = Offset.lerp(startPos, restPos, emerge)!;
    var pos = Offset.lerp(emerged, targetPos, approach)!;
    if (s > 1.4) {
      final bob = math.sin(s * 2.2 + bobPhase) * 4 * k * (1.0 - approach);
      pos = pos.translate(0, bob);
    }

    final grow = 1.0 + 0.07 * approach;
    final shrink = 1.0 - 0.25 * _easeInOutCubicS(_segS(s, 3.70, 4.06));
    final scaleF = math.max(0.05, emerge) * grow * shrink;
    final alpha = 1.0 - _easeInOutCubicS(_segS(s, 3.78, 4.08));
    if (alpha <= 0.01) return;

    final talking = s > talkStart && s < talkEnd;
    _drawBubble(
      canvas,
      center: pos,
      w: 132 * k * scaleF,
      h: 94 * k * scaleF,
      color: color,
      tail: sign < 0 ? _BubbleTail.left : _BubbleTail.right,
      dotPhase: talking ? s * 9 : s * 2.2,
      dotAmp: (talking ? 6.5 : 2.0) * k,
      alpha: alpha,
    );
  }

  void _drawUser(
    Canvas canvas,
    double cx,
    double baseY,
    double uScale,
    Color color,
    double alpha,
  ) {
    final paint = Paint()..color = color.withValues(alpha: 0.85 * alpha);
    final sc = k * uScale;
    // Kepala
    canvas.drawCircle(Offset(cx, baseY - 96 * sc), 30 * sc, paint);
    // Bahu: setengah cakram tepat di bawah kepala
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, baseY - 58 * sc), radius: 58 * sc),
      0,
      math.pi,
      true,
      paint,
    );
  }

  void _drawBubble(
    Canvas canvas, {
    required Offset center,
    required double w,
    required double h,
    required Color color,
    required _BubbleTail tail,
    required double dotPhase,
    required double dotAmp,
    required double alpha,
  }) {
    if (w <= 2 || h <= 2) return;
    final paint = Paint()..color = color.withValues(alpha: alpha);
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.30));

    // Ekor gelembung
    final tailPath = Path();
    final y1 = rect.bottom;
    switch (tail) {
      case _BubbleTail.left:
        tailPath
          ..moveTo(center.dx - w * 0.18, y1 - 6)
          ..lineTo(center.dx - w * 0.02, y1 - 6)
          ..lineTo(center.dx - w * 0.20, y1 + h * 0.20);
      case _BubbleTail.right:
        tailPath
          ..moveTo(center.dx + w * 0.02, y1 - 6)
          ..lineTo(center.dx + w * 0.18, y1 - 6)
          ..lineTo(center.dx + w * 0.20, y1 + h * 0.20);
      case _BubbleTail.center:
        tailPath
          ..moveTo(center.dx - w * 0.06, y1 - 6)
          ..lineTo(center.dx + w * 0.10, y1 - 6)
          ..lineTo(center.dx - w * 0.02, y1 + h * 0.20);
    }
    tailPath.close();
    canvas.drawPath(tailPath, paint);
    canvas.drawRRect(rrect, paint);

    // Tiga titik ketikan
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: alpha);
    final spacing = w * 0.19;
    final dr = h * 0.085;
    for (var i = 0; i < 3; i++) {
      final dx = center.dx + (i - 1) * spacing;
      final bounce = -dotAmp * math.max(0.0, math.sin(dotPhase + i * 0.9));
      canvas.drawCircle(Offset(dx, center.dy + bounce), dr, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.focal != focal ||
      oldDelegate.k != k ||
      oldDelegate.colorA != colorA ||
      oldDelegate.colorB != colorB;
}

enum _BubbleTail { left, right, center }

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
