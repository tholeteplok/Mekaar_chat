import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/utils/totp.dart';

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

  void _verify() {
    final code = _codeController.text.trim();
    if (!TotpUtil.verify(widget.twoFaSecret, code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode tidak valid. Coba lagi.'),
          backgroundColor: MekaarColors.sosRed,
        ),
      );
      return;
    }
    setState(() => _isVerifying = true);
    // Berhasil — kembalikan true agar caller melanjutkan ke layar PIN.
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      forceDark: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Icon(
                SolarIconsBold.shieldKeyhole,
                color: MekaarColors.yellow,
                size: 40,
              ),
              const SizedBox(height: 24),
              Text(
                'Verifikasi 2 Langkah',
                style: MekaarTypography.displayLG.copyWith(
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan kode 6 digit dari aplikasi authenticator Anda.',
                style: TextStyle(
                  color: MekaarColors.textSecondary,
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
                  color: Colors.white,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  hintText: '••••••',
                  hintStyle: const TextStyle(
                    color: MekaarColors.textMuted,
                    letterSpacing: 10,
                  ),
                  prefixIcon: const Icon(
                    SolarIconsOutline.shieldKeyhole,
                    color: MekaarColors.textSecondary,
                  ),
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  filled: true,
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: MekaarColors.textOnYellow,
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
