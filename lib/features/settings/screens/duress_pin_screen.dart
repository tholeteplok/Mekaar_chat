import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../auth/providers/auth_provider.dart';

class DuressPinScreen extends ConsumerStatefulWidget {
  const DuressPinScreen({super.key});

  @override
  ConsumerState<DuressPinScreen> createState() => _DuressPinScreenState();
}

class _DuressPinScreenState extends ConsumerState<DuressPinScreen> {
  bool _enabled = false;
  bool _isSetting = false;
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _status = 'Masukkan PIN Paksaan 6 digit.';

  static const int _len = 6;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final enabled = await ref.read(authProvider.notifier).isDuressEnabled();
      if (mounted) setState(() => _enabled = enabled);
    });
  }

  void _onKey(String key) {
    HapticFeedback.lightImpact();
    if (key == '⌫') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length < _len) {
      setState(() => _pin += key);
      if (_pin.length == _len) _submit();
    }
  }

  Future<void> _submit() async {
    if (!_isConfirming) {
      _confirmPin = _pin;
      setState(() {
        _pin = '';
        _isConfirming = true;
        _status = 'Konfirmasi PIN Paksaan 6 digit.';
      });
      return;
    }
    if (_pin != _confirmPin) {
      HapticFeedback.vibrate();
      setState(() {
        _pin = '';
        _isConfirming = false;
        _status = 'PIN tidak cocok. Mulai dari awal.';
      });
      return;
    }
    setState(() => _isSetting = true);
    await ref.read(authProvider.notifier).setupDuressPIN(_pin);
    if (mounted) {
      setState(() {
        _isSetting = false;
        _enabled = true;
        _pin = '';
        _isConfirming = false;
        _status = 'PIN Paksaan aktif. Saat dimasukkan, aplikasi terbuka normal namun diam-diam memicu SOS.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN Paksaan berhasil diatur.')),
      );
    }
  }

  Future<void> _disable() async {
    await ref.read(authProvider.notifier).disableDuressPIN();
    if (mounted) {
      setState(() => _enabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN Paksaan dinonaktifkan.')),
      );
    }
  }

  Widget _keypadRow(List<String> keys) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((k) => _key(k)).toList(),
      );

  Widget _key(String k) {
    if (k.isEmpty) return const SizedBox(width: 80, height: 64);
    final back = k == '⌫';
    return GestureDetector(
      onTap: () => _onKey(k),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: back ? Colors.transparent : MekaarColors.surface2,
        ),
        child: Center(
          child: back
              ? const Icon(Icons.backspace_outlined, color: MekaarColors.textSecondary)
              : Text(k,
                  style: MekaarTypography.monoMD
                      .copyWith(fontSize: 22, color: MekaarColors.textPrimary)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MekaarColors.background,
      appBar: const CustomAppBar(title: 'PIN Paksaan'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MekaarColors.sosLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Jika Anda dipaksa memasukkan PIN, gunakan PIN Paksaan ini. '
                'Aplikasi akan terbuka seperti biasa, namun diam-diam memicu SOS ke Guardian.',
                style: TextStyle(fontSize: 12, color: MekaarColors.sosRed),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(_status,
                textAlign: TextAlign.center,
                style: MekaarTypography.labelLG
                    .copyWith(color: MekaarColors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _len,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: MekaarColors.border, width: 2),
                    color: _pin.length > i ? MekaarColors.textPrimary : Colors.transparent,
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (_isSetting)
              const CircularProgressIndicator()
            else if (_enabled) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _disable,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Nonaktifkan PIN Paksaan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MekaarColors.sosRed,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!_enabled) ...[
              _keypadRow(['1', '2', '3']),
              _keypadRow(['4', '5', '6']),
              _keypadRow(['7', '8', '9']),
              _keypadRow(['', '0', '⌫']),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
