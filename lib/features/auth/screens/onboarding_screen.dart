import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
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

  final List<({String title, String desc, MikaPose pose})> _slides = [
    (
      title: 'Apa itu MEKAAR?',
      desc: 'Aplikasi perlindungan darurat: chat pribadi terenkripsi, tombol SOS satu ketukan, dan pelacakan lokasi saat Anda benar-benar dalam bahaya.',
      pose: MikaPose.hi,
    ),
    (
      title: 'Tambahkan Guardian Anda',
      desc: 'Guardian tidak bisa mengintai Anda. Izin GPS dan audio hanya aktif saat Anda menekan SOS. Setiap akses selalu tercatat di Log Sistem.',
      pose: MikaPose.love,
    ),
    (
      title: 'Kunci dengan PIN 6 digit',
      desc: 'Lindungi aplikasi dengan PIN 6 digit. SOS tetap bisa diakses saat aplikasi terkunci, dan 5 kali salah PIN akan mengunci aplikasi selama 30 menit.',
      pose: MikaPose.shield,
    ),
  ];

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      forceDark: true, // Always dark-navy gradient for onboarding
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                  child: const Text(
                    'Lewati',
                    style: TextStyle(
                      color: MekaarColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                      duration: const Duration(milliseconds: 350),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MikaIllustration(
                            key: ValueKey(slide.pose),
                            pose: slide.pose,
                            size: 170,
                            semanticLabel: 'Ilustrasi ${slide.title}',
                            animate: true,
                          ),
                          const SizedBox(height: 36),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            slide.desc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: MekaarColors.textSecondary,
                              height: 1.6,
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
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? MekaarColors.yellow
                              : MekaarColors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _nextPage,
                    icon: const Icon(SolarIconsOutline.altArrowRight),
                    label: Text(_currentPage == _slides.length - 1 ? 'Mulai' : 'Lanjut'),
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
