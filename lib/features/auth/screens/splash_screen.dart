import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/e2ee_service.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
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

    final pinLockNotifier = ref.read(pinLockEnabledProvider.notifier);
    try {
      await pinLockNotifier.initialized;
    } catch (_) {
      // Fail secure: nilai default tetap aktif jika preferensi gagal dimuat.
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.user != null) {
      final isPinLockEnabled = ref.read(pinLockEnabledProvider);

      // Cek apakah E2EE memerlukan restore (perangkat baru / reinstall).
      // Jika ya, PAKSA layar PIN meskipun PIN Lock dinonaktifkan,
      // agar kunci E2EE bisa dipulihkan sebelum user masuk chat.
      final e2eeNeedsRestore = E2eeService.instance.needsRestore;

      if (authState.isPinSet) {
        if (isPinLockEnabled || e2eeNeedsRestore) {
          // Go to validation screen (1x input)
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.pin,
            arguments: false,
          );
        } else {
          // Bypass PIN lock screen if disabled in settings
          // AND E2EE doesn't need restore
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
    return MekaarScaffold(
      forceDark: true, // Always dark-navy gradient for splash
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
                child: const MikaIllustration(
                  pose: MikaPose.hi,
                  size: 150,
                  semanticLabel: 'Mika menyambut Anda',
                ),
              ),
              const SizedBox(height: 32),
              // Wordmark resmi Mekaar.
              FadeTransition(
                opacity: _fadeAnimation,
                child: const MekaarWordmark(),
              ),
              const SizedBox(height: 12),
              // Tagline: Express Yourself. Stay Protected.
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'Bicara bebas. Tetap aman.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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
