import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import 'mekaar_bottom_sheet.dart';
import 'mekaar_pin_dots_indicator.dart';

/// Modal bottom sheet terpusat untuk mengubah / membuat PIN 6-digit baru.
/// Alur: Masukkan PIN Baru (6 digit) -> Konfirmasi PIN Baru (6 digit).
class MekaarChangePinSheet extends StatefulWidget {
  final Future<bool> Function(String newPin) onConfirmPin;
  final String title;

  const MekaarChangePinSheet({
    super.key,
    required this.onConfirmPin,
    this.title = 'Ganti PIN',
  });

  static Future<bool> show(
    BuildContext context, {
    required Future<bool> Function(String newPin) onConfirmPin,
    String title = 'Ganti PIN',
  }) async {
    final result = await MekaarBottomSheet.show<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MekaarChangePinSheet(
        onConfirmPin: onConfirmPin,
        title: title,
      ),
    );
    return result ?? false;
  }

  @override
  State<MekaarChangePinSheet> createState() => _MekaarChangePinSheetState();
}

class _MekaarChangePinSheetState extends State<MekaarChangePinSheet> {
  static const int _pinLength = 6;
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  void _handleKey(String key) {
    if (_isSubmitting) return;

    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        HapticService.trigger(MekaarHapticIntent.selection);
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _errorMessage = null;
        });
      }
      return;
    }

    if (_pin.length < _pinLength) {
      HapticService.trigger(MekaarHapticIntent.selection);
      setState(() {
        _pin += key;
        _errorMessage = null;
      });

      if (_pin.length == _pinLength) {
        _handlePinComplete();
      }
    }
  }

  Future<void> _handlePinComplete() async {
    if (!_isConfirming) {
      // Selesai langkah 1: simpan PIN pertama, minta konfirmasi
      HapticService.trigger(MekaarHapticIntent.selection);
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
      });
    } else {
      // Langkah 2: Cocokkan konfirmasi
      if (_pin == _firstPin) {
        setState(() => _isSubmitting = true);
        HapticService.trigger(MekaarHapticIntent.success);
        try {
          final success = await widget.onConfirmPin(_pin);
          if (!mounted) return;
          if (success) {
            Navigator.pop(context, true);
          } else {
            setState(() {
              _isSubmitting = false;
              _errorMessage = 'Gagal memperbarui PIN. Coba lagi.';
              _pin = '';
              _firstPin = '';
              _isConfirming = false;
            });
            HapticService.trigger(MekaarHapticIntent.destructive);
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'Terjadi kesalahan sistem. Coba lagi.';
            _pin = '';
            _firstPin = '';
            _isConfirming = false;
          });
          HapticService.trigger(MekaarHapticIntent.destructive);
        }
      } else {
        HapticService.trigger(MekaarHapticIntent.destructive);
        setState(() {
          _errorMessage = 'PIN tidak cocok. Mulai dari awal.';
          _pin = '';
          _firstPin = '';
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _isConfirming
        ? 'Masukkan kembali 6 digit PIN baru Anda'
        : 'Masukkan 6 digit PIN baru Anda';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MekaarColors.brandPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              SolarIconsOutline.keySquare,
              color: MekaarColors.brandPrimary,
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
            subtitle,
            style: MekaarTypography.bodySM.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Indikator 6-digit dots
          MekaarPinDotsIndicator(
            pinLength: _pinLength,
            enteredLength: _pin.length,
            isValidating: _isSubmitting,
            hasError: _errorMessage != null,
            dotSize: 14.0,
            dotSpacing: 16.0,
            activeColor: MekaarColors.brandPrimary,
            errorColor: MekaarColors.sosRed,
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
                  onTap: _isSubmitting ? null : () => _handleKey(key),
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
