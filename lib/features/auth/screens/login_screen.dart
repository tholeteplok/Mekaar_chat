import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
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

    return MekaarScaffold(
      forceDark: true, // Login page is always dark navy gradient
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
                      color: MekaarColors.yellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: MekaarColors.yellow.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: MekaarColors.textOnYellow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Mek',
                          style: TextStyle(color: MekaarColors.yellow),
                        ),
                        TextSpan(
                          text: 'aar',
                          style: TextStyle(color: MekaarColors.cyan),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                _isLogin ? 'Selamat Datang\nKembali' : 'Buat Akun\nBaru Anda',
                style: MekaarTypography.displayLG.copyWith(
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Masukkan email atau username dan password untuk melanjutkan.'
                    : 'Mulai dengan membuat profil chat terenkripsi Anda.',
                style: const TextStyle(
                  color: MekaarColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Username unik',
                          hintStyle: TextStyle(color: MekaarColors.textMuted),
                          prefixIcon: Icon(Icons.alternate_email, size: 20, color: MekaarColors.textSecondary),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Email atau Username',
                        hintStyle: TextStyle(color: MekaarColors.textMuted),
                        prefixIcon: Icon(Icons.alternate_email, size: 20, color: MekaarColors.textSecondary),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: MekaarColors.textMuted),
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: MekaarColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: MekaarColors.textSecondary,
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
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password minimal harus 6 karakter.',
                          style: TextStyle(
                            color: MekaarColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    // Primary Button: Yellow background, dark text
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _submit,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: MekaarColors.textOnYellow,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(_isLogin ? 'Masuk' : 'Daftar Sekarang'),
                      ),
                    ),
                    if (_isLogin) ...[
                      const SizedBox(height: 16),
                      // Secondary Button: outline brand.cyan, cyan text, pill shape
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: authState.isLoading
                              ? null
                              : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Lanjut dengan Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MekaarColors.cyan,
                            side: const BorderSide(color: MekaarColors.cyan, width: 2),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Footer link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                    style: const TextStyle(color: MekaarColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? 'Daftar' : 'Masuk',
                      style: const TextStyle(
                        color: MekaarColors.yellow,
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
