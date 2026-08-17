import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/bounce_interactive.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_card_divider.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_wordmark.dart';
import '../../../data/services/update_service.dart';

class AboutMekaarScreen extends ConsumerStatefulWidget {
  const AboutMekaarScreen({super.key});

  @override
  ConsumerState<AboutMekaarScreen> createState() => _AboutMekaarScreenState();
}

class _AboutMekaarScreenState extends ConsumerState<AboutMekaarScreen> {
  String _currentVersion = '1.0.0+1';
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
      setState(() => _currentVersion = version);
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
      currentVersionOverride: _currentVersion,
    );

    if (mounted) {
      setState(() {
        _isCheckingUpdate = false;
        _updateInfo = info;
      });

      if (info.hasUpdate) {
        HapticService.trigger(MekaarHapticIntent.success);
        _showUpdateDialog(info);
      } else if (info.errorMessage != null) {
        MekaarSnackbar.error(context, info.errorMessage!);
      } else {
        HapticService.trigger(MekaarHapticIntent.success);
        MekaarSnackbar.success(
          context,
          'Aplikasi MEKAAR Anda sudah versi paling mutakhir (v$_currentVersion).',
        );
      }
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
          'Versi baru ${info.latestVersion}$abiText telah tersedia di GitHub Releases!$sizeText\n\n${info.releaseName}\n\nCatatan Rilis:\n${info.releaseNotes}',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: MekaarColors.cyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            _openUrl(
              info.downloadUrl.isNotEmpty
                  ? info.downloadUrl
                  : (info.htmlUrl.isNotEmpty
                      ? info.htmlUrl
                      : 'https://github.com/tholeteplok/Mekaar_chat/releases'),
            );
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

  Future<void> _openUrl(String urlString) async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final target = urlString.trim().isNotEmpty
        ? urlString.trim()
        : 'https://github.com/tholeteplok/Mekaar_chat/releases';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MekaarScaffold(
      appBar: const CustomAppBar(
        title: 'Tentang MEKAAR',
        subtitle: 'Informasi Versi & Filosofi Keamanan',
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: MekaarSpacing.md,
          vertical: MekaarSpacing.sm,
        ).copyWith(bottom: 40),
        children: [
          // ── 1. Hero Brand Header ──
          _buildBrandHero(),
          const SizedBox(height: MekaarSpacing.md),

          // ── 2. Card Status Pembaruan ──
          _buildUpdateCard(),
          const SizedBox(height: MekaarSpacing.md),

          // ── 3. Card Filosofi & Prinsip Desain ──
          _buildPhilosophyCard(),
          const SizedBox(height: MekaarSpacing.md),

          // ── 4. Card Riwayat Pembaruan & Fitur Unggulan ──
          _buildChangelogCard(),
          const SizedBox(height: MekaarSpacing.md),

          // ── 5. Card Transparansi & Komunitas ──
          _buildCommunityCard(),
          const SizedBox(height: MekaarSpacing.lg),

          // ── Footer Copyright ──
          Center(
            child: Text(
              'MEKAAR Personal Safety System · Open Source\nDilindungi oleh Kriptografi & Komitmen Privasi Mutlak',
              style: MekaarTypography.caption.copyWith(
                color: isDark ? MekaarColors.textMuted : const Color(0xFF8C95AA),
                fontSize: 11,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHero() {
    return CustomCard(
      padding: const EdgeInsets.symmetric(
        horizontal: MekaarSpacing.md,
        vertical: MekaarSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: MekaarColors.cyan.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/logo/app_icon.webp',
                width: 88,
                height: 88,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  SolarIconsBold.shieldCheck,
                  size: 72,
                  color: MekaarColors.cyan,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const MekaarWordmark(fontSize: 26),
          const SizedBox(height: 4),
          Text(
            'Personal-Safety & Privacy-First Messenger',
            style: MekaarTypography.bodySM.copyWith(
              color: MekaarColors.textSecondaryOf(context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MekaarColors.border.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              'Versi $_currentVersion',
              style: MekaarTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: MekaarColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard() {
    final hasNewUpdate = _updateInfo?.hasUpdate ?? false;

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasNewUpdate ? MekaarColors.sosRed : MekaarColors.cyan)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasNewUpdate
                      ? SolarIconsBold.cloudUpload
                      : SolarIconsBold.checkCircle,
                  color: hasNewUpdate ? MekaarColors.sosRed : MekaarColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasNewUpdate
                          ? 'Pembaruan Tersedia'
                          : 'Status Versi Aplikasi',
                      style: MekaarTypography.bodyMD.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MekaarColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      hasNewUpdate
                          ? 'Versi ${_updateInfo!.latestVersion} siap diunduh'
                          : 'Aplikasi Anda mutakhir (v$_currentVersion)',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const MekaarCardDivider(),
          const SizedBox(height: 12),
          if (hasNewUpdate) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Catatan Rilis ${_updateInfo!.latestVersion}:',
                    style: MekaarTypography.bodySM.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (_updateInfo!.formattedSize.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MekaarColors.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: MekaarColors.cyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _updateInfo!.formattedSize,
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _updateInfo!.releaseNotes,
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MekaarColors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openUrl(_updateInfo!.downloadUrl),
                    icon: const Icon(SolarIconsOutline.download, size: 18),
                    label: Text(
                      _updateInfo!.formattedSize.isNotEmpty
                          ? 'Unduh APK (${_updateInfo!.formattedSize.split('·').first.trim()})'
                          : 'Unduh APK Rilis',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: BounceInteractive(
                    onTap: _isCheckingUpdate ? null : _handleCheckUpdate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: MekaarColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MekaarColors.cyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isCheckingUpdate) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: MekaarColors.cyan,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Menghubungi GitHub...',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              SolarIconsOutline.refreshCircle,
                              color: MekaarColors.cyan,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Periksa Pembaruan',
                              style: MekaarTypography.bodySM.copyWith(
                                color: MekaarColors.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhilosophyCard() {
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
        color: MekaarColors.cyan,
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

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                SolarIconsOutline.heartAngle,
                color: MekaarColors.softCoral,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Filosofi & Pilar Keamanan',
                style: MekaarTypography.bodyMD.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const MekaarCardDivider(),
          const SizedBox(height: 8),
          for (int i = 0; i < pillars.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: pillars[i].color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      pillars[i].icon,
                      color: pillars[i].color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pillars[i].title,
                          style: MekaarTypography.bodySM.copyWith(
                            fontWeight: FontWeight.bold,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pillars[i].desc,
                          style: MekaarTypography.caption.copyWith(
                            color: MekaarColors.textSecondaryOf(context),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < pillars.length - 1) const MekaarCardDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildChangelogCard() {
    final highlights = [
      'Fitur Burn on Exit (Hapus riwayat obrolan seketika saat meninggalkan layar chat)',
      'Fitur Pembersihan Terjadwal Berbasis Jam (Scheduled Room Wipe) 1x / Harian',
      'Private Contact Vault dengan aktivasi kode rahasia via Search Bar & salted hash',
      'Stealth Cloaking Asimetris pada Tab Pesan, Tab Kontak, dan Calon Anggota Grup',
      'Pelindung Layar Bidirectional (Anti Screenshot & Screen Recording)',
      'Aegis Shield E2EE (ChaCha20-Poly1305 & X25519) dengan Verifikasi Sidik Jari Kunci',
      'Mode Darurat SOS, Sirine Guardian, dan Pelacakan Rute Hangout Realtime',
    ];

    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                SolarIconsOutline.notes,
                color: MekaarColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Fitur & Kemampuan Utama',
                style: MekaarTypography.bodyMD.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const MekaarCardDivider(),
          const SizedBox(height: 8),
          for (final item in highlights) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      SolarIconsBold.checkCircle,
                      color: MekaarColors.guardianTeal,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textPrimaryOf(context),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommunityCard() {
    return CustomCard(
      padding: const EdgeInsets.all(MekaarSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                SolarIconsOutline.code2,
                color: MekaarColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Transparansi & Sumber Terbuka',
                style: MekaarTypography.bodyMD.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kode sumber MEKAAR dapat diaudit secara terbuka untuk menjamin tidak adanya celah keamanan tersembunyi (backdoor).',
            style: MekaarTypography.caption.copyWith(
              color: MekaarColors.textSecondaryOf(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          const MekaarCardDivider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MekaarColors.surface2Of(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                SolarIconsOutline.linkCircle,
                color: MekaarColors.cyan,
                size: 20,
              ),
            ),
            title: Text(
              'Repositori GitHub',
              style: MekaarTypography.bodySM.copyWith(
                fontWeight: FontWeight.bold,
                color: MekaarColors.textPrimaryOf(context),
              ),
            ),
            subtitle: Text(
              'github.com/tholeteplok/Mekaar_chat',
              style: MekaarTypography.caption.copyWith(
                color: MekaarColors.cyan,
              ),
            ),
            trailing: const Icon(
              SolarIconsOutline.arrowRightUp,
              color: MekaarColors.cyan,
              size: 18,
            ),
            onTap: () => _openUrl('https://github.com/tholeteplok/Mekaar_chat'),
          ),
        ],
      ),
    );
  }
}
