import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../core/utils/totp.dart';
import '../providers/two_fa_provider.dart';
import '../../auth/providers/auth_provider.dart';

import '../widgets/settings_tiles.dart';

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
      flat: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsTopBar(title: 'Verifikasi 2 Langkah'),
            Expanded(
              child: _isEnabled
                  ? _buildEnabledView()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amankan akun dengan kode dari aplikasi authenticator.',
                            style: MekaarTypography.bodyMD.copyWith(
                              color: MekaarColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: MekaarColors.surface2Of(context),
                              borderRadius:
                                  BorderRadius.circular(MekaarRadius.sm),
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
                                  style: MekaarTypography.monoMD.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        MekaarColors.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  uri,
                                  style: MekaarTypography.bodySM.copyWith(
                                    color: MekaarColors.textMutedOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Masukkan kode 6 digit dari authenticator untuk konfirmasi:',
                            style: MekaarTypography.labelLG,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: MekaarTypography.monoLG.copyWith(fontSize: 24),
                            decoration: const InputDecoration(
                              hintText: '••••••',
                              counterText: '',
                              prefixIcon: Icon(SolarIconsOutline.shieldKeyhole),
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
