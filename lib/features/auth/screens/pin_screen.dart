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
import '../providers/auth_provider.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;

  const PinScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _statusMessage = '';
  bool _hasError = false;
  bool _isCheckingSOSGuardians = false;

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
    _statusMessage = widget.isSetup
        ? 'Buat PIN 6 digit untuk mengamankan aplikasi.'
        : 'Masukkan PIN 6 digit Anda untuk masuk.';
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
    setState(() => _hasError = false); // Reset error state on new key press
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

    if (widget.isSetup) {
      if (!_isConfirming) {
        // First step of PIN setup
        _confirmPin = _pin;
        setState(() {
          _pin = '';
          _isConfirming = true;
          _statusMessage = 'Konfirmasi PIN 6 digit Anda.';
        });
      } else {
        // Second step of PIN setup (confirmation)
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
              Navigator.pushReplacementNamed(context, AppRoutes.home);
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
          final wasDuress = ref.read(authProvider).lastUnlockWasDuress;
          if (wasDuress) {
            // Duress PIN: buka normal (tanpa indikasi) lalu picu SOS silent.
            // Tidak ada toast/banner agar pelaku tidak curiga (blind spot #1).
            ref
                .read(sosProvider.notifier)
                .activateSOS(gps: true, mic: false, video: false);
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLocked = authState.isPinLocked;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return MekaarScaffold(
      forceDark: true, // PIN Screen is always dark navy gradient background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              // Wordmark resmi sebagai jangkar identitas layar autentikasi.
              const MekaarWordmark(fontSize: 30),
              const SizedBox(height: 20),
              // Title instruksi PIN.
              Text(
                widget.isSetup
                    ? (_isConfirming ? 'Konfirmasi PIN' : 'Buat PIN Keamanan')
                    : 'Buka Kunci Aplikasi',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: (isLocked || _hasError)
                          ? MekaarColors.sosCoral
                          : MekaarColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Dots indicators (shake saat salah, pop saat terisi)
              Semantics(
                label: 'PIN',
                value: '${_pin.length} dari $pinLength digit terisi',
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        animationsDisabled ? 0 : _shakeAnimation.value,
                        0,
                      ),
                      child: child,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pinLength,
                        (index) => AnimatedContainer(
                          duration: animationsDisabled
                              ? Duration.zero
                              : MekaarMotion.fast,
                          curve: MekaarMotion.bounce,
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _hasError
                                  ? MekaarColors.sosCoral
                                  : (_pin.length > index
                                        ? MekaarColors.yellow
                                        : Colors.white38),
                              width: 2,
                            ),
                            color: _pin.length > index
                                ? (_hasError
                                      ? MekaarColors.sosCoral
                                      : MekaarColors.yellow)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Custom Numeric Keypad
              if (!isLocked) ...[
                _buildKeypadRow(['1', '2', '3']),
                _buildKeypadRow(['4', '5', '6']),
                _buildKeypadRow(['7', '8', '9']),
                _buildKeypadRow([widget.isSetup ? '' : 'Lupa', '0', '⌫']),
              ] else ...[
                const Column(
                  children: [
                    Icon(
                      SolarIconsOutline.clockSquare,
                      size: 64,
                      color: MekaarColors.sosCoral,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Silakan tunggu durasi kunci berakhir.',
                      style: TextStyle(
                        color: MekaarColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              // SOS Button is always accessible at the bottom, even when locked
              Column(
                children: [
                  SOSButton(onPressed: _triggerSOS, size: 84),
                  const SizedBox(height: 12),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
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
    if (key.isEmpty) {
      return const SizedBox(width: 80, height: 70);
    }

    if (key == 'Lupa') {
      return SizedBox(
        width: 80,
        height: 70,
        child: Center(
          child: TextButton(
            onPressed: _showForgotPinDialog,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 60),
            ),
            child: const Text(
              'Lupa\nPIN?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
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
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBackspace ? Colors.transparent : MekaarColors.cardDark,
            ),
            child: Center(
              child: isBackspace
                  ? const Icon(
                      SolarIconsOutline.backspace,
                      color: Colors.white70,
                    )
                  : Text(
                      key,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPinDialog() async {
    final confirm = await MekaarDialog.showConfirmation<bool>(
      context: context,
      title: 'Lupa PIN?',
      message: 'Sesi Anda saat ini akan diakhiri. Anda harus masuk kembali menggunakan Email & Password akun Anda untuk membuat PIN baru.\n\nLanjutkan?',
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ya, Logout'),
        ),
      ],
    );

    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }
}
