import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_banner.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../auth/providers/auth_provider.dart';

/// Layar pengaturan PIN Tamu / Decoy.
/// Digunakan untuk skenario meminjamkan ponsel ke pihak ketiga (teman/pasangan/keluarga).
/// Membuka tampilan akun bersih alami tanpa memicu sinyal darurat SOS.
class DecoyPinScreen extends ConsumerStatefulWidget {
  const DecoyPinScreen({super.key});

  @override
  ConsumerState<DecoyPinScreen> createState() => _DecoyPinScreenState();
}

class _DecoyPinScreenState extends ConsumerState<DecoyPinScreen> {
  bool _isLoading = true;
  bool _enabled = false;
  bool _isEditing = false;
  bool _isSetting = false;

  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _status = 'Masukkan PIN Tamu 6 digit.';

  static const int _len = 6;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final enabled = await ref.read(authProvider.notifier).isDecoyEnabled();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _isLoading = false;
          _status = _enabled
              ? 'PIN Tamu aktif.'
              : 'Masukkan PIN Tamu 6 digit.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onKey(String key) {
    HapticService.trigger(MekaarHapticIntent.selection);
    if (key == 'Batal') {
      setState(() {
        _isEditing = false;
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
        _status = 'PIN Tamu aktif.';
      });
      return;
    }
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }
    if (_pin.length < _len) {
      setState(() => _pin += key);
      if (_pin.length == _len) {
        _submit();
      }
    }
  }

  Future<void> _submit() async {
    if (!_isConfirming) {
      _confirmPin = _pin;
      setState(() {
        _pin = '';
        _isConfirming = true;
        _status = _isEditing
            ? 'Konfirmasi PIN Tamu 6 digit baru.'
            : 'Konfirmasi PIN Tamu 6 digit.';
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

    // Validasi tidak sama dengan PIN utama
    final isSameAsPrimary =
        await ref.read(authProvider.notifier).validatePIN(_pin, allowDuress: false, allowDecoy: false);
    if (isSameAsPrimary) {
      HapticService.trigger(MekaarHapticIntent.destructive);
      setState(() {
        _pin = '';
        _isConfirming = false;
        _status = 'PIN Tamu tidak boleh sama dengan PIN utama.';
      });
      return;
    }

    // Validasi tidak sama dengan PIN Paksaan
    final isSameAsDuress =
        await ref.read(authRepositoryProvider).validateDuressPIN(_pin);
    if (isSameAsDuress) {
      HapticService.trigger(MekaarHapticIntent.destructive);
      setState(() {
        _pin = '';
        _isConfirming = false;
        _status = 'PIN Tamu tidak boleh sama dengan PIN Paksaan.';
      });
      return;
    }

    setState(() => _isSetting = true);
    try {
      await ref.read(authProvider.notifier).setupDecoyPIN(_pin);
      if (mounted) {
        final wasEditing = _isEditing;
        setState(() {
          _isSetting = false;
          _enabled = true;
          _isEditing = false;
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _status = 'PIN Tamu aktif.';
        });
        MekaarSnackbar.success(
          context,
          wasEditing
              ? 'PIN Tamu berhasil diperbarui.'
              : 'PIN Tamu berhasil diatur.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSetting = false);
        MekaarSnackbar.error(context, 'Gagal mengatur PIN Tamu: $e');
      }
    }
  }

  Future<void> _disable() async {
    final isPrimaryValid = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Konfirmasi PIN Utama',
      subtitle: 'Masukkan PIN utama Anda untuk menonaktifkan PIN Tamu',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!mounted || !isPrimaryValid) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MekaarColors.surface2Of(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        title: const Text('Nonaktifkan PIN Tamu?'),
        content: const Text(
          'PIN Tamu akan dihapus. Memasukkan PIN ini di layar kunci tidak akan membuka mode decoy lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.sosRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSetting = true);
    try {
      await ref.read(authProvider.notifier).disableDecoyPIN();
      if (mounted) {
        setState(() {
          _isSetting = false;
          _enabled = false;
          _isEditing = false;
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _status = 'PIN Tamu dinonaktifkan.';
        });
        MekaarSnackbar.success(context, 'PIN Tamu dinonaktifkan.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSetting = false);
        MekaarSnackbar.error(context, 'Gagal menonaktifkan PIN Tamu: $e');
      }
    }
  }

  Future<void> _startEditing() async {
    final isPrimaryValid = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Konfirmasi PIN Utama',
      subtitle: 'Masukkan PIN utama Anda untuk mengubah PIN Tamu',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!mounted || !isPrimaryValid) return;

    setState(() {
      _isEditing = true;
      _pin = '';
      _confirmPin = '';
      _isConfirming = false;
      _status = 'Masukkan PIN Tamu 6 digit baru.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MekaarScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _enabled && !_isEditing
                      ? _buildActiveState(context)
                      : _buildKeypadState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(SolarIconsOutline.arrowLeft),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text('PIN Tamu / Decoy', style: MekaarTypography.headingSM),
          const Spacer(),
          if (_enabled && !_isEditing)
            IconButton(
              icon: const Icon(SolarIconsOutline.pen),
              tooltip: 'Ubah PIN Tamu',
              onPressed: _isSetting ? null : _startEditing,
            ),
        ],
      ),
    );
  }

  Widget _buildActiveState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          MekaarBanner(
            color: MekaarColors.primary,
            icon: SolarIconsOutline.usersGroupTwoRounded,
            content: Text(
              'PIN Tamu Aktif: Saat PIN ini dimasukkan di layar kunci, aplikasi akan membuka akun bersih dengan pesan sambutan alami tanpa memicu sinyal darurat SOS.',
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textPrimaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSetting ? null : _startEditing,
            icon: const Icon(SolarIconsOutline.pen),
            label: const Text('Ubah PIN Tamu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MekaarColors.brandPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSetting ? null : _disable,
            icon: const Icon(SolarIconsOutline.trashBinTrash),
            label: const Text('Nonaktifkan PIN Tamu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MekaarColors.sosRed,
              side: BorderSide(
                color: MekaarColors.sosRed.withValues(alpha: 0.5),
              ),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MekaarRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadState(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _status,
            textAlign: TextAlign.center,
            style: MekaarTypography.bodyMD.copyWith(
              color: MekaarColors.textSecondaryOf(context),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_len, (index) {
            final isFilled = index < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? MekaarColors.primary
                    : MekaarColors.borderOf(context),
              ),
            );
          }),
        ),
        const Spacer(),
        _buildKeypad(context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildKeypad(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [_isEditing ? 'Batal' : '', '0', '⌫'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 72);
                }
                return InkWell(
                  onTap: _isSetting ? null : () => _onKey(key),
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MekaarColors.surfaceOf(context),
                    ),
                    child: key == '⌫'
                        ? const Icon(SolarIconsOutline.backspace)
                        : Text(
                            key,
                            style: MekaarTypography.headingMD.copyWith(
                              fontSize: key == 'Batal' ? 14 : 22,
                            ),
                          ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
