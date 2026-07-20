import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/utils/totp.dart';
import '../providers/two_fa_provider.dart';
import '../../auth/providers/auth_provider.dart';

class TwoFactorSetupScreen extends ConsumerStatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  ConsumerState<TwoFactorSetupScreen> createState() =>
      _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends ConsumerState<TwoFactorSetupScreen> {
  late final String _secret;
  final _codeController = TextEditingController();
  bool _isSaving = false;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _secret = TotpUtil.generateSecret();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (!TotpUtil.verify(_secret, code)) {
      MekaarSnackbar.error(
        context,
        'Kode tidak valid. Pastikan jam perangkat sudah benar.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(twoFaProvider.notifier).enable(_secret);
      if (mounted) {
        setState(() => _isEnabled = true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        MekaarSnackbar.error(
          context,
          'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account =
        ref.read(authProvider).profile?.email ?? 'pengguna@mekaar.id';
    final uri = TotpUtil.otpAuthUri(account, _secret);

    return MekaarScaffold(
      appBar: const CustomAppBar(title: 'Verifikasi 2 Langkah'),
      body: _isEnabled
          ? _buildEnabledView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amankan akun dengan kode dari aplikasi authenticator.',
                    style: MekaarTypography.bodyMD,
                  ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? MekaarColors.cardDark
                    : MekaarColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunci Rahasia (masukkan manual):',
                    style: MekaarTypography.labelLG,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _secret,
                    style: MekaarTypography.bodyMD.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: MekaarColors.softCoral,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    uri,
                    style: MekaarTypography.bodySM.copyWith(
                      color: MekaarColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Masukkan kode 6 digit dari authenticator untuk konfirmasi:',
              style: MekaarTypography.bodySM,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              maxLength: 6,
              textAlign: TextAlign.center,
              style: MekaarTypography.headingMD.copyWith(letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                prefixIcon: const Icon(SolarIconsOutline.shieldKeyhole),
              ),
              onSubmitted: (_) {
                if (!_isSaving) _confirm();
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _confirm,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aktifkan 2 Langkah'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnabledView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MikaIllustration(
              pose: MikaPose.shield,
              size: 150,
              semanticLabel: 'Verifikasi 2 Langkah aktif',
            ),
            const SizedBox(height: MekaarSpacing.lg),
            Text(
              'Verifikasi 2 Langkah aktif!',
              style: MekaarTypography.headingMD,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MekaarSpacing.sm),
            Text(
              'Akun Anda kini lebih aman. Kode dari authenticator akan '
              'diminta setiap kali login.',
              style: MekaarTypography.bodyMD,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MekaarSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Selesai'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
