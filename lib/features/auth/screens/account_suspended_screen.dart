import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/colors.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../providers/auth_provider.dart';

/// Layar Pembekuan Akun (*Account Suspended Screen*)
/// Tampil jika `is_suspended == true` di profil Supabase pengguna.
class AccountSuspendedScreen extends ConsumerWidget {
  final String? reason;
  final String? suspendedAt;

  const AccountSuspendedScreen({
    super.key,
    this.reason,
    this.suspendedAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final displayReason = reason ??
        authState.profile?.suspensionReason ??
        'Terdapat indikasi pelanggaran kebijakan keselamatan atau ketentuan komunitas MEKAAR.';

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Mika Illustration — Prihatin / Sedih
              const MikaIllustration(
                pose: MikaPose.huft,
                size: 140,
              ),
              const SizedBox(height: 24),
              // Judul Pembekuan
              const Text(
                'Akun Anda Dibekukan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MekaarColors.sosRed,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Alasan Suspensi Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MekaarColors.cardDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MekaarColors.sosRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ALASAN PEMBEKUAN:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: MekaarColors.sosRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayReason,
                      style: TextStyle(
                        fontSize: 14,
                        color: MekaarColors.textPrimaryOf(context),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sistem RLS dan akses ruang chat Anda telah dikunci demi keamanan pengguna lain. Jika Anda merasa ini adalah kekeliruan, Anda dapat mengajukan banding ke tim keselamatan.',
                style: TextStyle(
                  fontSize: 12,
                  color: MekaarColors.textSecondaryOf(context),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Tombol Banding / Dukungan
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _launchSupportEmail(displayReason),
                  icon: const Icon(Icons.support_agent_rounded, size: 20),
                  label: const Text(
                    'Hubungi Tim Keselamatan (Banding)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.accentOf(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tombol Keluar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20, color: MekaarColors.sosRed),
                  label: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: MekaarColors.sosRed),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MekaarColors.sosRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchSupportEmail(String reason) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'safety@mekaar.app',
      queryParameters: {
        'subject': 'Permohonan Banding Pembekuan Akun MEKAAR',
        'body': 'Halo Tim Keselamatan MEKAAR,\n\nSaya ingin mengajukan banding atas pembekuan akun saya dengan rincian:\nAlasan: $reason\n\nPenjelasan Tambahan:\n',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
