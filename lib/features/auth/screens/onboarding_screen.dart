import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mika_illustration.dart';
import 'welcome_animation_screen.dart';

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

  final List<({String title, String desc, MikaIllustrationType illustration})>
      _slides = [
    (
      title: 'Selamat Datang di MEKAAR',
      desc:
          'Aplikasi obrolan pribadi dengan perlindungan keselamatan terintegrasi, tombol SOS satu sentuhan, dan privasi penuh.',
      illustration: MikaIllustrationType.onboardingWelcome,
    ),
    (
      title: 'Guardian Tepercaya',
      desc:
          'Guardian adalah pelindung Anda. Akses lokasi GPS dan audio hanya aktif saat Anda menekan tombol SOS darurat.',
      illustration: MikaIllustrationType.onboardingGuardian,
    ),
    (
      title: 'PIN & Brankas Rahasia',
      desc:
          'Amankan obrolan pribadi, sembunyikan kontak sensitif, dan simpan berkas penting dalam Brankas terenkripsi PIN.',
      illustration: MikaIllustrationType.onboardingSecurity,
    ),
    (
      title: 'Privasi Penuh di Tanganmu',
      desc:
          'Semua pesan diamankan dengan enkripsi end-to-end tanpa pelacakan data. Anda memegang kendali sepenuhnya.',
      illustration: MikaIllustrationType.onboardingSuccess,
    ),
  ];

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
        curve: Curves.easeOutCubic,
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

  @override
  Widget build(BuildContext context) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final cardBorder = MekaarColors.cardBorderOf(context);
    final safePadding = MediaQuery.paddingOf(context);

    return MekaarScaffold(
      flat: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: PageView (5 Slides) ──
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48), // Spacing for skip button
                        AnimatedAppear(
                          key: ValueKey(index),
                          duration: MekaarMotion.slow,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MikaIllustration(
                                key: ValueKey(slide.illustration),
                                type: slide.illustration,
                                size: 180,
                                semanticLabel: 'Ilustrasi ${slide.title}',
                              ),
                              const SizedBox(height: MekaarSpacing.section),
                              SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      slide.title,
                                      textAlign: TextAlign.center,
                                      style: MekaarTypography.headingLG
                                          .copyWith(color: textPrimary),
                                    ),
                                    const SizedBox(height: MekaarSpacing.lg),
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
                        const SizedBox(height: 72), // Spacing for bottom bar
                      ],
                    ),
                  ),
                );
              } else {
                // Slide 5: The Climactic Welcome Animation
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

          // ── Layer 2: Top "Lewati" Button ──
          Positioned(
            top: safePadding.top + 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isDocking ? 0.0 : 1.0,
              child: TextButton(
                onPressed: _skipToLogin,
                child: Text(
                  'Lewati',
                  style: MekaarTypography.labelLG.copyWith(
                    color: textSecondary,
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 3: Bottom Bar (5 Dots & Action Button) ──
          Positioned(
            bottom: safePadding.bottom + 24,
            left: 28,
            right: 28,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
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
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: AnimatedContainer(
                            duration: MekaarMotion.counter,
                            curve: Curves.easeOutCubic,
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? MekaarColors.accentOf(context)
                                  : cardBorder,
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
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MekaarColors.accentOf(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
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
