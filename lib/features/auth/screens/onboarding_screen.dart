import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<({String title, String desc, MikaIllustrationType illustration})> _slides = [
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

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  Future<void> _nextPage() async {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: MekaarMotion.counter,
        curve: Curves.easeOutCubic,
      );
    } else {
      bool hasSeen = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        hasSeen = prefs.getBool('has_seen_welcome_animation') ?? false;
      } catch (_) {}
      if (!mounted) return;
      if (!hasSeen) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcomeAnimation);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final cardBorder = MekaarColors.cardBorderOf(context);

    return MekaarScaffold(
      flat: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.login),
                  child: Text(
                    'Lewati',
                    style: MekaarTypography.labelLG.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];

                    return AnimatedAppear(
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
                    );
                  },
                ),
              ),
              // Dots & Next Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => GestureDetector(
                        key: ValueKey('onboarding_dot_$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
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
                  ElevatedButton.icon(
                    onPressed: _nextPage,
                    icon: const Icon(SolarIconsOutline.altArrowRight, size: 18),
                    label: Text(
                      'Lanjut',
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
            ],
          ),
        ),
      ),
    );
  }
}
