import 'package:flutter/material.dart';
import '../widgets/mika_illustration.dart';
import 'colors.dart';

/// Data class terstruktur untuk tiap slide onboarding MEKAAR.
class MekaarOnboardingSlideData {
  final String title;
  final String desc;
  final String lottieAsset;
  final MikaIllustrationType fallbackIllustration;
  final Color themeColor;
  final double bottomOffsetFactor;

  const MekaarOnboardingSlideData({
    required this.title,
    required this.desc,
    required this.lottieAsset,
    required this.fallbackIllustration,
    required this.themeColor,
    this.bottomOffsetFactor = 0.0,
  });
}

/// Token konfigurasi konveyor panggung paralaks dan panggung onboarding MEKAAR.
/// Menjaga konsistensi nilai panggung tanpa hardcoded styling.
class MekaarOnboardingTokens {
  MekaarOnboardingTokens._();

  // ── Dimensi Panggung Konveyor ──
  static const double stageWidth = 190.0;
  static const double groundlineWidth = 280.0;
  static const double groundlineCenterThickness = 2.0;
  static const double groundlineEndThickness = 0.5;
  static const double groundlineHeight = 2.0;
  static const double mascotSize = 300.0;
  static const double stageHeight = 340.0;

  // ── Rasio Paralaks & Kedalaman ──
  static const double minMascotScale = 0.72;
  static const double maxMascotScale = 1.0;
  static const double minMascotOpacity = 0.40;
  static const double maxMascotOpacity = 1.0;

  // ── Rasio Kecepatan Paralaks Layer ──
  static const double textParallaxOffset = 36.0;

  // ── Aset Animasi Lottie ──
  static const String lottieWelcome =
      'assets/animations/frog_waving_greeting.json';
  static const String lottieGuardian =
      'assets/animations/frog_walking_confidently.json';
  static const String lottieSecurity =
      'assets/animations/frog_security_locked.json';
  static const String lottieSuccess =
      'assets/animations/frog_jumping_happy_smooth.json';

  // ── Daftar 4 Slide Baku MEKAAR ──
  static const List<MekaarOnboardingSlideData> defaultSlides = [
    MekaarOnboardingSlideData(
      title: 'Selamat Datang di MEKAAR',
      desc:
          'Aplikasi obrolan pribadi dengan perlindungan keselamatan terintegrasi, tombol SOS satu sentuhan, dan privasi penuh.',
      lottieAsset: lottieWelcome,
      fallbackIllustration: MikaIllustrationType.onboardingWelcome,
      themeColor: AppColors.blue,
      bottomOffsetFactor: -0.115,
    ),
    MekaarOnboardingSlideData(
      title: 'Guardian Tepercaya',
      desc:
          'Guardian adalah pelindung Anda. Akses lokasi GPS dan audio hanya aktif saat Anda menekan tombol SOS darurat.',
      lottieAsset: lottieGuardian,
      fallbackIllustration: MikaIllustrationType.onboardingGuardian,
      themeColor: AppColors.warnAmber,
      bottomOffsetFactor: -0.096,
    ),
    MekaarOnboardingSlideData(
      title: 'PIN & Brankas Rahasia',
      desc:
          'Amankan obrolan pribadi, sembunyikan kontak sensitif, dan simpan berkas penting dalam Brankas terenkripsi PIN.',
      lottieAsset: lottieSecurity,
      fallbackIllustration: MikaIllustrationType.onboardingSecurity,
      themeColor: Color(0xFF6366F1), // Indigo Vault
      bottomOffsetFactor: -0.207,
    ),
    MekaarOnboardingSlideData(
      title: 'Privasi Penuh di Tanganmu',
      desc:
          'Semua pesan diamankan dengan enkripsi end-to-end tanpa pelacakan data. Anda memegang kendali sepenuhnya.',
      lottieAsset: lottieSuccess,
      fallbackIllustration: MikaIllustrationType.onboardingSuccess,
      themeColor: AppColors.green,
      bottomOffsetFactor: -0.103,
    ),
  ];
}
