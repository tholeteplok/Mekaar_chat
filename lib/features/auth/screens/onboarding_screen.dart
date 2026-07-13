import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';

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
      'title': 'Chat Standar Lebih Breathable',
      'desc': 'Nikmati obrolan modern bersama teman sebaya dengan privasi tinggi, read receipts opsional, dan view-once media.',
      'icon': 'chat_bubble_outline',
    },
    {
      'title': 'Sistem Guardian & SOS Terkontrol',
      'desc': 'Guardian tidak bisa mengintai Anda. Izin GPS & audio hanya aktif ketika Anda menekan tombol SOS dalam bahaya.',
      'icon': 'shield_outlined',
    },
    {
      'title': 'Manajemen Data 3 Lapisan',
      'desc': 'Kebebasan hapus chat biasa, auto-delete terkendali pada chat guardian, dan log sistem darurat permanen untuk bukti hukum.',
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
      backgroundColor: MekaarColors.background,
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
                    style: TextStyle(color: MekaarColors.textSecondary, fontWeight: FontWeight.w600),
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
                    IconData iconData = Icons.chat_bubble_outline;
                    if (slide['icon'] == 'shield_outlined') {
                      iconData = Icons.shield_outlined;
                    } else if (slide['icon'] == 'lock_outline') {
                      iconData = Icons.lock_outline;
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: MekaarColors.softCoral.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData,
                            size: 64,
                            color: MekaarColors.softCoral,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          slide['title']!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: MekaarColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['desc']!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: MekaarColors.textSecondary,
                                height: 1.6,
                              ),
                        ),
                      ],
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
