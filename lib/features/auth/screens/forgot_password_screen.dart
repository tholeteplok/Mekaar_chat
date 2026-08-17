import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showOtpFallback = false;
  String _resolvedEmail = '';
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final input = _emailController.text.trim();
    try {
      final email =
          await ref.read(authProvider.notifier).sendPasswordReset(input) ??
              input;

      if (!mounted) return;

      HapticService.trigger(MekaarHapticIntent.success);
      _resolvedEmail = email;

      MekaarSnackbar.success(
        context,
        'Cek email Anda untuk link reset password.',
      );
    } catch (e) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal mengirim email reset: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitOtpFallback() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    final success = await ref.read(authProvider.notifier).confirmPasswordReset(
          email: _resolvedEmail.isNotEmpty
              ? _resolvedEmail
              : _emailController.text.trim(),
          token: otp,
          newPassword: newPassword,
        );

    if (!mounted) return;

    if (success) {
      HapticService.trigger(MekaarHapticIntent.success);
      MekaarSnackbar.success(
        context,
        'Password berhasil diperbarui! Silakan masuk dengan password baru.',
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } else {
      final error =
          ref.read(authProvider).error ?? 'Gagal memperbarui password';
      MekaarSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      flat: true,
      forceDark: true,
      appBar: CustomAppBar(
        title: 'Lupa Password',
        onBackPress: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Icon(
                  SolarIconsBold.lockPassword,
                  color: MekaarColors.accentOf(context),
                  size: 44,
                ),
                const SizedBox(height: 20),
                Text(
                  _showOtpFallback ? 'Reset dengan OTP' : 'Lupa Password?',
                  style: MekaarTypography.displayLG.copyWith(
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showOtpFallback
                      ? 'Masukkan kode 6-digit OTP dan password baru Anda.'
                      : 'Masukkan alamat email terdaftar Anda. Kami akan mengirimkan link pemulihan password.',
                  style: const TextStyle(
                    color: MekaarColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_showOtpFallback) ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      hintText: 'Email atau Username',
                      hintStyle: const TextStyle(
                        color: MekaarColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        SolarIconsOutline.user,
                        size: 20,
                        color: MekaarColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      final input = v?.trim() ?? '';
                      if (input.isEmpty) {
                        return 'Email atau username tidak boleh kosong';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submitRequest(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: MekaarColors.textOnYellow,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Kirim Link Reset'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showOtpFallback = true);
                      },
                      child: Text(
                        'Punya Kode OTP 6-Digit? Masukkan manual',
                        style: TextStyle(
                          color: MekaarColors.accentOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.text,
                    textAlign: TextAlign.center,
                    style: MekaarTypography.headingMD.copyWith(
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      hintText: 'Kode OTP 6-Digit',
                      hintStyle: const TextStyle(
                        color: MekaarColors.textMuted,
                        letterSpacing: 2,
                      ),
                      prefixIcon: const Icon(
                        SolarIconsOutline.shieldKeyhole,
                        size: 20,
                        color: MekaarColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      final otp = v?.trim() ?? '';
                      if (otp.isEmpty) {
                        return 'Kode OTP tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      hintText: 'Password Baru',
                      hintStyle: const TextStyle(
                        color: MekaarColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        SolarIconsOutline.lock,
                        size: 20,
                        color: MekaarColors.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? SolarIconsOutline.eyeClosed
                              : SolarIconsOutline.eye,
                          size: 20,
                          color: MekaarColors.textSecondary,
                        ),
                        onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final p = v?.trim() ?? '';
                      if (p.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      hintText: 'Konfirmasi Password Baru',
                      hintStyle: const TextStyle(
                        color: MekaarColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        SolarIconsOutline.lockPassword,
                        size: 20,
                        color: MekaarColors.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? SolarIconsOutline.eyeClosed
                              : SolarIconsOutline.eye,
                          size: 20,
                          color: MekaarColors.textSecondary,
                        ),
                        onPressed: () => setState(
                          () =>
                              _obscureConfirmPassword = !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v != _newPasswordController.text) {
                        return 'Konfirmasi password tidak cocok';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submitOtpFallback(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitOtpFallback,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: MekaarColors.textOnYellow,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Perbarui Password'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() => _showOtpFallback = false);
                      },
                      child: Text(
                        'Kembali ke Kirim Link Reset',
                        style: TextStyle(
                          color: MekaarColors.accentOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
