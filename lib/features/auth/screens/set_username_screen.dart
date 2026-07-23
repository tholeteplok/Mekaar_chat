import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../providers/auth_provider.dart';

class SetUsernameScreen extends ConsumerStatefulWidget {
  const SetUsernameScreen({super.key});

  @override
  ConsumerState<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends ConsumerState<SetUsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  Timer? _debounceTimer;
  bool _isChecking = false;
  bool? _isAvailable;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim().toLowerCase();
    _debounceTimer?.cancel();
    setState(() {
      _isAvailable = null;
      _validationError = null;
    });

    if (text.isEmpty) return;

    if (text.length < 3) {
      setState(() => _validationError = 'Minimal 3 karakter');
      return;
    }

    if (text.length > 20) {
      setState(() => _validationError = 'Maksimal 20 karakter');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(text)) {
      setState(() => _validationError = 'Hanya huruf, angka, dan garis bawah (_)');
      return;
    }

    _isChecking = true;
    setState(() {});

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final repo = ref.read(authRepositoryProvider);
        final available = await repo.isUsernameAvailable(text);
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isAvailable = available;
            if (!available) {
              _validationError = 'Username sudah digunakan orang lain';
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty || _validationError != null || _isAvailable != true) {
      return;
    }

    final success = await ref.read(authProvider.notifier).setUsername(username);
    if (success && mounted) {
      MekaarSnackbar.success(context, 'Username @$username berhasil didaftarkan!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return PopScope(
      canPop: false,
      child: MekaarScaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MekaarSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(
                  child: MikaIllustration(
                    pose: MikaPose.happy,
                    size: 110,
                  ),
                ),
                const SizedBox(height: MekaarSpacing.lg),
                Text(
                  'Buat Username Anda',
                  style: MekaarTypography.headingLG,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MekaarSpacing.xs),
                Text(
                  'Selamat datang! Pilih username unik yang akan digunakan teman untuk menemukan Anda.',
                  style: MekaarTypography.bodyMD.copyWith(
                    color: MekaarColors.textMutedOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MekaarSpacing.xl),
                TextField(
                  controller: _usernameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Username unik',
                    hintText: 'contoh: alex_id',
                    prefixText: '@',
                    suffixIcon: _isChecking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_isAvailable == true
                            ? const Icon(SolarIconsBold.checkCircle, color: MekaarColors.success)
                            : (_validationError != null
                                ? const Icon(SolarIconsBold.closeCircle, color: MekaarColors.sosCoral)
                                : null)),
                    errorText: _validationError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_isAvailable == true && _validationError == null) ...[
                  const SizedBox(height: MekaarSpacing.xs),
                  Text(
                    '✓ Username tersedia!',
                    style: TextStyle(
                      color: MekaarColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_isAvailable == true &&
                            _validationError == null &&
                            !authState.isLoading)
                        ? _handleSubmit
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MekaarColors.yellow,
                      foregroundColor: MekaarColors.textOnYellow,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: MekaarColors.textOnYellow,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Simpan & Lanjutkan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: MekaarSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
