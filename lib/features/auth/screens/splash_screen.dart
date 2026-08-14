import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/e2ee_service.dart';
import '../../sos/providers/sos_provider.dart';
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
      duration: const Duration(milliseconds: 600),
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
    // Wait 800ms for smooth splash presentation
    await Future.delayed(const Duration(milliseconds: 800));

    // Wait until profile & session loading finishes to avoid race conditions
    // Timeout setelah 15 detik untuk mencegah infinite loop
    int waitAttempts = 0;
    while (ref.read(authProvider).isLoading && waitAttempts < 300) {
      await Future.delayed(const Duration(milliseconds: 50));
      waitAttempts++;
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
      // 1. Suspension Lockout Check (dengan SOS immunity guard)
      if (authState.profile?.isSuspended == true) {
        try {
          final activeSos = await ref.read(sosRepositoryProvider).getActiveSOS();
          if (activeSos == null) {
            if (!mounted) return;
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.accountSuspended,
              arguments: {
                'reason': authState.profile?.suspensionReason,
                'suspendedAt': authState.profile?.suspendedAt?.toIso8601String(),
              },
            );
            return;
          }
        } catch (_) {
          // Fallback if SOS fetch fails
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.accountSuspended,
            arguments: {
              'reason': authState.profile?.suspensionReason,
            },
          );
          return;
        }
      }

      // 2. 2FA Gatekeeping Check
      final twoFaEnabled = authState.profile?.twoFaEnabled ?? false;
      final twoFaSecret = authState.profile?.twoFaSecret;
      if (twoFaEnabled && twoFaSecret != null && twoFaSecret.isNotEmpty) {
        final authRepo = ref.read(authRepositoryProvider);
        final is2faVerified = await authRepo.is2faVerified();
        if (!is2faVerified) {
          if (!mounted) return;
          final verified = await Navigator.pushNamed(
            context,
            AppRoutes.twoFactor,
            arguments: twoFaSecret,
          );
          if (verified != true) return;
        }
      }

      if (!mounted) return;
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
          if (authState.needsUsername) {
            Navigator.pushReplacementNamed(context, AppRoutes.setUsername);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
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
      flat: false,
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
                  pose: MikaPose.welcome,
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
