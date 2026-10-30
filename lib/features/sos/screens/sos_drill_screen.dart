import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/motion.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/sos_button.dart';
import '../../guardian/providers/guardian_provider.dart';
import '../providers/sos_provider.dart';

/// Kunci preferensi lokal untuk status penyelesaian latihan SOS
class SosDrillPrefs {
  SosDrillPrefs._();
  static const String completedAtKey = 'sos_drill_completed_at';
}

/// Langkah-langkah dalam mesin status latihan SOS
enum _DrillStep { intro, hold, simulate, summary }

/// Layar Latihan SOS (Mode Simulasi Mandiri).
///
/// Memungkinkan pengguna dan wali berlatih alur SOS tanpa memicu sirene,
/// panggilan darurat, streaming lokasi GPS, atau transmisi jaringan luar apa pun.
class SosDrillScreen extends ConsumerStatefulWidget {
  const SosDrillScreen({super.key});

  @override
  ConsumerState<SosDrillScreen> createState() => _SosDrillScreenState();
}

class _SosDrillScreenState extends ConsumerState<SosDrillScreen> {
  _DrillStep _step = _DrillStep.intro;
  int _simulationStage = 0;
  Timer? _simulationTimer;

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startHoldStep() {
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _step = _DrillStep.hold;
    });
  }

  void _onDrillTriggered() {
    HapticService.trigger(MekaarHapticIntent.success);
    setState(() {
      _step = _DrillStep.simulate;
      _simulationStage = 0;
    });

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      setState(() {
        _simulationStage = 3;
      });
      return;
    }

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 650), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_simulationStage < 3) {
        setState(() {
          _simulationStage++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _goToSummary() {
    _simulationTimer?.cancel();
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _step = _DrillStep.summary;
    });
  }

  void _repeatDrill() {
    _simulationTimer?.cancel();
    HapticService.trigger(MekaarHapticIntent.selection);
    setState(() {
      _step = _DrillStep.hold;
      _simulationStage = 0;
    });
  }

  Future<void> _finishDrill() async {
    HapticService.trigger(MekaarHapticIntent.success);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SosDrillPrefs.completedAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Cek keamanan: Tolak latihan jika SOS nyata sedang aktif
    final isRealSosActive = ref.watch(
      sosProvider.select(
        (s) =>
            s.status == SOSStatus.active || s.status == SOSStatus.queuedOffline,
      ),
    );

    if (isRealSosActive) {
      return Scaffold(
        backgroundColor: MekaarColors.backgroundOf(context),
        appBar: AppBar(
          title: const Text('Latihan SOS'),
          backgroundColor: MekaarColors.surfaceOf(context),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  SolarIconsOutline.dangerCircle,
                  color: MekaarColors.sosRed,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'SOS Nyata Sedang Aktif',
                  style: MekaarTypography.headingMD.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mode latihan tidak dapat dibuka saat sesi darurat nyata sedang berjalan.',
                  style: MekaarTypography.bodyMD,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.sosRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.sosActive,
                    );
                  },
                  child: const Text('Buka Layar Darurat Nyata'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final guardians = ref.watch(guardianProvider);
    final targetGuardianName = guardians.isNotEmpty
        ? guardians.first.name
        : 'Wali Siaga';

    return Scaffold(
      backgroundColor: MekaarColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(
          'Latihan SOS (Simulasi)',
          style: MekaarTypography.headingSM.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: MekaarColors.surfaceOf(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(SolarIconsOutline.arrowLeft),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Simulasi Persisten Wajib (tampil di semua langkah)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: MekaarBanner(
                color: MekaarColors.warnAmber,
                icon: SolarIconsOutline.shieldWarning,
                content: Text(
                  'SIMULASI — Tidak ada sinyal bahaya, pesan, lokasi GPS, atau alarm yang dikirim ke pihak mana pun.',
                  style: MekaarTypography.caption.copyWith(
                    color: MekaarColors.warnAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: MekaarMotion.normal,
                child: _buildCurrentStep(targetGuardianName),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(String guardianName) {
    switch (_step) {
      case _DrillStep.intro:
        return _buildIntroStep();
      case _DrillStep.hold:
        return _buildHoldStep();
      case _DrillStep.simulate:
        return _buildSimulateStep(guardianName);
      case _DrillStep.summary:
        return _buildSummaryStep();
    }
  }

  Widget _buildIntroStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_intro'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsOutline.shieldCheck,
                color: AppColors.blue,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Latih Refleks Darurat Anda',
            style: MekaarTypography.headingMD.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Ketahui persis bagaimana tombol darurat bekerja sebelum Anda benar-benar membutuhkannya.',
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          CustomCard(
            child: Column(
              children: [
                _buildInfoRow(
                  icon: SolarIconsOutline.shield,
                  title: '100% Aman & Bebas Risiko',
                  subtitle:
                      'Tidak ada notifikasi ke wali, tidak ada sirene keras, dan tidak ada pelacakan GPS.',
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: SolarIconsOutline.handShake,
                  title: 'Latih Memori Otot',
                  subtitle:
                      'Rasakan getaran tombol SOS saat ditahan selama 2 detik penuh hingga aktif.',
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: SolarIconsOutline.eye,
                  title: 'Lihat Tampilan Wali',
                  subtitle:
                      'Pelajari apa yang akan dilihat wali darurat saat sinyal SOS dikirimkan.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: _startHoldStep,
            child: Text(
              'Mulai Latihan',
              style: MekaarTypography.labelLG.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.blue, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MekaarTypography.labelLG.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHoldStep() {
    return Center(
      key: const ValueKey('step_hold'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tahan Tombol SOS',
              style: MekaarTypography.headingMD.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan dan tahan tombol di bawah selama 2 detik penuh hingga lingkaran terisi sempurna.',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Menggunakan widget SOSButton asli aplikasi untuk konsistensi memori otot
            SOSButton(
              onPressed: _onDrillTriggered,
              isActive: false,
              size: 88,
              holdDuration: const Duration(seconds: 2),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MekaarColors.surface2Of(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    SolarIconsOutline.infoCircle,
                    size: 16,
                    color: MekaarColors.textMutedOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pelepasan sebelum 2 detik akan membatalkan',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulateStep(String guardianName) {
    return SingleChildScrollView(
      key: const ValueKey('step_simulate'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Alur Pengiriman Simulasi',
            style: MekaarTypography.headingMD.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Berikut tahapan yang terjadi di latar belakang saat SOS aktif:',
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Tahap 1: Penguncian & Persiapan
          _buildSimulationTile(
            stepNumber: 1,
            title: 'Persiapan Keamanan Perangkat',
            subtitle: 'Kunci otomatis aktif, GPS diinisialisasi secara lokal.',
            isDone: _simulationStage >= 1,
            inProgress: _simulationStage == 0,
          ),
          const SizedBox(height: 12),

          // Tahap 2: Pengiriman Sinyal ke Guardian
          _buildSimulationTile(
            stepNumber: 2,
            title: 'Peringatan ke $guardianName',
            subtitle: _simulationStage >= 2
                ? 'Sinyal terkirim (simulasi).'
                : 'Mengirim sinyal simulasi...',
            isDone: _simulationStage >= 2,
            inProgress: _simulationStage == 1,
          ),
          const SizedBox(height: 12),

          // Tahap 3: Pratinjau Tampilan Wali
          _buildSimulationTile(
            stepNumber: 3,
            title: 'Tampilan yang Diterima Wali',
            subtitle: 'Wali menerima pesan darurat & status keamanan.',
            isDone: _simulationStage >= 3,
            inProgress: _simulationStage == 2,
          ),
          const SizedBox(height: 24),

          // Kartu Mockup Tampilan Wali
          if (_simulationStage >= 2) ...[
            CustomCard(
              color: MekaarColors.surface2Of(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MekaarColors.sosRed.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          SolarIconsOutline.dangerTriangle,
                          color: MekaarColors.sosRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pratinjau Notifikasi Wali',
                        style: MekaarTypography.labelMD.copyWith(
                          fontWeight: FontWeight.bold,
                          color: MekaarColors.sosRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '🚨 Peringatan SOS: Membutuhkan Bantuan Segera! [Simulasi Latihan]',
                    style: MekaarTypography.bodySM.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: Sinyal darurat aktif · Titik koordinat aman (simulasi) · Sirene berbunyi.',
                    style: MekaarTypography.caption.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
            onPressed: _goToSummary,
            child: Text(
              'Lanjut ke Rangkuman',
              style: MekaarTypography.labelLG.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationTile({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool inProgress,
  }) {
    Color iconColor;
    Widget leadingWidget;

    if (isDone) {
      iconColor = AppColors.green;
      leadingWidget = const Icon(
        SolarIconsOutline.checkCircle,
        color: AppColors.green,
        size: 24,
      );
    } else if (inProgress) {
      iconColor = AppColors.blue;
      leadingWidget = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else {
      iconColor = MekaarColors.textMutedOf(context);
      leadingWidget = Text(
        '$stepNumber',
        style: MekaarTypography.labelMD.copyWith(
          color: MekaarColors.textMutedOf(context),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MekaarColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(MekaarRadius.md),
        border: Border.all(
          color: inProgress
              ? AppColors.blue.withValues(alpha: 0.5)
              : MekaarColors.cardBorderOf(context),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: leadingWidget)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MekaarTypography.labelLG.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDone || inProgress
                        ? MekaarColors.textPrimaryOf(context)
                        : MekaarColors.textMutedOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: MekaarTypography.caption.copyWith(color: iconColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_summary'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsOutline.verifiedCheck,
                color: AppColors.green,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Latihan SOS Selesai!',
            style: MekaarTypography.headingMD.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Anda telah berhasil mempraktikkan pengaktifan darurat dan alur simulasi pengirimannya.',
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catatan Keselamatan Nyata',
                  style: MekaarTypography.labelLG.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MekaarColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSummaryBullet(
                  'Pembatalan SOS nyata selalu mewajibkan verifikasi PIN Anda untuk mencegah paksaan.',
                ),
                const SizedBox(height: 8),
                _buildSummaryBullet(
                  'Dalam situasi nyata, sirene alarm ponsel akan berbunyi kencang agar warga sekitar waspada.',
                ),
                const SizedBox(height: 8),
                _buildSummaryBullet(
                  'Pastikan Anda memiliki minimal 1 Guardian aktif yang siap merespons kapan pun.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  onPressed: _repeatDrill,
                  child: const Text('Ulangi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.md),
                    ),
                  ),
                  onPressed: _finishDrill,
                  child: Text(
                    'Selesai',
                    style: MekaarTypography.labelLG.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            SolarIconsOutline.checkCircle,
            size: 14,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: MekaarTypography.bodySM.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}
