import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_glass_blur_container.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_update_dialog.dart';
import '../../../core/widgets/mekaar_crypto_donation_bottom_sheet.dart';
import '../../../core/widgets/mekaar_permissions_bottom_sheet.dart';
import '../../../data/services/update_service.dart';
import '../widgets/settings_tiles.dart';

class AboutMekaarScreen extends ConsumerStatefulWidget {
  const AboutMekaarScreen({super.key});

  @override
  ConsumerState<AboutMekaarScreen> createState() => _AboutMekaarScreenState();
}

class _AboutMekaarScreenState extends ConsumerState<AboutMekaarScreen> {
  String _currentVersion = 'Memuat...';
  bool _isCheckingUpdate = false;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final updateService = ref.read(updateServiceProvider);
    final version = await updateService.getCurrentVersion();
    if (mounted) {
      setState(() {
        _currentVersion = version;
      });
    }
  }

  Future<void> _handleCheckUpdate() async {
    if (_isCheckingUpdate) return;
    HapticService.trigger(MekaarHapticIntent.selection);

    setState(() {
      _isCheckingUpdate = true;
      _updateInfo = null;
    });

    final updateService = ref.read(updateServiceProvider);
    final info = await updateService.checkForUpdate(
      currentVersionOverride:
          _currentVersion != 'Memuat...' ? _currentVersion : null,
    );

    if (!mounted) return;

    setState(() {
      _isCheckingUpdate = false;
      _updateInfo = info;
    });

    if (info.errorMessage != null) {
      MekaarSnackbar.error(context, info.errorMessage!);
    } else if (info.hasUpdate) {
      HapticService.trigger(MekaarHapticIntent.success);
      _showUpdateDialog(info);
    } else {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        'Aplikasi MEKAAR Anda sudah versi paling mutakhir (v$_currentVersion).',
      );
    }
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    final sizeText = info.formattedSize.isNotEmpty
        ? '\nUkuran Paket: ${info.formattedSize}'
        : '';
    final abiText =
        info.matchedAbi != 'universal' ? ' (${info.matchedAbi})' : '';

    MekaarDialog.showConfirmation<void>(
      context: context,
      title: 'Pembaruan Tersedia 🚀',
      message:
          'Versi baru ${info.latestVersion}$abiText telah tersedia!$sizeText\n\n${info.releaseName}\n\nCatatan Rilis:\n${info.releaseNotes}',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Nanti'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.accentOf(context),
            foregroundColor: MekaarColors.textOnBlue,
          ),
          onPressed: () {
            Navigator.pop(context);
            _startInAppUpdate(info);
          },
          icon: const Icon(SolarIconsOutline.download, size: 16),
          label: Text(
            info.formattedSize.isNotEmpty
                ? 'Unduh (${info.formattedSize.split('·').first.trim()})'
                : 'Unduh Sekarang',
          ),
        ),
      ],
    );
  }

  Future<void> _startInAppUpdate(AppUpdateInfo info) async {
    await showInAppUpdateDialog(
      context: context,
      info: info,
      onOpenUrl: _openUrl,
    );
  }

  Future<void> _openUrl(String urlString) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final target = urlString.trim().isNotEmpty
        ? urlString.trim()
        : 'https://github.com/tholeteplok/Mekaar_chat';
    try {
      final uri = Uri.parse(target);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallbackLaunched =
            await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      }
    } catch (_) {
      try {
        final uri = Uri.parse(target);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          MekaarSnackbar.error(context, 'Tidak dapat membuka tautan.');
        }
      }
    }
  }

  void _showPhilosophySheet(BuildContext context) {
    HapticService.trigger(MekaarHapticIntent.selection);
    final pillars = [
      (
        icon: SolarIconsOutline.shieldKeyhole,
        title: 'Aegis Shield (E2EE)',
        desc:
            'Komunikasi terenkripsi penuh dari ujung ke ujung menggunakan kriptografi asimetris modern X25519 & ChaCha20-Poly1305.',
        color: MekaarColors.guardianTeal,
      ),
      (
        icon: SolarIconsOutline.lock,
        title: 'Zero-Knowledge & Privacy-First',
        desc:
            'Data adalah milik Anda seutuhnya. Tanpa pelacakan analytics komersial, bebas data mining, dan bebas iklan.',
        color: MekaarColors.accentOf(context),
      ),
      (
        icon: SolarIconsOutline.flame,
        title: 'Burn on Exit & Scheduled Wipe',
        desc:
            'Mendukung pemusnahan pesan instan saat keluar layar obrolan serta pembersihan terjadwal berbasis jam secara otomatis.',
        color: MekaarColors.sosRed,
      ),
      (
        icon: SolarIconsOutline.shieldUser,
        title: 'Guardian & Emergency SOS',
        desc:
            'Jaringan wali terpercaya untuk memantau keamanan rute perjalanan (Auto Check-In) dan eskalasi darurat SOS real-time.',
        color: MekaarColors.softCoral,
      ),
      (
        icon: SolarIconsOutline.eyeClosed,
        title: 'Plausible Deniability',
        desc:
            'Dilengkapi PIN Paksaan (Duress) dan Private Contact Vault stealth untuk perlindungan integritas fisik dari paksaan pihak lain.',
        color: MekaarColors.warnAmber,
      ),
    ];

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MekaarColors.softCoral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    SolarIconsOutline.heartAngle,
                    color: MekaarColors.softCoral,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filosofi & Pilar Keamanan',
                        style: MekaarTypography.headingMD.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '5 prinsip perlindungan & integritas data MEKAAR',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < pillars.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: pillars[i].color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(MekaarRadius.sm),
                              ),
                              child: Icon(
                                pillars[i].icon,
                                color: pillars[i].color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pillars[i].title,
                                    style: MekaarTypography.bodyMD.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: MekaarColors.textPrimaryOf(context),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    pillars[i].desc,
                                    style: MekaarTypography.bodySM.copyWith(
                                      color: MekaarColors.textSecondaryOf(context),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < pillars.length - 1)
                        const MekaarCardDivider(fullWidth: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showHighlightsSheet(BuildContext context) {
    HapticService.trigger(MekaarHapticIntent.selection);
    final highlights = [
      (
        title: 'Burn on Exit',
        desc: 'Hapus riwayat obrolan seketika saat meninggalkan layar chat.',
      ),
      (
        title: 'Pembersihan Terjadwal (Scheduled Wipe)',
        desc: 'Pembersihan room otomatis 1x atau harian pada jam yang ditentukan.',
      ),
      (
        title: 'Private Contact Vault',
        desc: 'Ruang kontak rahasia dengan aktivasi kode via Search Bar & salted hash.',
      ),
      (
        title: 'Stealth Cloaking Asimetris',
        desc: 'Sembunyikan jejak kontak rahasia pada Tab Pesan, Kontak, dan Pemilihan Anggota Grup.',
      ),
      (
        title: 'Pelindung Layar Bidirectional',
        desc: 'Perlindungan anti-screenshot dan blokir perekaman layar.',
      ),
      (
        title: 'Aegis Shield E2EE',
        desc: 'Enkripsi ChaCha20-Poly1305 & X25519 dengan verifikasi sidik jari kunci.',
      ),
      (
        title: 'Mode Darurat SOS & Rute Aman',
        desc: 'Sirine Guardian, pemantauan rute perjalanan, dan eskalasi darurat real-time.',
      ),
    ];

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MekaarColors.accentTextOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    SolarIconsOutline.notes,
                    color: MekaarColors.accentTextOf(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fitur & Kemampuan Utama',
                        style: MekaarTypography.headingMD.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '7 fitur keamanan unggulan MEKAAR',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < highlights.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                SolarIconsBold.checkCircle,
                                color: MekaarColors.guardianTeal,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    highlights[i].title,
                                    style: MekaarTypography.bodyMD.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: MekaarColors.textPrimaryOf(context),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    highlights[i].desc,
                                    style: MekaarTypography.bodySM.copyWith(
                                      color: MekaarColors.textSecondaryOf(context),
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < highlights.length - 1)
                        const MekaarCardDivider(fullWidth: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTermsAndPrivacySheet(BuildContext context) {
    HapticService.trigger(MekaarHapticIntent.selection);
    final terms = [
      (
        icon: SolarIconsOutline.shieldKeyhole,
        title: 'Komitmen Zero-Knowledge',
        desc:
            'Server MEKAAR tidak pernah menyimpan kunci privat atau memiliki akses dekripsi terhadap pesan, panggilan, dan media Anda.',
      ),
      (
        icon: SolarIconsOutline.forbiddenCircle,
        title: 'Bebas Iklan & Pelacak Komersial',
        desc:
            'Aplikasi beroperasi secara independen tanpa pelacak pihak ketiga, tanpa profil analitik iklan, dan tanpa monetisasi data pribadi.',
      ),
      (
        icon: SolarIconsOutline.keySquare,
        title: 'Kedaulatan Kunci Kriptografi',
        desc:
            'Setiap pasangan kunci enkripsi disimpan secara eksklusif di penyimpanan aman perangkat lokal Anda.',
      ),
      (
        icon: SolarIconsOutline.usersGroupTwoRounded,
        title: 'Etika & Perlindungan Komunitas',
        desc:
            'Aplikasi ditujukan untuk keselamatan pribadi. Dilarang keras menyalahgunakan sistem ini untuk aktivitas ilegal atau pelecehan.',
      ),
    ];

    MekaarBottomSheet.show(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    SolarIconsOutline.documentText,
                    color: MekaarColors.guardianTeal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Syarat Layanan & Privasi',
                        style: MekaarTypography.headingMD.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Prinsip perlindungan hukum & zero-knowledge MEKAAR',
                        style: MekaarTypography.bodySM.copyWith(
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < terms.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(MekaarRadius.sm),
                              ),
                              child: Icon(
                                terms[i].icon,
                                color: MekaarColors.guardianTeal,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    terms[i].title,
                                    style: MekaarTypography.bodyMD.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: MekaarColors.textPrimaryOf(context),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    terms[i].desc,
                                    style: MekaarTypography.bodySM.copyWith(
                                      color: MekaarColors.textSecondaryOf(context),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < terms.length - 1)
                        const MekaarCardDivider(fullWidth: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHubItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.65);
    final glassBorder = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.black.withValues(alpha: 0.07),
      width: 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MekaarGlassBlurContainer(
          isFloating: true,
          width: 56,
          height: 56,
          borderRadius: BorderRadius.circular(18),
          padding: EdgeInsets.zero,
          border: glassBorder,
          customColor: glassBg,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Center(
              child: Icon(
                icon,
                size: 22,
                color: iconColor ?? MekaarColors.textPrimaryOf(context),
              ),
            ),
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: MekaarTypography.labelSM.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: MekaarColors.textSecondaryOf(context),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNewUpdate = _updateInfo?.hasUpdate ?? false;

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Tentang MEKAAR'),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8).copyWith(bottom: 36),
                children: [
                  // ── 1. Hero Brand Header (Terpusat & Bersih) ──
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Logo Squircle
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MekaarRadius.xl),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.blue.withValues(alpha: isDark ? 0.25 : 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(MekaarRadius.xl),
                            child: Image.asset(
                              'assets/logo/app_icon.webp',
                              width: 88,
                              height: 88,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(MekaarRadius.xl),
                                ),
                                child: const Icon(
                                  SolarIconsBold.shieldCheck,
                                  size: 48,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Nama Brand
                        Text(
                          'Mekaar',
                          style: MekaarTypography.headingLG.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),

                        // Subtitle
                        Text(
                          'Personal-Safety & Privacy-First Messenger',
                          style: MekaarTypography.bodyMD.copyWith(
                            color: MekaarColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6),

                        // Versi Aplikasi
                        Text(
                          'Versi $_currentVersion',
                          style: MekaarTypography.caption.copyWith(
                            color: MekaarColors.textMutedOf(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Status Pembaruan Pill Button ──
                        InkWell(
                          borderRadius: BorderRadius.circular(MekaarRadius.xl),
                          onTap: _isCheckingUpdate
                              ? null
                              : () {
                                  if (hasNewUpdate) {
                                    _showUpdateDialog(_updateInfo!);
                                  } else {
                                    _handleCheckUpdate();
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: hasNewUpdate
                                  ? MekaarColors.sosRed.withValues(alpha: 0.15)
                                  : AppColors.blue.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(MekaarRadius.xl),
                              border: Border.all(
                                color: hasNewUpdate
                                    ? MekaarColors.sosRed.withValues(alpha: 0.4)
                                    : AppColors.blue.withValues(alpha: isDark ? 0.4 : 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isCheckingUpdate) ...[
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Memeriksa Pembaruan...',
                                    style: TextStyle(
                                      color: AppColors.blue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else if (hasNewUpdate) ...[
                                  const Icon(
                                    SolarIconsBold.cloudUpload,
                                    color: MekaarColors.sosRed,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pembaruan Tersedia (v${_updateInfo!.latestVersion})',
                                    style: const TextStyle(
                                      color: MekaarColors.sosRed,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    SolarIconsBold.refresh,
                                    color: AppColors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Cek Pembaruan',
                                    style: TextStyle(
                                      color: AppColors.blue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 2. Quick Channels Action Hub (3 Frosted Glass Buttons) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionHubItem(
                          icon: SolarIconsOutline.letter,
                          label: 'Bantuan',
                          onTap: () => _openUrl('https://github.com/tholeteplok/Mekaar_chat/issues'),
                        ),
                        _buildActionHubItem(
                          icon: SolarIconsOutline.code2,
                          label: 'GitHub',
                          onTap: () => _openUrl('https://github.com/tholeteplok/Mekaar_chat'),
                        ),
                        _buildActionHubItem(
                          icon: SolarIconsBold.wallet2,
                          label: 'Donasi',
                          iconColor: AppColors.blue,
                          onTap: () => MekaarCryptoDonationBottomSheet.show(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 3. Grouped CustomCard (4 Menu Utama Tanpa Duplikasi) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CustomCard(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // 1. Filosofi & Pilar Keamanan
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MekaarColors.softCoral.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(MekaarRadius.sm),
                              ),
                              child: const Icon(
                                SolarIconsOutline.heartAngle,
                                color: MekaarColors.softCoral,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Filosofi & Pilar Keamanan',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '5 prinsip perlindungan & integritas data',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            trailing: Icon(
                              SolarIconsOutline.altArrowRight,
                              size: 16,
                              color: MekaarColors.textMutedOf(context),
                            ),
                            onTap: () => _showPhilosophySheet(context),
                          ),
                          const MekaarCardDivider(),

                          // 2. Fitur & Kemampuan Utama
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MekaarColors.accentTextOf(context).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(MekaarRadius.sm),
                              ),
                              child: Icon(
                                SolarIconsOutline.notes,
                                color: MekaarColors.accentTextOf(context),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Fitur & Kemampuan Utama',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '7 fitur keamanan unggulan MEKAAR',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            trailing: Icon(
                              SolarIconsOutline.altArrowRight,
                              size: 16,
                              color: MekaarColors.textMutedOf(context),
                            ),
                            onTap: () => _showHighlightsSheet(context),
                          ),
                          const MekaarCardDivider(),

                          // 3. Syarat Layanan & Privasi
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MekaarColors.guardianTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(MekaarRadius.sm),
                              ),
                              child: const Icon(
                                SolarIconsOutline.documentText,
                                color: MekaarColors.guardianTeal,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Syarat Layanan & Privasi',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'Komitmen zero-knowledge & hak pengguna',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            trailing: Icon(
                              SolarIconsOutline.altArrowRight,
                              size: 16,
                              color: MekaarColors.textMutedOf(context),
                            ),
                            onTap: () => _showTermsAndPrivacySheet(context),
                          ),
                          const MekaarCardDivider(),

                          // 4. Perizinan & Hak Akses Perangkat
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: MekaarColors.warnAmber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(MekaarRadius.sm),
                              ),
                              child: const Icon(
                                SolarIconsOutline.shieldCheck,
                                color: MekaarColors.warnAmber,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Perizinan & Hak Akses',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'Kamera, mikrofon, lokasi, & notifikasi',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: MekaarColors.textMutedOf(context),
                              ),
                            ),
                            trailing: Icon(
                              SolarIconsOutline.altArrowRight,
                              size: 16,
                              color: MekaarColors.textMutedOf(context),
                            ),
                            onTap: () => MekaarPermissionsBottomSheet.show(
                              context: context,
                              onGrant: () async {
                                await openAppSettings();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 28),

                  // ── 4. Footer Kriptografi & Lisensi ──
                  Center(
                    child: Text(
                      'MEKAAR Personal Safety System · Open Source\nDilindungi oleh Kriptografi & Komitmen Privasi Mutlak',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
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
}