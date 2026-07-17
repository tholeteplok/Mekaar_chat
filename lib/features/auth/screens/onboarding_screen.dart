import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/meka_mascot_geng.dart';
import '../../../core/routes/app_routes.dart';

class _BouncyMascot extends StatefulWidget {
  final double size;
  final String? message;

  const _BouncyMascot({required this.size, this.message});

  @override
  State<_BouncyMascot> createState() => _BouncyMascotState();
}

class _BouncyMascotState extends State<_BouncyMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final offset = -8 * _ctrl.value;
        final scale = 1 + 0.03 * _ctrl.value;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: MekaMascotGeng(size: widget.size, message: widget.message),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Apa itu MEKAAR?',
      'desc': 'Aplikasi perlindungan darurat: chat pribadi terenkripsi, tombol SOS satu ketukan, dan pelacakan lokasi saat Anda benar-benar dalam bahaya.',
      'bubble': 'Halo! Kami Meka & Geng 🫧',
    },
    {
      'title': 'Tambahkan Guardian Anda',
      'desc': 'Guardian tidak bisa mengintai Anda. Izin GPS & audio hanya aktif saat Anda menekan SOS. Setiap akses mereka selalu tercatat di Log Sistem.',
      'bubble': 'Kami siap menjagamu! 🤝',
    },
    {
      'title': 'Kunci dengan PIN 6 Digit',
      'desc': 'Lindungi aplikasi dengan PIN 6 digit. SOS tetap bisa diakses meski aplikasi terkunci, dan 5 kali salah PIN akan mengunci 30 menit.',
      'bubble': 'PIN rahasia biar aman! 🔒',
    },
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
                    'Skip',
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
                          _BouncyMascot(
                            size: 110,
                            message: slide['bubble'],
                          ),
                          const SizedBox(height: 48),
                          Text(
                            slide['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            slide['desc']!,
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
