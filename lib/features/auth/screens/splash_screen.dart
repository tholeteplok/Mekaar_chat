import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mika_mascot.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Wait at least 1.5 seconds for fade animation
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Wait until profile & session loading finishes to avoid race conditions
    while (ref.read(authProvider).isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.user != null) {
      final isPinLockEnabled = ref.read(pinLockEnabledProvider);
      
      if (authState.isPinSet) {
        if (isPinLockEnabled) {
          // Go to validation screen (1x input)
          Navigator.pushReplacementNamed(context, AppRoutes.pin, arguments: false);
        } else {
          // Bypass PIN lock screen if disabled in settings
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        // Must setup PIN first time (2x input: create & confirm)
        Navigator.pushReplacementNamed(context, AppRoutes.pin, arguments: true);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MekaarColors.backgroundDark,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mascot with gentle floating entrance
              AnimatedAppear(
                duration: const Duration(milliseconds: 500),
                offsetY: 24,
                child: const MikaMascot(
                  expression: MikaExpression.wave,
                  size: 120,
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'MEKAAR',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'Aplikasi Chat & Keamanan Personal',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
