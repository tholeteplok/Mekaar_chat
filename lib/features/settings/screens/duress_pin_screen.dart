import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/icons.dart';
import '../../../core/constants/typography.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mekaar_state_view.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../widgets/settings_tiles.dart';
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
    HapticService.trigger(MekaarHapticIntent.selection);
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
      HapticService.trigger(MekaarHapticIntent.destructive);
      setState(() {
        _pin = '';
        _isConfirming = false;
        _status = 'PIN tidak cocok. Mulai dari awal.';
      });
      return;
    }

    // High 18 / Med 5: Pastikan Duress PIN tidak sama dengan PIN utama
    final isSameAsPrimary = await ref.read(authProvider.notifier).validatePIN(_pin);
    if (isSameAsPrimary) {
      HapticService.trigger(MekaarHapticIntent.destructive);
      setState(() {
        _pin = '';
        _isConfirming = false;
        _status = 'PIN Paksaan tidak boleh sama dengan PIN utama.';
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
      MekaarSnackbar.success(context, 'PIN Paksaan berhasil diatur.');
    }
  }

  Future<void> _disable() async {
    // Re-authentication prior to disabling Duress PIN
    final reauthed = await Navigator.pushNamed(
      context,
      AppRoutes.pin,
      arguments: {'mode': 'verify'},
    );
    if (reauthed == true) {
      await ref.read(authProvider.notifier).disableDuressPIN();
      if (mounted) {
        setState(() {
          _enabled = false;
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _status = 'PIN Paksaan dinonaktifkan.';
        });
        MekaarSnackbar.success(context, 'PIN Paksaan dinonaktifkan.');
      }
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
          color: back ? Colors.transparent : MekaarColors.surface2Of(context),
        ),
        child: Center(
          child: back
              ? Icon(
                  SolarIconsOutline.backspace,
                  color: Theme.of(context).colorScheme.onSurface,
                )
              : Text(
                  k,
                  style: MekaarTypography.monoMD.copyWith(
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          children: [
            const SettingsTopBar(title: 'PIN Paksaan (Duress)'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MekaarColors.sosRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Jika Anda dipaksa memasukkan PIN, gunakan PIN Paksaan ini. '
                      'Aplikasi akan terbuka seperti biasa, namun diam-diam memicu SOS ke Guardian.',
                      style: MekaarTypography.bodySM.copyWith(
                        color: MekaarColors.sosRed,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: MekaarTypography.labelLG.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
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
                    border: Border.all(color: MekaarColors.borderOf(context), width: 2),
                    color: _pin.length > i ? MekaarColors.textPrimaryOf(context) : Colors.transparent,
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (_isSetting)
              const MekaarStateView(
                pose: MikaPose.pin,
                title: 'Mengatur PIN Paksaan',
                message: 'Tunggu sebentar, kami mengamankan akun Anda.',
                illustrationSize: 96,
                semanticLabel: 'Mengatur PIN Paksaan',
              )
            else if (_enabled) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _disable,
                icon: const Icon(MekaarIcons.delete),
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
