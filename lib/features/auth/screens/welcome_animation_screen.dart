import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';

/// Layar animasi perkenalan identitas MEKAAR (Chat Bubble + Shield bertabrakan
/// menjadi logo Mekaar) yang hanya ditampilkan satu kali pasca-onboarding.
class WelcomeAnimationScreen extends ConsumerStatefulWidget {
  const WelcomeAnimationScreen({super.key});

  @override
  ConsumerState<WelcomeAnimationScreen> createState() =>
      _WelcomeAnimationScreenState();
}

class _WelcomeAnimationScreenState extends ConsumerState<WelcomeAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hapticTriggered = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _controller.addListener(() {
      // Pemicu getaran haptic tepat saat kedua ikon bertabrakan di tengah (~460ms)
      if (_controller.value >= 0.20 && !_hapticTriggered) {
        _hapticTriggered = true;
        HapticService.trigger(MekaarHapticIntent.selection);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishWelcome();
      }
    });

    _controller.forward();
  }

  Future<void> _finishWelcome() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome_animation', true);
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxRadius = math.sqrt(
      screenSize.width * screenSize.width +
          screenSize.height * screenSize.height,
    );

    return MekaarScaffold(
      flat: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ── Layer 1: Gelombang Biru Layar (Blue Wave Radial Burst) ──
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = _controller.value;
              double waveScale = 0.0;
              double waveOpacity = 0.0;

              if (val >= 0.20 && val < 0.40) {
                // Ekspansi gelombang biru dari tengah memenuhi layar
                final t = (val - 0.20) / 0.20;
                waveScale = Curves.easeOutCubic.transform(t);
                waveOpacity = 1.0;
              } else if (val >= 0.40 && val < 0.43) {
                // Tahan sesaat dalam keadaan biru penuh
                waveScale = 1.0;
                waveOpacity = 1.0;
              } else if (val >= 0.43 && val < 0.60) {
                // Menyusut cepat kembali ke pusat logo
                final t = (val - 0.43) / 0.17;
                waveScale = 1.0 - Curves.easeInOutCubic.transform(t);
                waveOpacity = (1.0 - t).clamp(0.0, 1.0);
              }

              if (waveScale <= 0.0) return const SizedBox.shrink();

              final currentDiameter = maxRadius * 2 * waveScale;

              return Center(
                child: Opacity(
                  opacity: waveOpacity,
                  child: Container(
                    width: currentDiameter,
                    height: currentDiameter,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Layer 2: Ikon Bubble & Shield Bertabrakan Menuju Tengah ──
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = _controller.value;
              if (val >= 0.22) return const SizedBox.shrink();

              // Fase 1: Pendekatan dari samping (0.00 - 0.20)
              final approachProgress = (val / 0.20).clamp(0.0, 1.0);
              final curvedApproach =
                  Curves.easeInCubic.transform(approachProgress);

              final leftOffset = -140.0 * (1.0 - curvedApproach);
              final rightOffset = 140.0 * (1.0 - curvedApproach);

              // Opasitas muncul di awal dan hilang saat tabrakan
              double iconOpacity = 1.0;
              if (val < 0.06) {
                iconOpacity = (val / 0.06).clamp(0.0, 1.0);
              } else if (val > 0.20) {
                iconOpacity = (1.0 - ((val - 0.20) / 0.02)).clamp(0.0, 1.0);
              }

              return Center(
                child: Opacity(
                  opacity: iconOpacity,
                  child: SizedBox(
                    width: 320,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Balon Obrolan (kiri)
                        Transform.translate(
                          offset: Offset(leftOffset - 24, 0),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.safeTeal.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.safeTeal,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                SolarIconsBold.chatRoundDots,
                                color: AppColors.safeTeal,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        // Perisai Perlindungan (kanan)
                        Transform.translate(
                          offset: Offset(rightOffset + 24, 0),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.blue,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                SolarIconsBold.shieldCheck,
                                color: AppColors.blue,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Layer 3: Logo Mekaar, Wordmark, dan Tagline ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo resmi Mekaar muncul dari titik penyusutan
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final val = _controller.value;
                    if (val < 0.50) return const SizedBox(height: 110);

                    final t = ((val - 0.50) / 0.22).clamp(0.0, 1.0);
                    final scale = Curves.easeOutBack.transform(t);
                    final opacity = ((val - 0.50) / 0.10).clamp(0.0, 1.0);

                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Image.asset(
                          'assets/logo/app_icon.webp',
                          width: 110,
                          height: 110,
                          semanticLabel: 'Logo MEKAAR',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Wordmark resmi Mekaar meluncur halus ke atas
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final val = _controller.value;
                    if (val < 0.65) return const SizedBox(height: 48);

                    final t = ((val - 0.65) / 0.20).clamp(0.0, 1.0);
                    final opacity = Curves.easeOut.transform(t);
                    final offsetY = 20.0 * (1.0 - Curves.easeOutCubic.transform(t));

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, offsetY),
                        child: const MekaarWordmark(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Tagline resmi Mekaar memudar masuk
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final val = _controller.value;
                    if (val < 0.75) return const SizedBox(height: 20);

                    final t = ((val - 0.75) / 0.17).clamp(0.0, 1.0);
                    final opacity = Curves.easeOut.transform(t);

                    return Opacity(
                      opacity: opacity,
                      child: Text(
                        'Bicara bebas. Tetap aman.',
                        style: TextStyle(
                          fontSize: 14,
                          color: MekaarColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Tombol "Lewati" di Pojok Kanan Atas ──
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: TextButton(
                onPressed: _finishWelcome,
                style: TextButton.styleFrom(
                  foregroundColor: MekaarColors.textSecondaryOf(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Lewati',
                  style: MekaarTypography.labelLG.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
