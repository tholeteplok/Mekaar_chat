import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/motion.dart';
import '../constants/typography.dart';
import '../routes/app_routes.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';
import '../../data/services/database_key_service.dart';
import '../../data/services/local_vault_database.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Sheet verifikasi PIN 6-digit terpusat untuk mengamankan akses fitur sensitif
/// seperti Brankas Berkas dan Arsip Percakapan.
class MekaarPinVerificationSheet extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;

  const MekaarPinVerificationSheet({
    super.key,
    required this.title,
    required this.subtitle,
  });

  /// Menampilkan sheet verifikasi PIN modal.
  /// Mengembalikan `true` jika PIN terverifikasi dengan benar, atau `false`/`null` jika dibatalkan.
  static Future<bool> verify(
    BuildContext context, {
    String title = 'Verifikasi PIN Keamanan',
    String subtitle = 'Masukkan 6 digit PIN untuk melanjutkan',
  }) async {
    final result = await MekaarBottomSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MekaarPinVerificationSheet(
        title: title,
        subtitle: subtitle,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<MekaarPinVerificationSheet> createState() =>
      _MekaarPinVerificationSheetState();
}

class _MekaarPinVerificationSheetState
    extends ConsumerState<MekaarPinVerificationSheet>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  static const int _pinLength = 6;
  bool _isVerifying = false;
  String? _errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: MekaarMotion.slow,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween:
            Tween(begin: 0.0, end: -10.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: -10.0, end: 10.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 10.0, end: -6.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: -6.0, end: 6.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleKey(String key) {
    if (_isVerifying) return;
    HapticService.trigger(MekaarHapticIntent.selection);

    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _errorMessage = null;
        });
      }
      return;
    }

    if (_pin.length < _pinLength) {
      setState(() {
        _pin += key;
        _errorMessage = null;
      });
      if (_pin.length == _pinLength) {
        _submitPin();
      }
    }
  }

  Future<void> _submitPin() async {
    setState(() => _isVerifying = true);

    try {
      final isValid =
          await ref.read(authProvider.notifier).validatePIN(_pin);

      if (!mounted) return;

      if (isValid) {
        final wasDuress = ref.read(authProvider).lastUnlockWasDuress;
        try {
          final vaultKey = await DatabaseKeyService.instance.deriveVaultKey(
            _pin,
            isDuress: wasDuress,
          );
          DatabaseKeyService.instance.setActiveVaultKey(
            vaultKey,
            isDuress: wasDuress,
          );
          await LocalVaultDatabase.instance.openVault(
            key: vaultKey,
            isDuress: wasDuress,
          );
        } catch (_) {}

        if (!mounted) return;
        HapticService.trigger(MekaarHapticIntent.success);
        Navigator.of(context).pop(true);
      } else {
        HapticService.trigger(MekaarHapticIntent.destructive);
        _shakeController.forward(from: 0.0);
        setState(() {
          _pin = '';
          _isVerifying = false;
          _errorMessage = 'PIN salah. Silakan coba lagi.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _isVerifying = false;
        _errorMessage = 'Terjadi kesalahan saat memverifikasi PIN.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isPinSet = authState.isPinSet;
    final isLocked = authState.isPinLocked;

    if (!isPinSet) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MekaarColors.warnAmber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsOutline.shieldWarning,
                color: MekaarColors.warnAmber,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PIN Keamanan Belum Diatur',
              style: MekaarTypography.headingMD.copyWith(
                color: MekaarColors.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Anda perlu membuat PIN 6 digit terlebih dahulu untuk mengamankan brankas dan arsip.',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MekaarColors.primaryOf(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, false);
                  Navigator.pushNamed(context, AppRoutes.pin, arguments: true);
                },
                child: const Text('Atur PIN Sekarang'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    if (isLocked) {
      final rem = authState.remainingLockMinutes;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MekaarColors.sosRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsOutline.lockPassword,
                color: MekaarColors.sosRed,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Akses PIN Terkunci Sementara',
              style: MekaarTypography.headingMD.copyWith(
                color: MekaarColors.sosRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Terlalu banyak percobaan PIN yang salah. Demi keamanan, silakan tunggu $rem menit sebelum mencoba lagi.',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tutup'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MekaarColors.primaryOf(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              SolarIconsOutline.safeSquare,
              color: MekaarColors.primaryOf(context),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: MekaarTypography.headingMD.copyWith(
              color: MekaarColors.textPrimaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            style: MekaarTypography.bodySM.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Indikator 6-digit dots dengan shake animation
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pinLength,
                (index) => Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _errorMessage != null
                          ? MekaarColors.sosRed
                          : MekaarColors.primaryOf(context).withValues(alpha: 0.5),
                      width: 2,
                    ),
                    color: _pin.length > index
                        ? (_errorMessage != null
                            ? MekaarColors.sosRed
                            : MekaarColors.primaryOf(context))
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: MekaarTypography.caption.copyWith(
                color: MekaarColors.sosRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else
            const SizedBox(height: 24),

          // Keypad numerik
          _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 60);
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              width: 72,
              height: 56,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isVerifying ? null : () => _handleKey(key),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: key == '⌫'
                          ? Colors.transparent
                          : MekaarColors.surface2Of(context),
                    ),
                    alignment: Alignment.center,
                    child: key == '⌫'
                        ? Icon(
                            SolarIconsOutline.backspace,
                            color: MekaarColors.textPrimaryOf(context),
                            size: 24,
                          )
                        : Text(
                            key,
                            style: MekaarTypography.headingLG.copyWith(
                              color: MekaarColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
