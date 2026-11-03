import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/onboarding_tokens.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../widgets/mekaar_lottie_parallax_item.dart';
import '../widgets/mekaar_stage_grounding_line.dart';
import 'welcome_animation_screen.dart';

/// Layar Onboarding MEKAAR dengan Panggung Konveyor Paralaks Maskot Mika
/// dan Garis Pijakan Bersama (Shared Grounding Stage Line) minimalis.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _isDocking = false;
  final GlobalKey<WelcomeAnimationViewState> _welcomeViewKey =
      GlobalKey<WelcomeAnimationViewState>();

  final List<MekaarOnboardingSlideData> _slides =
      MekaarOnboardingTokens.defaultSlides;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    if (index == 4) {
      _welcomeViewKey.currentState?.playAnimation();
    } else {
      _welcomeViewKey.currentState?.resetAnimation();
    }
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: MekaarMotion.counter,
        curve: MekaarMotion.standard,
      );
    }
  }

  void _startDocking() {
    if (_currentPage == 4) {
      _welcomeViewKey.currentState?.startDocking();
    } else {
      _nextPage();
    }
  }

  void _skipToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  /// Menghitung interpolasi warna tema halus antar-slide saat pengguna menggeser layar
  Color _getInterpolatedThemeColor(double page) {
    if (page >= 3.0) return _slides.last.themeColor;
    final int baseIndex = page.floor().clamp(0, _slides.length - 1);
    final int nextIndex = (baseIndex + 1).clamp(0, _slides.length - 1);
    final double factor = (page - baseIndex).clamp(0.0, 1.0);
    final color1 = _slides[baseIndex].themeColor;
    final color2 = _slides[nextIndex].themeColor;
    return Color.lerp(color1, color2, factor) ?? color1;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final cardBorder = MekaarColors.cardBorderOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final isReduceMotion = context.reduceMotion;

    return MekaarScaffold(
      flat: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 0 & 1: Panggung Konveyor Paralaks & Aura Latar Belakang ──
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              final double page = _pageController.hasClients
                  ? (_pageController.page ?? _currentPage.toDouble())
                  : _currentPage.toDouble();

              // Opasitas panggung memudar halus saat mendekati Slide 5 (Genesis Bloom)
              final double stageOpacity =
                  (1.0 - (page - 3.0)).clamp(0.0, 1.0);

              if (stageOpacity <= 0.0) {
                return const SizedBox.shrink();
              }

              final Color activeColor = _getInterpolatedThemeColor(page);

              return Opacity(
                opacity: stageOpacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 0: Ambient Aura Glow Tipis (Mengikuti Posisi Panggung)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 120),
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor.withValues(alpha: 0.16),
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.20),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Layer 1: Panggung Konveyor Maskot Mika + Garis Pijakan Bersama
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            clipBehavior: Clip.none,
                            children: [
                              // ── Garis Pijakan Bersama (Minimalis 1.5px Hairline) ──
                              Positioned(
                                bottom: 0,
                                child: MekaarStageGroundingLine(
                                  accentColor: activeColor,
                                ),
                              ),

                              // ── Konveyor 4 Maskot Mika (Peeking Staggered) ──
                              if (isReduceMotion)
                                // Mode Aksesibilitas: Tampilkan hanya karakter aktif di tengah tanpa translasi
                                if (_currentPage < 4)
                                  Positioned(
                                    bottom: 0,
                                    child: MekaarLottieParallaxItem(
                                      key: ValueKey('mascot_static_$_currentPage'),
                                      assetPath: _slides[_currentPage].lottieAsset,
                                      distance: 0.0,
                                      semanticLabel:
                                          'Ilustrasi ${_slides[_currentPage].title}',
                                    ),
                                  )
                              else
                                // Mode Normal: 4 Maskot berselancar di atas konveyor panggung
                                ...List.generate(4, (index) {
                                  final double delta = index - page;
                                  final double distance = delta.abs();

                                  // Jika karakter berada jauh di luar layar, sembunyikan untuk hemat komputasi
                                  if (distance > 2.0) {
                                    return const SizedBox.shrink();
                                  }

                                  // Translasi horizontal sepanjang garis panggung (145px peeking offset)
                                  final double translateX = delta *
                                      MekaarOnboardingTokens.stageWidth;

                                  // Parallax Scaling: 1.0 di tengah, 0.72 di pinggir
                                  final double scale = (1.0 -
                                          (0.28 * math.min(distance, 1.0)))
                                      .clamp(
                                    MekaarOnboardingTokens.minMascotScale,
                                    MekaarOnboardingTokens.maxMascotScale,
                                  );

                                  // Opacity: 1.0 di tengah, 0.40 saat mengintip di samping
                                  final double opacity = (1.0 -
                                          (0.60 * math.min(distance, 1.2)))
                                      .clamp(0.0, 1.0);

                                  return Positioned(
                                    bottom: 0,
                                    child: Transform.translate(
                                      offset: Offset(translateX, 0),
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.bottomCenter,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: MekaarLottieParallaxItem(
                                            key: ValueKey('mascot_conveyor_$index'),
                                            assetPath: _slides[index].lottieAsset,
                                            distance: distance,
                                            semanticLabel:
                                                'Ilustrasi ${_slides[index].title}',
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Layer 2: PageView (5 Slides) ──
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: 5,
            physics: _isDocking
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              if (index < 4) {
                final slide = _slides[index];
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Ruang panggung atas dialokasikan untuk konveyor maskot
                        const Spacer(),

                        // Konten Teks (Judul & Deskripsi)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 120.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: MekaarTypography.headingLG
                                    .copyWith(color: textPrimary),
                              ),
                              const SizedBox(height: MekaarSpacing.md),
                              Text(
                                slide.desc,
                                textAlign: TextAlign.center,
                                style: MekaarTypography.bodySM.copyWith(
                                  color: textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Slide 5: The Climactic Welcome Animation (Genesis Bloom & Docking)
                return WelcomeAnimationView(
                  key: _welcomeViewKey,
                  isEmbedded: true,
                  autoStart: _currentPage == 4,
                  showStandAloneControls: false,
                  onDockingStarted: () => setState(() => _isDocking = true),
                  onDockingComplete: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.login),
                  onSkip: _skipToLogin,
                );
              }
            },
          ),

          // ── Layer 3: Top "Lewati" Button & Brand Chip ──
          Positioned(
            top: safePadding.top + 16,
            left: 24,
            right: 16,
            child: AnimatedOpacity(
              duration: context.motion(MekaarMotion.fast),
              opacity: _isDocking ? 0.0 : 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'MEKAAR',
                      style: MekaarTypography.labelLG.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      children: const [
                        TextSpan(
                          text: '.chat',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _skipToLogin,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Lewati',
                      style: MekaarTypography.labelLG.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Layer 4: Bottom Bar (5 Dots & Action Button) ──
          Positioned(
            bottom: safePadding.bottom + 24,
            left: 28,
            right: 28,
            child: AnimatedOpacity(
              duration: context.motion(MekaarMotion.fast),
              opacity: _isDocking ? 0.0 : 1.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 5 Dots (Indices 0 through 4)
                  Row(
                    children: List.generate(
                      5,
                      (index) => GestureDetector(
                        key: ValueKey('onboarding_dot_$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_isDocking) return;
                          _pageController.animateToPage(
                            index,
                            duration: MekaarMotion.counter,
                            curve: MekaarMotion.standard,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 8,
                          ),
                          child: AnimatedContainer(
                            duration: MekaarMotion.counter,
                            curve: MekaarMotion.standard,
                            width: _currentPage == index ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? AppColors.green
                                  : cardBorder,
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: AppColors.green
                                            .withValues(alpha: 0.65),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action Button ("Lanjut" on 0..3, "Mulai Sekarang" on 4)
                  ElevatedButton.icon(
                    key: ValueKey(
                      _currentPage == 4
                          ? 'onboarding_btn_start'
                          : 'onboarding_btn_next',
                    ),
                    onPressed: _isDocking
                        ? null
                        : (_currentPage == 4 ? _startDocking : _nextPage),
                    icon: const Icon(SolarIconsOutline.altArrowRight, size: 18),
                    label: Text(
                      _currentPage == 4 ? 'Mulai Sekarang' : 'Lanjut',
                      style: MekaarTypography.labelLG.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MekaarColors.accentOf(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.lg),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
