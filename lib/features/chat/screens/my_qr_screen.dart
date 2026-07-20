import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../auth/providers/auth_provider.dart';

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
    final name = authState.profile?.fullName ?? authState.profile?.username ?? 'User';
    final username = authState.profile?.username ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'QR Code Profil'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Tunjukkan kode QR ini ke teman Anda agar mereka dapat langsung memindai dan memulai chat 1:1 terenkripsi end-to-end.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: MekaarColors.textSecondary),
            ),
            const SizedBox(height: 32),
            if (userId == null)
              const Padding(
                padding: EdgeInsets.all(64.0),
                child: CircularProgressIndicator(),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? MekaarColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: MyQrScreen.payloadFor(userId),
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: MekaarTypography.headingMD.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: MekaarTypography.bodyMD.copyWith(
                          color: MekaarColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Copy Code Pill Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: MyQrScreen.payloadFor(userId)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tautan profil berhasil disalin!'),
                        backgroundColor: MekaarColors.success,
                      ),
                    );
                  },
                  icon: const Icon(SolarIconsOutline.copy, size: 18),
                  label: const Text('Salin Tautan Profil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MekaarColors.softCoral,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
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
