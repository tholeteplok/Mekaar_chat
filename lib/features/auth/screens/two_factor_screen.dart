import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/utils/totp.dart';
import '../providers/auth_provider.dart';

class TwoFactorScreen extends ConsumerStatefulWidget {
  final String twoFaSecret;

  const TwoFactorScreen({super.key, required this.twoFaSecret});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verify() async {
    final code = _codeController.text.trim();
    if (!TotpUtil.verify(widget.twoFaSecret, code)) {
      MekaarSnackbar.error(context, 'Kode tidak valid. Coba lagi.');
      return;
    }
    setState(() => _isVerifying = true);
    await ref.read(authRepositoryProvider).save2faVerified(true);
    if (!mounted) return;
    // Berhasil — kembalikan true agar caller melanjutkan ke layar PIN.
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final textMuted = MekaarColors.textMutedOf(context);
    final surface2Color = MekaarColors.surface2Of(context);
    final cardBorder = MekaarColors.cardBorderOf(context);

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Icon(
                SolarIconsBold.shieldKeyhole,
                color: AppColors.blue,
                size: 40,
              ),
              const SizedBox(height: 24),
              Text(
                'Verifikasi 2 Langkah',
                style: MekaarTypography.displayLG.copyWith(
                  color: textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan kode 6 digit dari aplikasi authenticator Anda.',
                style: TextStyle(
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
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
                autofocus: true,
                textAlign: TextAlign.center,
                style: MekaarTypography.headingMD.copyWith(
                  color: textPrimary,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surface2Color,
                  hintText: '••••••',
                  hintStyle: TextStyle(
                    color: textMuted,
                    letterSpacing: 10,
                  ),
                  prefixIcon: Icon(
                    SolarIconsOutline.shieldKeyhole,
                    color: textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    borderSide: const BorderSide(
                      color: AppColors.blue,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MekaarRadius.sm),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Verifikasi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
