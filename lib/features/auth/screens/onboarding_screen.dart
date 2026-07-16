import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mika_mascot.dart';
import '../../../core/routes/app_routes.dart';

class _BouncyMascot extends StatefulWidget {
  final MikaExpression expression;
  final double size;

  const _BouncyMascot({required this.expression, required this.size});

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
      child: MikaMascot(expression: widget.expression, size: widget.size),
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
      'icon': 'chat_bubble_outline',
    },
    {
      'title': 'Tambahkan Guardian Anda',
      'desc': 'Guardian tidak bisa mengintai Anda. Izin GPS & audio hanya aktif saat Anda menekan SOS. Setiap akses mereka selalu tercatat di Log Sistem.',
      'icon': 'shield_outlined',
    },
    {
      'title': 'Kunci dengan PIN 6 Digit',
      'desc': 'Lindungi aplikasi dengan PIN 6 digit. SOS tetap bisa diakses meski aplikasi terkunci, dan 5 kali salah PIN akan mengunci 30 menit.',
      'icon': 'lock_outline',
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
    return Scaffold(
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
                  child: Text(
                    'Skip',
                    style: MekaarTypography.labelLG.copyWith(
                      color: MekaarColors.textSecondary,
                      fontWeight: FontWeight.w600,
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
                    MikaExpression expr = MikaExpression.happy;
                    if (slide['icon'] == 'shield_outlined') {
                      expr = MikaExpression.wave;
                    } else if (slide['icon'] == 'lock_outline') {
                      expr = MikaExpression.happy;
                    } else if (slide['icon'] == 'visibility_outlined') {
                      expr = MikaExpression.panic;
                    }

                    return AnimatedAppear(
                      key: ValueKey(index),
                      duration: const Duration(milliseconds: 350),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  gradient: index == 1
                                      ? MekaarGradients.teal
                                      : MekaarGradients.coral,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              _BouncyMascot(expression: expr, size: 132),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(
                            slide['title']!,
                            textAlign: TextAlign.center,
                            style: MekaarTypography.headingLG,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            slide['desc']!,
                            textAlign: TextAlign.center,
                            style: MekaarTypography.bodyMD.copyWith(height: 1.6),
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
                              ? MekaarColors.softCoral
                              : MekaarColors.border,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: MekaarColors.textPrimary,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
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
