import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/custom_card.dart';
import '../providers/guardian_provider.dart';
import '../../../data/models/guardian_model.dart';
import '../../auth/providers/auth_provider.dart';

class SwapGuardianScreen extends ConsumerStatefulWidget {
  final Guardian guardian;

  const SwapGuardianScreen({super.key, required this.guardian});

  @override
  ConsumerState<SwapGuardianScreen> createState() => _SwapGuardianScreenState();
}

class _SwapGuardianScreenState extends ConsumerState<SwapGuardianScreen> {
  // Izin untuk arah sebaliknya (B menjaga A)
  bool _gpsForB = true;
  bool _micForB = false;
  bool _videoForB = false;

  // Konfirmasi PIN
  String _pin = '';
  bool _isPinConfirming = false;
  bool _isLoading = false;
  static const int _pinLength = 6;

  void _handlePinKey(String key) {
    HapticService.trigger(MekaarHapticIntent.selection);
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }
    if (_pin.length < _pinLength) {
      setState(() => _pin += key);
      if (_pin.length == _pinLength) _verifyAndSwap();
    }
  }

  Future<void> _verifyAndSwap() async {
    setState(() => _isLoading = true);

    final isValid = await ref.read(authProvider.notifier).validatePIN(_pin);
    if (!isValid) {
      HapticService.trigger(MekaarHapticIntent.destructive);
      setState(() {
        _pin = '';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN salah. Silakan coba lagi.'),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
      return;
    }

    // PIN valid — kirim permintaan tukar posisi
    try {
      await ref
          .read(guardianProvider.notifier)
          .initiateRoleSwap(widget.guardian.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permintaan Tukar Posisi dikirim ke ${widget.guardian.name}!',
            ),
            backgroundColor: MekaarColors.success,
          ),
        );
        Navigator.popUntil(
          context,
          (route) => route.isFirst || route.settings.name == '/guardian',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      appBar: const CustomAppBar(
        title: 'Tukar Posisi',
        subtitle: 'Saling menjaga satu sama lain',
      ),
      body: _isPinConfirming ? _buildPinConfirmView() : _buildPermissionsView(),
    );
  }

  Widget _buildPermissionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MekaarColors.guardianLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MekaarColors.guardianTeal.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(SolarIconsOutline.refresh, color: MekaarColors.guardianTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tukar Posisi memungkinkan ${widget.guardian.name} juga menjadi guardian Anda '
                    'dengan izin yang sama. Kedua pihak harus menyetujui.',
                    style: MekaarTypography.bodySM.copyWith(
                      color: MekaarColors.guardianTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Existing direction
          Text('ARAH SAAT INI (A → B)', style: MekaarTypography.overline),
          const SizedBox(height: 12),
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Avatar(
                  initial: widget.guardian.name.isNotEmpty
                      ? widget.guardian.name[0]
                      : 'U',
                  size: 40,
                  isGuardian: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.guardian.name,
                        style: MekaarTypography.labelLG,
                      ),
                      Text(
                        'menjaga Anda saat ini',
                        style: MekaarTypography.bodySM,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _miniChip(
                      'GPS',
                      widget.guardian.permissions['gps'] ?? false,
                    ),
                    const SizedBox(width: 4),
                    _miniChip(
                      'Mic',
                      widget.guardian.permissions['mic'] ?? false,
                    ),
                    const SizedBox(width: 4),
                    _miniChip(
                      'Video',
                      widget.guardian.permissions['video'] ?? false,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // New direction
          Text('ARAH BARU (B → A)', style: MekaarTypography.overline),
          const SizedBox(height: 4),
          Text(
            'Pilih izin yang diberikan kepada Anda saat Anda menjadi guardian untuk ${widget.guardian.name}.',
            style: MekaarTypography.bodyMD,
          ),
          const SizedBox(height: 12),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: MekaarColors.softCoral,
                  title: Text(
                    'Lacak Lokasi GPS',
                    style: MekaarTypography.labelLG,
                  ),
                  subtitle: Text(
                    'Anda bisa melihat lokasi ${widget.guardian.name} saat SOS aktif.',
                    style: MekaarTypography.bodySM,
                  ),
                  value: _gpsForB,
                  onChanged: (v) => setState(() => _gpsForB = v),
                ),
                const Divider(
                  height: 1,
                  color: MekaarColors.borderLight,
                  indent: 72,
                ),
                SwitchListTile(
                  activeThumbColor: MekaarColors.softCoral,
                  title: Text(
                    'Akses Mikrofon',
                    style: MekaarTypography.labelLG,
                  ),
                  subtitle: Text(
                    'Anda bisa mendengar audio sekitar perangkat ${widget.guardian.name} saat SOS.',
                    style: MekaarTypography.bodySM,
                  ),
                  value: _micForB,
                  onChanged: (v) => setState(() => _micForB = v),
                ),
                const Divider(
                  height: 1,
                  color: MekaarColors.borderLight,
                  indent: 72,
                ),
                SwitchListTile(
                  activeThumbColor: MekaarColors.softCoral,
                  title: Text(
                    'Akses Kamera (Video Darurat)',
                    style: MekaarTypography.labelLG,
                  ),
                  subtitle: Text(
                    'Anda dapat mengirim video darurat ke guardian saat SOS.',
                    style: MekaarTypography.bodySM,
                  ),
                  value: _videoForB,
                  onChanged: (v) => setState(() => _videoForB = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(SolarIconsOutline.lock),
              label: Text(
                'Lanjutkan & Konfirmasi dengan PIN',
                style: MekaarTypography.buttonLG.copyWith(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.guardianTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => setState(() => _isPinConfirming = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinConfirmView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const Spacer(),
          const Icon(
            SolarIconsOutline.lock,
            size: 52,
            color: MekaarColors.guardianTeal,
          ),
          const SizedBox(height: 16),
          Text('Konfirmasi dengan PIN', style: MekaarTypography.headingMD),
          const SizedBox(height: 8),
          Text(
            'Masukkan PIN 6 digit Anda untuk mengonfirmasi permintaan Tukar Posisi.',
            textAlign: TextAlign.center,
            style: MekaarTypography.bodyMD,
          ),
          const SizedBox(height: 36),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pinLength,
              (index) => Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MekaarColors.border, width: 2),
                  color: _pin.length > index
                      ? MekaarColors.guardianTeal
                      : Colors.transparent,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (_isLoading)
            const CircularProgressIndicator(color: MekaarColors.guardianTeal)
          else
            _buildKeypad(),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() {
              _isPinConfirming = false;
              _pin = '';
            }),
            child: Text(
              'Kembali',
              style: MekaarTypography.bodyMD.copyWith(
                color: MekaarColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
      children: rows
          .map(
            (row) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                if (key.isEmpty) return const SizedBox(width: 80, height: 70);
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  width: 70,
                  height: 70,
                  child: InkWell(
                    onTap: () => _handlePinKey(key),
                    borderRadius: BorderRadius.circular(35),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: key == '⌫'
                            ? Colors.transparent
                            : MekaarColors.surface2Of(context),
                      ),
                      child: Center(
                        child: key == '⌫'
                            ? Icon(
                                SolarIconsOutline.backspace,
                                color: Theme.of(context).colorScheme.onSurface,
                              )
                            : Text(
                                key,
                                style: MekaarTypography.monoLG.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          )
          .toList(),
    );
  }

  Widget _miniChip(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: enabled ? MekaarColors.successLight : MekaarColors.borderLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: MekaarTypography.labelSM.copyWith(
          color: enabled ? MekaarColors.success : MekaarColors.textMuted,
        ),
      ),
    );
  }
}
