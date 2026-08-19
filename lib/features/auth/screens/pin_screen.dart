import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/motion.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_wordmark.dart';
import '../../../core/widgets/sos_button.dart';
import '../../guardian/providers/guardian_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../../../data/services/e2ee_service.dart';
import '../providers/auth_provider.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;

  const PinScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with TickerProviderStateMixin {
  late bool _isSetupMode;
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _statusMessage = '';
  bool _hasError = false;
  bool _isCheckingSOSGuardians = false;
  bool _isBottomSheetOpen = false;
  bool _obscurePin = true;

  static const int pinLength = 6;

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _shakeAnimation = Tween<double>(
    begin: -10,
    end: 10,
  ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

  @override
  void initState() {
    super.initState();
    _isSetupMode = widget.isSetup;
    _statusMessage = _isSetupMode
        ? 'Buat PIN 6 digit untuk mengamankan aplikasi.'
        : 'Masukkan PIN 6 digit Anda untuk masuk.';

    // Buka keypad bottom sheet secara otomatis saat pertama kali masuk jika tidak terkunci
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(authProvider).isPinLocked) {
        _openKeypadBottomSheet();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shakeController.stop();
      _shakeController.value = 0;
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleKeyPress(String key) {
    if (ref.read(authProvider).isPinLocked) return;
    setState(() => _hasError = false);
    HapticService.trigger(MekaarHapticIntent.selection);

    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }

    if (_pin.length < pinLength) {
      setState(() => _pin += key);

      if (_pin.length == pinLength) {
        _processPIN();
      }
    }
  }

  Future<void> _processPIN() async {
    final notifier = ref.read(authProvider.notifier);

    if (_isSetupMode) {
      if (!_isConfirming) {
        // Step 1: Simpan PIN pertama, minta konfirmasi
        _confirmPin = _pin;
        setState(() {
          _pin = '';
          _isConfirming = true;
          _statusMessage = 'Konfirmasi PIN 6 digit Anda.';
        });
      } else {
        // Step 2: Konfirmasi PIN
        if (_pin == _confirmPin) {
          await notifier.setupPIN(_pin);
          if (mounted) {
            final authState = ref.read(authProvider);
            if (authState.error != null) {
              HapticService.trigger(MekaarHapticIntent.destructive);
              setState(() {
                _pin = '';
                _hasError = true;
                _statusMessage = authState.error!;
              });
            } else {
              HapticService.trigger(MekaarHapticIntent.success);
              if (_isBottomSheetOpen && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              if (authState.needsUsername) {
                Navigator.pushReplacementNamed(context, AppRoutes.setUsername);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              }
            }
          }
        } else {
          HapticService.trigger(MekaarHapticIntent.destructive);
          if (!MediaQuery.disableAnimationsOf(context)) {
            _shakeController.forward(from: 0);
          }
          setState(() {
            _pin = '';
            _hasError = true;
            _isConfirming = false;
            _statusMessage = 'PIN tidak cocok. Mulai dari awal.';
          });
        }
      }
    } else {
      // PIN validation
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      final isValid = await notifier.validatePIN(_pin);
      if (isValid) {
        if (mounted) {
          HapticService.trigger(MekaarHapticIntent.success);
          if (_isBottomSheetOpen && Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          final authState = ref.read(authProvider);
          final wasDuress = authState.lastUnlockWasDuress;

          if (authState.e2eeNeedsRestore && !wasDuress) {
            await _showE2eeRestoreDialog();
          }

          if (!mounted) return;

          if (wasDuress) {
            ref
                .read(sosProvider.notifier)
                .activateSOS(gps: true, mic: false, video: false);
            if (authState.needsUsername) {
              Navigator.pushReplacementNamed(context, AppRoutes.setUsername);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.home);
            }
          } else {
            if (authState.needsUsername) {
              Navigator.pushReplacementNamed(context, AppRoutes.setUsername);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.home);
            }
          }
        }
      } else {
        HapticService.trigger(MekaarHapticIntent.destructive);
        if (!disableAnimations) {
          _shakeController.forward(from: 0);
        }
        setState(() {
          _pin = '';
          _hasError = true;
          final state = ref.read(authProvider);
          if (state.isPinLocked) {
            _statusMessage = 'Aplikasi terkunci. Coba lagi dalam 30 menit.';
            if (_isBottomSheetOpen && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          } else {
            _statusMessage =
                'PIN salah. ${5 - state.pinAttempts} percobaan tersisa.';
          }
        });
      }
    }
  }

  Future<void> _triggerSOS() async {
    if (_isCheckingSOSGuardians) return;
    _isCheckingSOSGuardians = true;

    try {
      var loadStatus = ref.read(guardianLoadStatusProvider);
      if (loadStatus != GuardianLoadStatus.data) {
        await ref.read(guardianProvider.notifier).refreshGuardians();
        loadStatus = ref.read(guardianLoadStatusProvider);
      }
      if (!mounted) return;

      if (loadStatus == GuardianLoadStatus.data &&
          activeGuardiansOf(ref.read(guardianProvider)).isEmpty) {
        final shouldContinue = await MekaarDialog.showNoActiveGuardianWarning(
          context: context,
        );
        if (!mounted || !shouldContinue) return;
      }

      Navigator.pushNamed(context, AppRoutes.sosActive);
    } finally {
      _isCheckingSOSGuardians = false;
    }
  }

  void _openKeypadBottomSheet() {
    if (_isBottomSheetOpen) return;
    final isLocked = ref.read(authProvider).isPinLocked;
    if (isLocked) return;

    _isBottomSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final sheetBg = MekaarColors.surfaceOf(context);
            final sheetBorder = MekaarColors.cardBorderOf(context);
            final textPrimary = MekaarColors.textPrimaryOf(context);
            final textSecondary = MekaarColors.textSecondaryOf(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              padding: const EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: sheetBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle Bar
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: textSecondary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Header sheet
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              SolarIconsBold.shieldKeyhole,
                              size: 18,
                              color: AppColors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Papan Tombol Keamanan',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            SolarIconsOutline.altArrowDown,
                            color: textSecondary,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Tutup Papan Tombol',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Keypad Rows
                    _buildKeypadRow(['1', '2', '3']),
                    _buildKeypadRow(['4', '5', '6']),
                    _buildKeypadRow(['7', '8', '9']),
                    _buildKeypadRow([_isSetupMode ? '' : 'Lupa', '0', '⌫']),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isBottomSheetOpen = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLocked = authState.isPinLocked;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final surfaceColor = MekaarColors.surfaceOf(context);
    final cardBorder = MekaarColors.cardBorderOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Wordmark resmi sebagai jangkar identitas layar autentikasi
              const Center(
                child: MekaarWordmark(fontSize: 40),
              ),
              const Spacer(flex: 2),

              // Emblem Keamanan Layered Halo
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.blue.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsBold.shieldKeyhole,
                      color: AppColors.blue,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title instruksi PIN
              Center(
                child: Text(
                  widget.isSetup
                      ? (_isConfirming ? 'Konfirmasi PIN' : 'Buat PIN Keamanan')
                      : 'Buka Kunci Aplikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Status message / Lockout message
              Center(
                child: Semantics(
                  liveRegion: isLocked || _hasError,
                  child: AnimatedSwitcher(
                    duration: animationsDisabled
                        ? Duration.zero
                        : MekaarMotion.fast,
                    child: Text(
                      isLocked
                          ? 'Terlalu banyak percobaan salah. Terkunci ${authState.remainingLockMinutes} menit.'
                          : _statusMessage,
                      key: ValueKey(_statusMessage),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: (isLocked || _hasError)
                            ? MekaarColors.sosCoral
                            : textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 6 Lingkaran PIN Interaktif dengan Typing Behavior & Card
              Semantics(
                label: 'PIN',
                value: '${_pin.length} dari $pinLength digit terisi',
                child: InkWell(
                  onTap: isLocked ? null : _openKeypadBottomSheet,
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        animationsDisabled ? 0 : _shakeAnimation.value,
                        0,
                      ),
                      child: child,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _hasError
                              ? MekaarColors.sosCoral
                              : (_pin.isNotEmpty
                                  ? AppColors.blue.withValues(alpha: 0.5)
                                  : cardBorder),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.04,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // PIN Dots / Number Slots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              pinLength,
                              (index) => _buildPinCircle(index, animationsDisabled),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Card Footer: Keyboard Hint & Eye Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    SolarIconsOutline.keyboard,
                                    size: 16,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ketuk untuk buka papan tombol',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              // Eye icon toggle for Show/Hide digits
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: Icon(
                                  _obscurePin
                                      ? SolarIconsOutline.eyeClosed
                                      : SolarIconsOutline.eye,
                                  size: 19,
                                  color: textSecondary,
                                ),
                                tooltip: _obscurePin
                                    ? 'Tampilkan angka PIN'
                                    : 'Sembunyikan angka PIN',
                                onPressed: () {
                                  setState(() => _obscurePin = !_obscurePin);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Lupa PIN (Hanya tampil di mode unlock)
              if (!_isSetupMode && !isLocked)
                Center(
                  child: TextButton(
                    onPressed: _showForgotPinDialog,
                    child: const Text(
                      'Lupa PIN?',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              const Spacer(flex: 3),

              // Tombol SOS Darurat di bagian bawah
              Center(
                child: Column(
                  children: [
                    SOSButton(onPressed: _triggerSOS, size: 76),
                    const SizedBox(height: 10),
                    const Text(
                      'Pencet SOS untuk keadaan darurat',
                      style: TextStyle(
                        color: MekaarColors.sosCoral,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinCircle(int index, bool animationsDisabled) {
    final isFilled = _pin.length > index;
    final isCurrent = _pin.length == index;
    final cardBorder = MekaarColors.cardBorderOf(context);
    final surface2 = MekaarColors.surface2Of(context);
    final textPrimary = MekaarColors.textPrimaryOf(context);

    Color borderColor;
    if (_hasError) {
      borderColor = MekaarColors.sosCoral;
    } else if (isFilled) {
      borderColor = AppColors.blue;
    } else if (isCurrent) {
      borderColor = AppColors.blue.withValues(alpha: 0.6);
    } else {
      borderColor = cardBorder;
    }

    return AnimatedContainer(
      duration: animationsDisabled ? Duration.zero : MekaarMotion.fast,
      curve: MekaarMotion.bounce,
      width: 26,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isCurrent || isFilled ? 2.5 : 1.5,
        ),
        color: isFilled
            ? (_obscurePin
                ? (_hasError ? MekaarColors.sosCoral : AppColors.blue)
                : surface2)
            : (isCurrent
                ? AppColors.blue.withValues(alpha: 0.18)
                : surface2),
        boxShadow: (isFilled && _obscurePin)
            ? [
                BoxShadow(
                  color: (_hasError ? MekaarColors.sosCoral : AppColors.blue)
                      .withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isFilled && !_obscurePin
            ? Text(
                _pin[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _hasError ? MekaarColors.sosCoral : textPrimary,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKeypadButton(key)).toList(),
    );
  }

  Widget _buildKeypadButton(String key) {
    final textPrimary = MekaarColors.textPrimaryOf(context);
    final textSecondary = MekaarColors.textSecondaryOf(context);
    final surface2 = MekaarColors.surface2Of(context);
    final cardBorder = MekaarColors.cardBorderOf(context);

    if (key.isEmpty) {
      return const SizedBox(width: 76, height: 66);
    }

    if (key == 'Lupa') {
      return SizedBox(
        width: 76,
        height: 66,
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showForgotPinDialog();
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 60),
            ),
            child: Text(
              'Lupa\nPIN?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ),
      );
    }

    final isBackspace = key == '⌫';

    return Semantics(
      button: true,
      label: isBackspace ? 'Hapus digit terakhir' : 'Angka $key',
      onTap: () => _handleKeyPress(key),
      child: ExcludeSemantics(
        child: PressableScale(
          scale: 0.92,
          onTap: () => _handleKeyPress(key),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBackspace ? Colors.transparent : surface2,
              border: Border.all(
                color: isBackspace ? Colors.transparent : cardBorder,
                width: 1,
              ),
            ),
            child: Center(
              child: isBackspace
                  ? Icon(
                      SolarIconsOutline.backspace,
                      color: textPrimary,
                      size: 24,
                    )
                  : Text(
                      key,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPinDialog() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final provider = user?.appMetadata['provider'] as String? ?? 'email';
    final isGoogleUser = provider == 'google';
    final isEmailPasswordUser = !isGoogleUser;

    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    final shouldReset = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: MekaarColors.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(SolarIconsOutline.lockUnlocked, color: MekaarColors.sosRed),
              SizedBox(width: 8),
              Text('Reset PIN & Keamanan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGoogleUser
                    ? 'Apakah Anda ingin mereset PIN? Karena Anda masuk dengan Google, Anda akan diminta untuk melakukan login Google kembali untuk mengonfirmasi identitas Anda.\n\n'
                      '⚠️ Kunci E2EE lama akan diganti dengan kunci baru yang terbungkus (wrapped) dengan PIN baru Anda. Pesan lama yang terenkripsi akan dibersihkan.'
                    : 'Apakah Anda ingin mereset PIN? Anda dapat membuat PIN baru setelah verifikasi password akun.\n\n'
                      '⚠️ Kunci E2EE lama akan diganti dengan kunci baru yang terbungkus (wrapped) dengan PIN baru Anda. Pesan lama yang terenkripsi akan dibersihkan.',
                style: const TextStyle(fontSize: 13),
              ),
              if (isEmailPasswordUser) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi Password Akun',
                    errorText: errorMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MekaarColors.sosRed,
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final pwd = passwordController.text.trim();
                      if (isEmailPasswordUser && pwd.isEmpty) {
                        setDialogState(() => errorMessage = 'Masukkan password akun');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      final success = await ref
                          .read(authProvider.notifier)
                          .resetPinWithVerification(
                            password: isEmailPasswordUser ? pwd : null,
                            isGoogleUser: isGoogleUser,
                          );

                      setDialogState(() => isLoading = false);

                      if (success && ctx.mounted) {
                        Navigator.pop(ctx, true);
                      } else {
                        final err = ref.read(authProvider).error;
                        setDialogState(() => errorMessage = err ?? 'Verifikasi gagal');
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reset PIN & Buat Baru'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();

    if (shouldReset == true && mounted) {
      setState(() {
        _isSetupMode = true;
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
        _hasError = false;
        _statusMessage = 'Buat PIN 6 digit baru untuk mengamankan aplikasi.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN lama berhasil direset. Silakan buat PIN 6 digit baru.'),
          backgroundColor: MekaarColors.accentOf(context),
        ),
      );
    }
  }

  /// Dialog yang muncul setelah PIN valid tapi E2EE perlu restore.
  /// Menawarkan: input PIN lama untuk restore, atau reset E2EE secara sadar.
  Future<void> _showE2eeRestoreDialog() async {
    final pinController = TextEditingController();
    bool isLoading = false;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: MekaarColors.surfaceOf(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(SolarIconsOutline.shieldKeyhole, color: MekaarColors.warnAmber),
              SizedBox(width: 8),
              Expanded(
                child: Text('Pemulihan Kunci E2EE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perangkat ini belum memiliki kunci enkripsi. '
                'Masukkan PIN lama Anda untuk memulihkan riwayat chat, '
                'atau reset untuk memulai dengan kunci baru.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN Lama (6 digit)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Reset E2EE secara sadar
                      final confirmReset = await MekaarDialog.showConfirmation<bool>(
                        context: ctx,
                        title: 'Reset Kunci E2EE?',
                        message:
                            'Riwayat obrolan lama yang terenkripsi TIDAK akan '
                            'bisa dibaca lagi selamanya. Hanya pesan baru yang '
                            'akan terenkripsi dengan kunci baru.\n\n'
                            'Tindakan ini tidak dapat dibatalkan.',
                        isDestructive: true,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: MekaarColors.sosRed,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Reset E2EE'),
                          ),
                        ],
                      );
                      if (confirmReset == true && ctx.mounted) {
                        Navigator.pop(ctx, 'reset');
                      }
                    },
              child: const Text('Reset E2EE',
                  style: TextStyle(color: MekaarColors.sosRed)),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final oldPin = pinController.text.trim();
                      if (oldPin.length != 6) return;

                      setDialogState(() => isLoading = true);
                      final success =
                          await E2eeService.instance.tryRestoreWithPin(oldPin);
                      setDialogState(() => isLoading = false);

                      if (success) {
                        // Backup ulang dengan PIN baru yang aktif (_pin)
                        try {
                          await E2eeService.instance.backupWithPin(_pin);
                        } catch (_) {}
                        if (ctx.mounted) Navigator.pop(ctx, 'restored');
                      } else {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('PIN lama salah. Coba lagi.'),
                              backgroundColor: MekaarColors.sosRed,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pulihkan'),
            ),
          ],
        ),
      ),
    );

    pinController.dispose();

    if (result == 'reset' && mounted) {
      await E2eeService.instance.forceResetIdentity();
      ref.read(authProvider.notifier).setE2eeNeedsRestore(false);
    } else if (result == 'restored' && mounted) {
      ref.read(authProvider.notifier).setE2eeNeedsRestore(false);
    }
  }
}
