import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../providers/guardian_provider.dart';

// Layar "Kode QR Saya": tampilkan ke teman terpercaya agar ia bisa
// memindai dan mengirim undangan guardian tanpa mencari username.
class QrInviteScreen extends ConsumerStatefulWidget {
  const QrInviteScreen({super.key});

  static String payloadFor(String token) => 'mekaar://invite/$token';

  @override
  ConsumerState<QrInviteScreen> createState() => _QrInviteScreenState();
}

class _QrInviteScreenState extends ConsumerState<QrInviteScreen> {
  String? _token;
  bool _isLoading = true;
  bool _isRotating = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final token = await ref
          .read(guardianRepositoryProvider)
          .getMyInviteToken();
      if (mounted) setState(() => _token = token);
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal memuat kode QR');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rotateToken() async {
    setState(() => _isRotating = true);
    try {
      final token = await ref
          .read(guardianRepositoryProvider)
          .rotateInviteToken();
      if (mounted) {
        setState(() => _token = token);
        MekaarSnackbar.success(
          context,
          'Kode QR diperbarui. Kode lama tidak berlaku lagi.',
        );
      }
    } catch (_) {
      if (mounted) {
        MekaarSnackbar.error(context, 'Gagal memperbarui kode');
      }
    } finally {
      if (mounted) setState(() => _isRotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Kode QR Saya'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Tunjukkan kode ini ke teman terpercaya. Ia dapat memindainya untuk mengirim undangan menjadi Guardian Anda.',
              textAlign: TextAlign.center,
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(64.0),
                child: CircularProgressIndicator(),
              )
            else if (_token != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: MekaarColors.borderLight),
                ),
                child: QrImageView(
                  data: QrInviteScreen.payloadFor(_token!),
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(64.0),
                child: Icon(
                  SolarIconsOutline.dangerCircle,
                  size: 48,
                  color: MekaarColors.sosRed,
                ),
              ),
            const SizedBox(height: 24),
            if (_token != null)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _token!));
                  MekaarSnackbar.info(context, 'Kode disalin');
                },
                icon: const Icon(SolarIconsOutline.copy, size: 18),
                label: const Text('Salin Kode'),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: (_isLoading || _isRotating) ? null : _rotateToken,
                icon: _isRotating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(SolarIconsOutline.refresh),
                label: const Text('Perbarui Kode'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Perbarui kode jika Anda merasa kode lama pernah tersebar.',
              textAlign: TextAlign.center,
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
