import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_wordmark.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    bool success = false;
    if (_isLogin) {
      success = await ref.read(authProvider.notifier).login(email, password);
    } else {
      success = await ref
          .read(authProvider.notifier)
          .register(email, password, username);
    }

    if (!success && mounted) {
      TextInput.finishAutofillContext(shouldSave: false);
      final error = ref.read(authProvider).error ?? 'Terjadi kesalahan';
      MekaarSnackbar.error(context, error);
      return;
    }

    if (!mounted) return;
    TextInput.finishAutofillContext();
    final authState = ref.read(authProvider);

    // Verifikasi 2 Langkah (TOTP) jika diaktifkan.
    if (authState.profile?.twoFaEnabled == true &&
        authState.profile?.twoFaSecret != null) {
      final verified = await Navigator.pushNamed(
        context,
        AppRoutes.twoFactor,
        arguments: authState.profile!.twoFaSecret,
      );
      if (verified != true) {
        // User membatalkan/verifikasi gagal — batalkan login agar aman.
        await ref.read(authProvider.notifier).logout();
        return;
      }
    }

    if (!mounted) return;

    // Peringatan login dari device baru.
    final isNewDevice = ref.read(authProvider).newDeviceLogin;
    if (isNewDevice) {
      final device = ref.read(authProvider).profile?.lastLoginDevice ?? 'baru';
      ref.read(authProvider.notifier).clearNewDeviceFlag();
      if (mounted) {
        await MekaarDialog.show(
          context: context,
          title: 'Login Perangkat Baru',
          body:
              'Akun Anda baru saja login dari perangkat: $device. '
              'Jika bukan Anda, segera ubah password dan matikan sesi.',
          confirmLabel: 'Mengerti',
          barrierDismissible: false,
        );
      }
    }

    if (!mounted) return;
    if (authState.isPinSet) {
      Navigator.pushReplacementNamed(context, AppRoutes.pin, arguments: false);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.pin, arguments: true);
    }
  }

  Future<void> _signInWithGoogle() async {
    final success = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!success && mounted) {
      final error = ref.read(authProvider).error ?? 'Gagal masuk dengan Google';
      MekaarSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final textMuted = MekaarColors.textMutedOf(context);
    final surfaceColor = MekaarColors.surfaceOf(context);
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
              // App Brand Header with logo wordmark Mek (yellow) + aar (cyan)
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logo/app_icon.webp',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const MekaarWordmark(fontSize: 22),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                _isLogin ? 'Selamat Datang\nKembali' : 'Buat Akun\nBaru Anda',
                style: MekaarTypography.displayLG.copyWith(
                  height: 1.2,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Masukkan email atau username dan password untuk melanjutkan.'
                    : 'Mulai dengan membuat profil chat terenkripsi Anda.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _usernameController,
                          autofillHints: const [AutofillHints.newUsername],
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: surface2Color,
                            hintText: 'Username unik',
                            hintStyle: TextStyle(color: textMuted),
                            prefixIcon: Icon(
                              SolarIconsOutline.mentionSquare,
                              size: 20,
                              color: textSecondary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.blue,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Username tidak boleh kosong'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        autofillHints: _isLogin
                            ? const [AutofillHints.username]
                            : const [AutofillHints.email],
                        keyboardType: _isLogin
                            ? TextInputType.text
                            : TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: surface2Color,
                          hintText: _isLogin ? 'Email atau Username' : 'Email',
                          hintStyle: TextStyle(color: textMuted),
                          prefixIcon: Icon(
                            SolarIconsOutline.mentionSquare,
                            size: 20,
                            color: textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.blue,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Input tidak boleh kosong';
                          }
                          final input = v.trim();
                          final validEmail = RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(input);
                          if (!_isLogin) {
                            return validEmail ? null : 'Email tidak valid';
                          }
                          if (input.contains('@')) {
                            return validEmail ? null : 'Email tidak valid';
                          }
                          return input.length >= 3
                              ? null
                              : 'Username minimal 3 karakter';
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        autofillHints: [
                          _isLogin
                              ? AutofillHints.password
                              : AutofillHints.newPassword,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!authState.isLoading) _submit();
                        },
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: surface2Color,
                          hintText: 'Password',
                          hintStyle: TextStyle(color: textMuted),
                          prefixIcon: Icon(
                            SolarIconsOutline.lock,
                            size: 20,
                            color: textSecondary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? SolarIconsOutline.eyeClosed
                                  : SolarIconsOutline.eye,
                              size: 20,
                              color: textSecondary,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.blue,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Password minimal 6 karakter'
                            : null,
                      ),
                      if (_isLogin) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.forgotPassword,
                              );
                            },
                            child: const Text(
                              'Lupa Password?',
                              style: TextStyle(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Password minimal harus 6 karakter.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),
                      // Primary Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(_isLogin ? 'Masuk' : 'Daftar Sekarang'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Secondary Button: Google Sign-In
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed:
                              authState.isLoading ? null : _signInWithGoogle,
                          icon: const Icon(MekaarIcons.gMobiledata, size: 28),
                          label: const Text('Lanjut dengan Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            backgroundColor: surfaceColor,
                            side: BorderSide(
                              color: cardBorder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Footer link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'Daftar' : 'Masuk',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
