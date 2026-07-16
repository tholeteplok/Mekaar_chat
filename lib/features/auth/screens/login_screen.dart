import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
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

  Future<void> _submit() async {    if (!_formKey.currentState!.validate()) return;

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

    if (success && mounted) {
      final authState = ref.read(authProvider);
      if (authState.isPinSet) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.pin,
          arguments: false,
        );
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.pin, arguments: true);
      }
    } else if (mounted) {
      final error = ref.read(authProvider).error ?? 'Terjadi kesalahan';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: MekaarColors.sosRed),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final success = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!success && mounted) {
      final error = ref.read(authProvider).error ?? 'Gagal masuk dengan Google';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: MekaarColors.sosRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              // App Brand Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: MekaarColors.softCoral,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'MEKAAR',
                    style: MekaarTypography.monoMD.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                _isLogin ? 'Selamat Datang\nKembali' : 'Buat Akun\nBaru Anda',
                style: MekaarTypography.displayLG.copyWith(height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Masukkan email atau username dan password untuk melanjutkan.'
                    : 'Mulai dengan membuat profil chat terenkripsi Anda.',
                style: MekaarTypography.bodyMD,
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Username unik',
                          prefixIcon: Icon(Icons.alternate_email, size: 20),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Username tidak boleh kosong'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        hintText: 'Email atau Username',
                        prefixIcon: Icon(Icons.alternate_email, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Input tidak boleh kosong';
                        }
                        final input = v.trim();
                        if (input.contains('@')) {
                          return input.contains('.')
                              ? null
                              : 'Email tidak valid';
                        }
                        return input.length >= 3
                            ? null
                            : 'Username minimal 3 karakter';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: MekaarColors.textMuted,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Password minimal 6 karakter'
                          : null,
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password minimal harus 6 karakter.',
                          style: MekaarTypography.bodySM,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isLogin ? 'Masuk' : 'Daftar Sekarang'),
                      ),
                    ),
                    if (_isLogin) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: authState.isLoading
                              ? null
                              : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 24),
                          label: const Text('Lanjut dengan Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MekaarColors.textPrimary,
                            side: const BorderSide(
                                color: MekaarColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                    style: MekaarTypography.bodyMD,
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'Daftar' : 'Masuk',
                      style: MekaarTypography.labelLG.copyWith(
                        color: MekaarColors.softCoral,
                        fontWeight: FontWeight.bold,
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
