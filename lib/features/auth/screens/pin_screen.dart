import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/sos_button.dart';
import '../providers/auth_provider.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;

  const PinScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _statusMessage = '';

  static const int pinLength = 6;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isSetup
        ? 'Buat PIN 6 digit untuk mengamankan aplikasi.'
        : 'Masukkan PIN 6 digit Anda untuk masuk.';
  }

  void _handleKeyPress(String key) {
    if (ref.read(authProvider).isPinLocked) return;
    HapticFeedback.lightImpact();

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
              HapticFeedback.vibrate();
              setState(() {
                _pin = '';
                _statusMessage = authState.error!;
              });
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.home);
            }
          }
        } else {
          HapticFeedback.vibrate();
          setState(() {
            _pin = '';
            _isConfirming = false;
            _statusMessage = 'PIN tidak cocok. Mulai dari awal.';
          });
        }
      }
    } else {
      // PIN validation
      final isValid = await notifier.validatePIN(_pin);
      if (isValid) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _pin = '';
          final state = ref.read(authProvider);
          if (state.isPinLocked) {
            _statusMessage = 'Aplikasi terkunci. Coba lagi dalam 30 menit.';
          } else {
            _statusMessage = 'PIN salah. ${5 - state.pinAttempts} percobaan tersisa.';
          }
        });
      }
    }
  }

  void _triggerSOS() {
    Navigator.pushNamed(context, AppRoutes.sosActive);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLocked = authState.isPinLocked;

    return Scaffold(
      backgroundColor: MekaarColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              // Title Header
              Text(
                widget.isSetup 
                    ? (_isConfirming ? 'Konfirmasi PIN' : 'Buat PIN Keamanan') 
                    : 'Buka MEKAAR',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: MekaarColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                isLocked
                    ? 'Terlalu banyak percobaan salah. Terkunci ${authState.remainingLockMinutes} menit.'
                    : _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isLocked ? MekaarColors.sosRed : MekaarColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              // Dots indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pinLength,
                  (index) => Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: MekaarColors.border, width: 2),
                      color: _pin.length > index ? MekaarColors.textPrimary : Colors.transparent,
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
                _buildKeypadRow(['', '0', '⌫']),
              ] else ...[
                const Column(
                  children: [
                    Icon(Icons.lock_clock, size: 64, color: MekaarColors.sosRed),
                    SizedBox(height: 12),
                    Text(
                      'Silakan tunggu durasi kunci berakhir.',
                      style: TextStyle(color: MekaarColors.textSecondary, fontSize: 13),
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
                      color: MekaarColors.sosRed,
                      fontSize: 11,
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

    final isBackspace = key == '⌫';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      width: 70,
      height: 70,
      child: InkWell(
        onTap: () => _handleKeyPress(key),
        borderRadius: BorderRadius.circular(35),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBackspace ? Colors.transparent : MekaarColors.surface2,
          ),
          child: Center(
            child: isBackspace
                ? const Icon(Icons.backspace_outlined, color: MekaarColors.textSecondary)
                : Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: MekaarColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
