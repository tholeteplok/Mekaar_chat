import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../data/services/privacy_consent_service.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'custom_card.dart';
import 'mekaar_bottom_sheet.dart';

/// MekaarPrivacyConsentBottomSheet — Lembar persetujuan komunikasi privasi
/// dan transparansi radikal arsitektur E2EE MEKAAR 3.0.
///
/// Mengomunikasikan dua sisi koin yang setara: apa yang dilindungi dan apa
/// yang dikorbankan (misal: ganti HP/instal ulang = riwayat percakapan hilang permanen).
class MekaarPrivacyConsentBottomSheet extends StatefulWidget {
  const MekaarPrivacyConsentBottomSheet({super.key});

  /// Menampilkan Bottom Sheet Persetujuan Privasi.
  /// Mengembalikan `true` jika pengguna mencentang dan menekan tombol lanjutkan; `false` jika batal.
  static Future<bool> show({required BuildContext context}) async {
    HapticService.trigger(MekaarHapticIntent.selection);

    final result = await MekaarBottomSheet.show<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => const MekaarPrivacyConsentBottomSheet(),
    );

    return result ?? false;
  }

  @override
  State<MekaarPrivacyConsentBottomSheet> createState() =>
      _MekaarPrivacyConsentBottomSheetState();
}

class _MekaarPrivacyConsentBottomSheetState
    extends State<MekaarPrivacyConsentBottomSheet> {
  bool _isAcknowledged = false;
  bool _isSaving = false;

  Future<void> _handleContinue() async {
    if (!_isAcknowledged || _isSaving) return;

    _isSaving = true;
    HapticService.trigger(MekaarHapticIntent.selection);

    try {
      await PrivacyConsentService.instance.recordConsent();
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.safeTeal.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsBold.shieldCheck,
                    color: AppColors.safeTeal,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sebelum Mulai: Cara Kerja Ruang Aman Ini',
                        style: MekaarTypography.headingSM.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Transparansi penuh tentang perlindungan dan pengorbanannya.',
                        style: MekaarTypography.bodySM.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── 1. Yang Dilindungi ──
            _buildSectionHeader(
              context,
              title: 'Yang Dilindungi',
              icon: SolarIconsBold.lockKeyhole,
              iconColor: AppColors.safeTeal,
            ),
            const SizedBox(height: 8),
            CustomCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletItem(
                    context,
                    'Percakapanmu terenkripsi ujung ke ujung — hanya kamu dan lawan bicaramu yang bisa membaca isinya.',
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                    context,
                    'Tanpa nomor HP. Identitasmu di sini hanya username pilihanmu.',
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                    context,
                    'Pesan dapat diatur menghilang otomatis, dan ruang bisa dibersihkan saat keluar.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 2. Yang Dikorbankan (Baca Baik-Baik) ──
            _buildSectionHeader(
              context,
              title: 'Yang Dikorbankan (baca ini baik-baik)',
              icon: SolarIconsBold.dangerTriangle,
              iconColor: AppColors.warnAmber,
            ),
            const SizedBox(height: 8),
            CustomCard(
              color: isDark
                  ? AppColors.warnAmber.withValues(alpha: 0.08)
                  : AppColors.warnAmber.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.warnAmber.withValues(alpha: 0.35),
                width: 1,
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletItem(
                    context,
                    'Ganti HP atau install ulang = semua riwayat percakapan hilang selamanya. Ini disengaja: kunci enkripsimu ikut musnah bersama perangkat lama, dan tidak ada salinan yang bisa dipulihkan oleh siapa pun, termasuk pengelola server.',
                    isBoldHighlight: true,
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                    context,
                    'Masuk kembali dengan akunmu hanya memulihkan akun dan kontakmu, bukan isi percakapan.',
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                    context,
                    'Lupa PIN berarti memulai sebagai identitas baru dan melakukan verifikasi ulang ke kontak-kontakmu.',
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                    context,
                    'Kami tidak dapat mencegah lawan bicaramu menyimpan tangkapan layar atau memotret layar dengan perangkat lain.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 3. Batas Perlindungannya ──
            _buildSectionHeader(
              context,
              title: 'Batas Perlindungannya',
              icon: SolarIconsBold.infoCircle,
              iconColor: AppColors.blue,
            ),
            const SizedBox(height: 8),
            CustomCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletItem(
                    context,
                    'Server tetap mengetahui siapa terhubung dengan siapa dan kapan — bukan isi pesannya.',
                  ),
                  const SizedBox(height: 10),
                  _buildBulletItem(
                    context,
                    'Perlindungan ini berlaku selama perangkatmu terkunci dan PIN-mu tidak diketahui orang lain.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 4. Checkbox Persetujuan Spesifik ──
            InkWell(
              key: const ValueKey('privacy_consent_checkbox_tile'),
              borderRadius: BorderRadius.circular(MekaarRadius.md),
              onTap: () {
                HapticService.trigger(MekaarHapticIntent.selection);
                setState(() => _isAcknowledged = !_isAcknowledged);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      key: const ValueKey('privacy_consent_checkbox'),
                      value: _isAcknowledged,
                      activeColor: AppColors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        HapticService.trigger(MekaarHapticIntent.selection);
                        setState(() => _isAcknowledged = val ?? false);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Saya paham: jika saya berganti perangkat, riwayat percakapan saya akan hilang permanen, dan itu adalah bagian dari perlindungannya.',
                          style: MekaarTypography.labelMD.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── 5. Tombol Konfirmasi ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('privacy_consent_continue_button'),
                onPressed: _isAcknowledged && !_isSaving ? _handleContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  disabledForegroundColor: textSecondary.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.pill),
                  ),
                ),
                child: Text(
                  'Saya Paham & Lanjutkan',
                  style: MekaarTypography.labelLG.copyWith(
                    color: _isAcknowledged ? Colors.white : textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: MekaarTypography.labelLG.copyWith(
            fontWeight: FontWeight.bold,
            color: MekaarColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(
    BuildContext context,
    String text, {
    bool isBoldHighlight = false,
  }) {
    final textPrimary = MekaarColors.textPrimaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textPrimary.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: MekaarTypography.bodySM.copyWith(
              color: textPrimary,
              height: 1.4,
              fontWeight: isBoldHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
