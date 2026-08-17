import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_bottom_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../core/widgets/mika_illustration.dart';
import '../../../data/services/alarm_service.dart';
import '../providers/device_lost_provider.dart';

class DeviceLostLockScreen extends ConsumerStatefulWidget {
  const DeviceLostLockScreen({super.key});

  @override
  ConsumerState<DeviceLostLockScreen> createState() =>
      _DeviceLostLockScreenState();
}

class _DeviceLostLockScreenState extends ConsumerState<DeviceLostLockScreen> {
  bool _isAlarmPlaying = false;
  final _pinController = TextEditingController();
  bool _isUnlocking = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _isAlarmPlaying = AlarmService.isPlaying;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _toggleAlarm() async {
    if (_isAlarmPlaying) {
      await AlarmService.stopAlarm();
      if (!mounted) return;
      setState(() => _isAlarmPlaying = false);
      MekaarSnackbar.success(context, 'Alarm berhasil dimatikan.');
    } else {
      await AlarmService.playSOSAlarm();
      if (!mounted) return;
      setState(() => _isAlarmPlaying = true);
      MekaarSnackbar.error(context, 'Alarm berbunyi keras!');
    }
  }

  Future<void> _callRecoveryContact(String contactNumber) async {
    try {
      final cleanNumber = contactNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        MekaarSnackbar.error(context, 'Tidak dapat melakukan panggilan telepon.');
      }
    } catch (_) {
      if (!mounted) return;
      MekaarSnackbar.error(context, 'Gagal memicu panggilan telepon.');
    }
  }

  void _showUnlockBottomSheet(BuildContext context) {
    _pinController.clear();
    setState(() => _pinError = null);

    MekaarBottomSheet.show(
      context: context,
      title: 'Buka Kunci Perangkat',
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Masukkan 6-digit PIN MEKAAR Anda untuk menonaktifkan Mode Hilang.',
                    style: TextStyle(
                      fontSize: 14,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    textField: true,
                    label: 'Input PIN 6 digit untuk buka kunci',
                    hint: 'Masukkan 6 digit angka PIN Anda',
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        counterText: '',
                        errorText: _pinError,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isUnlocking
                        ? null
                        : () async {
                            final pin = _pinController.text.trim();
                            if (pin.length != 6) {
                              setSheetState(() {
                                _pinError = 'PIN harus 6 digit angka';
                              });
                              return;
                            }

                            setSheetState(() {
                              _isUnlocking = true;
                              _pinError = null;
                            });

                            final success = await ref
                                .read(deviceLostProvider.notifier)
                                .unlockWithPIN(pin);

                            if (!mounted) return;

                            final nav = Navigator.of(this.context);
                            final scContext = this.context;

                            if (success) {
                              if (AlarmService.isPlaying) {
                                await AlarmService.stopAlarm();
                              }
                              nav.pop(); // Close bottom sheet
                              nav.pop(); // Close lock screen
                              if (scContext.mounted) {
                                MekaarSnackbar.success(
                                  scContext,
                                  'Mode Hilang berhasil dinonaktifkan.',
                                );
                              }
                            } else {
                              setSheetState(() {
                                _isUnlocking = false;
                                _pinError = 'PIN salah. Silakan coba lagi.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUnlocking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buka Kunci'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(deviceLostProvider);
    final contact = lockState.recoveryContact;

    return MekaarScaffold(
      flat: false,
      forceDark: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MekaarColors.sosRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MekaarColors.sosRed.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SolarIconsBold.shieldWarning,
                      color: MekaarColors.sosRed,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'PERANGKAT DALAM MODE HILANG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Mascot Illustration
              const MikaIllustration(
                pose: MikaPose.huft,
                size: 130,
                semanticLabel: 'Ponsel dalam mode hilang',
              ),
              const SizedBox(height: 28),
              // Main Message Card
              Expanded(
                child: CustomCard(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              SolarIconsOutline.lockKeyhole,
                              color: MekaarColors.sosRed,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pesan Pemilik Ponsel:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lockState.lockMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (contact != null && contact.isNotEmpty) ...[
                          const Divider(height: 32, color: Colors.white12),
                          const Text(
                            'Nomor Pemulihan:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: MekaarColors.accentOf(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              if (contact != null && contact.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _callRecoveryContact(contact),
                    icon: const Icon(SolarIconsBold.phoneCalling),
                    label: Text('Hubungi Pemilik ($contact)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _toggleAlarm,
                      icon: Icon(
                        _isAlarmPlaying
                            ? SolarIconsOutline.volumeCross
                            : SolarIconsOutline.volumeLoud,
                      ),
                      label: Text(_isAlarmPlaying ? 'Stop Sirine' : 'Bunyikan Sirine'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Unlock Button
              TextButton.icon(
                onPressed: () => _showUnlockBottomSheet(context),
                icon: const Icon(SolarIconsOutline.keyMinimalistic, size: 18),
                label: const Text('Saya Pemilik Ponsel (Buka dengan PIN)'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
