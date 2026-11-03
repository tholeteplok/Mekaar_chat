import 'package:flutter/material.dart';
import 'colors.dart';

/// Data class terstruktur untuk tiap slide onboarding MEKAAR.
class MekaarOnboardingSlideData {
  final String title;
  final String desc;
  final String lottieAsset;
  final Color themeColor;

  const MekaarOnboardingSlideData({
    required this.title,
    required this.desc,
    required this.lottieAsset,
    required this.themeColor,
  });
}

/// Token konfigurasi konveyor panggung paralaks dan panggung onboarding MEKAAR.
/// Menjaga konsistensi nilai panggung tanpa hardcoded styling.
class MekaarOnboardingTokens {
  MekaarOnboardingTokens._();

  // ── Dimensi Panggung Konveyor ──
  static const double stageWidth = 145.0;
  static const double groundlineWidth = 250.0;
  static const double groundlineHeight = 1.5;
  static const double mascotSize = 200.0;

  // ── Rasio Paralaks & Kedalaman ──
  static const double minMascotScale = 0.72;
  static const double maxMascotScale = 1.0;
  static const double minMascotOpacity = 0.40;
  static const double maxMascotOpacity = 1.0;
  static const double maxMascotBlur = 3.5;

  // ── Rasio Kecepatan Paralaks Layer ──
  static const double auraSpeed = 0.20;
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
      themeColor: AppColors.blue,
    ),
    MekaarOnboardingSlideData(
      title: 'Guardian Tepercaya',
      desc:
          'Guardian adalah pelindung Anda. Akses lokasi GPS dan audio hanya aktif saat Anda menekan tombol SOS darurat.',
      lottieAsset: lottieGuardian,
      themeColor: AppColors.warnAmber,
    ),
    MekaarOnboardingSlideData(
      title: 'PIN & Brankas Rahasia',
      desc:
          'Amankan obrolan pribadi, sembunyikan kontak sensitif, dan simpan berkas penting dalam Brankas terenkripsi PIN.',
      lottieAsset: lottieSecurity,
      themeColor: Color(0xFF6366F1), // Indigo Vault
    ),
    MekaarOnboardingSlideData(
      title: 'Privasi Penuh di Tanganmu',
      desc:
          'Semua pesan diamankan dengan enkripsi end-to-end tanpa pelacakan data. Anda memegang kendali sepenuhnya.',
      lottieAsset: lottieSuccess,
      themeColor: AppColors.green,
    ),
  ];
}
