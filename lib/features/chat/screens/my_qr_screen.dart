import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../auth/providers/auth_provider.dart';

/// MyQrScreen — Layar QR Code Profil & Integrasi Pemindai ala Telegram.
///
/// Menyajikan kartu QR profil dengan avatar melayang (overlapping)
/// serta tombol aksi terpadu untuk berbagi dan memindai QR teman.
class MyQrScreen extends ConsumerStatefulWidget {
  const MyQrScreen({super.key});

  static String payloadFor(String userId) => 'mekaar://user/$userId';

  @override
  ConsumerState<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends ConsumerState<MyQrScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    final name =
        authState.profile?.fullName ?? authState.profile?.username ?? 'User';
    final username = authState.profile?.username ?? '';
    final avatarUrl = authState.profile?.avatarUrl;

    final isDark = MekaarColors.isDarkContext(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MekaarScaffold(
      flat: false,
      appBar: const CustomAppBar(title: 'Kode QR Profil'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Tunjukkan kode QR ini ke teman Anda agar dapat langsung terhubung dalam obrolan terenkripsi Mekaar Aegis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: MekaarColors.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            if (userId == null)
              const MekaarStateView(
                pose: MikaPose.key,
                title: 'Menyiapkan Kode QR',
                message: 'Menghasilkan kode profil Anda…',
                semanticLabel: 'Memuat kode QR profil',
              )
            else ...[
              // ── Telegram-Style Overlapping QR Card ──
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // White/Surface QR Card Container
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    decoration: BoxDecoration(
                      color: isDark ? MekaarColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(MekaarRadius.xl),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.35 : 0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // QR Image Container with Rounded Edge
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(MekaarRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: MyQrScreen.payloadFor(userId),
                            version: QrVersions.auto,
                            size: 210,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF0F172A),
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF0F172A),
                            ),
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Full Name
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: MekaarTypography.headingMD.copyWith(
                            fontWeight: FontWeight.w800,
                            color: MekaarColors.textPrimaryOf(context),
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            textAlign: TextAlign.center,
                            style: MekaarTypography.labelLG.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Micro Protection Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: MekaarColors.guardianTeal
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(MekaarRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                SolarIconsBold.shieldCheck,
                                size: 13,
                                color: MekaarColors.safeTextOf(context),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Mekaar Aegis E2EE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: MekaarColors.safeTextOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Overlapping Floating Avatar
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? MekaarColors.cardDark : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Avatar(
                        imageUrl: avatarUrl,
                        initial: name,
                        size: 72,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // ── Primary Action: Salin & Bagikan QR ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticService.trigger(MekaarHapticIntent.success);
                    Clipboard.setData(
                      ClipboardData(text: MyQrScreen.payloadFor(userId)),
                    );
                    MekaarSnackbar.success(
                      context,
                      'Tautan profil berhasil disalin!',
                    );
                  },
                  icon: const Icon(SolarIconsOutline.copy, size: 20),
                  label: const Text(
                    'Salin & Bagikan Tautan QR',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.pill),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Secondary Action (Telegram Style): Pindai Kode QR ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticService.trigger(MekaarHapticIntent.selection);
                    Navigator.pushNamed(context, AppRoutes.contactQrScan);
                  },
                  icon: Icon(
                    SolarIconsOutline.scanner,
                    size: 20,
                    color: MekaarColors.accentOf(context),
                  ),
                  label: Text(
                    'Pindai Kode QR Teman',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : MekaarColors.canvasTop,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.pill),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
