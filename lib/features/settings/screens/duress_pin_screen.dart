import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/mekaar_banner.dart';
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
  bool _isLoading = true;
  bool _enabled = false;
  bool _isEditing = false;
  bool _isSetting = false;
  bool _obscurePin = true;

  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _status = 'Masukkan PIN Paksaan 6 digit.';

  static const int _len = 6;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final enabled = await ref.read(authProvider.notifier).isDuressEnabled();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _isLoading = false;
          _status = _enabled
              ? 'PIN Paksaan aktif.'
              : 'Masukkan PIN Paksaan 6 digit.';
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
        _status = 'PIN Paksaan aktif.';
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
            ? 'Konfirmasi PIN Paksaan 6 digit baru.'
            : 'Konfirmasi PIN Paksaan 6 digit.';
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
    final isSameAsPrimary =
        await ref.read(authProvider.notifier).validatePIN(_pin);
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
    try {
      await ref.read(authProvider.notifier).setupDuressPIN(_pin);
      if (mounted) {
        final wasEditing = _isEditing;
        setState(() {
          _isSetting = false;
          _enabled = true;
          _isEditing = false;
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _status = 'PIN Paksaan aktif.';
        });
        MekaarSnackbar.success(
          context,
          wasEditing
              ? 'PIN Paksaan berhasil diperbarui.'
              : 'PIN Paksaan berhasil diatur.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSetting = false);
        MekaarSnackbar.error(context, 'Gagal mengatur PIN Paksaan: $e');
      }
    }
  }

  Future<String?> _promptPrimaryPin(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: MekaarColors.surface2Of(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MekaarRadius.lg),
          ),
          title: Text(title, style: MekaarTypography.headingSM),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: MekaarTypography.bodySM.copyWith(
                  color: MekaarColors.textSecondaryOf(ctx),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'PIN Utama (6 digit)',
                  counterText: '',
                  prefixIcon: const Icon(SolarIconsOutline.lockKeyhole),
                  filled: true,
                  fillColor: MekaarColors.surfaceOf(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                    borderSide: BorderSide(color: MekaarColors.borderOf(ctx)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                'Batal',
                style: TextStyle(color: MekaarColors.textSecondaryOf(ctx)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(ctx, text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.md),
                ),
              ),
              child: const Text('Lanjutkan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startChangePin() async {
    final primaryPin = await _promptPrimaryPin(
      context,
      title: 'Verifikasi PIN Utama',
      message: 'Masukkan PIN utama Anda untuk mengubah PIN Paksaan.',
    );
    if (primaryPin == null || primaryPin.isEmpty) return;

    final isValid =
        await ref.read(authProvider.notifier).validatePIN(primaryPin);
    if (!isValid) {
      if (mounted) {
        HapticService.trigger(MekaarHapticIntent.destructive);
        MekaarSnackbar.error(context, 'PIN utama salah.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isEditing = true;
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
        _status = 'Masukkan PIN Paksaan 6 digit baru.';
      });
    }
  }

  Future<void> _disable() async {
    final primaryPin = await _promptPrimaryPin(
      context,
      title: 'Nonaktifkan PIN Paksaan',
      message: 'Masukkan PIN utama Anda untuk menonaktifkan PIN Paksaan.',
    );
    if (primaryPin == null || primaryPin.isEmpty) return;

    final isValid =
        await ref.read(authProvider.notifier).validatePIN(primaryPin);
    if (!isValid) {
      if (mounted) {
        HapticService.trigger(MekaarHapticIntent.destructive);
        MekaarSnackbar.error(context, 'PIN utama salah.');
      }
      return;
    }

    setState(() => _isSetting = true);
    try {
      await ref.read(authProvider.notifier).disableDuressPIN();
      if (mounted) {
        setState(() {
          _isSetting = false;
          _enabled = false;
          _isEditing = false;
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
          _status = 'Masukkan PIN Paksaan 6 digit.';
        });
        MekaarSnackbar.success(context, 'PIN Paksaan berhasil dinonaktifkan.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSetting = false);
        MekaarSnackbar.error(context, 'Gagal menonaktifkan PIN Paksaan: $e');
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
    final cancel = k == 'Batal';
    return GestureDetector(
      onTap: () => _onKey(k),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (back || cancel)
              ? Colors.transparent
              : MekaarColors.surface2Of(context),
        ),
        child: Center(
          child: back
              ? Icon(
                  SolarIconsOutline.backspace,
                  color: Theme.of(context).colorScheme.onSurface,
                )
              : cancel
                  ? Text(
                      'Batal',
                      style: MekaarTypography.labelMD.copyWith(
                        color: MekaarColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildActiveView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MekaarColors.surface2Of(context),
              borderRadius: BorderRadius.circular(MekaarRadius.card),
              border: Border.all(
                color: MekaarColors.success.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: MekaarColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      SolarIconsOutline.shieldCheck,
                      color: MekaarColors.success,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'PIN Paksaan Aktif',
                  style: MekaarTypography.headingSM.copyWith(
                    color: MekaarColors.successTextOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fitur perlindungan darurat sedang aktif untuk akun Anda.',
                  textAlign: TextAlign.center,
                  style: MekaarTypography.bodySM.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MekaarColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(MekaarRadius.card),
              border: Border.all(
                color: MekaarColors.borderOf(context),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  SolarIconsOutline.infoCircle,
                  color: MekaarColors.brandPrimary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Jika Anda dipaksa membuka aplikasi dalam kondisi ancaman, '
                    'masukkan PIN Paksaan ini pada layar kunci.\n\n'
                    'Aplikasi akan terbuka seperti biasa untuk mengelabui pelaku, '
                    'tetapi sistem secara diam-diam memicu SOS dan mengirimkan lokasi darurat ke Guardian Anda.',
                    style: MekaarTypography.bodySM.copyWith(
                      color: MekaarColors.textSecondaryOf(context),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _startChangePin,
            icon: const Icon(SolarIconsOutline.pen),
            label: const Text('Ubah PIN Paksaan'),
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
            onPressed: _disable,
            icon: const Icon(SolarIconsOutline.trashBinTrash),
            label: const Text('Nonaktifkan PIN Paksaan'),
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

  Widget _buildInputView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Column(
                      children: [
                        MekaarBanner(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.all(14),
                          color: MekaarColors.sosRed,
                          icon: SolarIconsOutline.shieldWarning,
                          content: Text(
                            'PIN Paksaan TIDAK BOLEH sama dengan PIN utama. '
                            'Saat dimasukkan, aplikasi terbuka normal namun diam-diam memicu SOS ke Guardian.',
                            style: MekaarTypography.bodySM.copyWith(
                              color: MekaarColors.sosDeep,
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
                  const SizedBox(height: 12),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    icon: Icon(
                      _obscurePin
                          ? SolarIconsOutline.eyeClosed
                          : SolarIconsOutline.eye,
                      size: 22,
                      color: MekaarColors.textSecondaryOf(context),
                    ),
                    tooltip: _obscurePin ? 'Tampilkan PIN' : 'Sembunyikan PIN',
                    onPressed: () =>
                        setState(() => _obscurePin = !_obscurePin),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_len, (i) {
                      final isEntered = _pin.length > i;
                      final isDark = MekaarColors.isDarkContext(context);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isEntered
                                ? MekaarColors.brandPrimary
                                : MekaarColors.borderOf(context),
                            width: 2,
                          ),
                          color: isEntered
                              ? MekaarColors.textPrimaryOf(context)
                              : Colors.transparent,
                        ),
                        child: (!_obscurePin && isEntered)
                            ? Center(
                                child: Text(
                                  _pin[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      );
                    }),
                  ),
                  const Spacer(),
                  // Papan keypad PIN — selalu tampil saat mode input/ubah PIN
                  _keypadRow(['1', '2', '3']),
                  _keypadRow(['4', '5', '6']),
                  _keypadRow(['7', '8', '9']),
                  _keypadRow([_isEditing ? 'Batal' : '', '0', '⌫']),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isEditing) {
          setState(() {
            _isEditing = false;
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
            _status = 'PIN Paksaan aktif.';
          });
        }
      },
      child: MekaarScaffold(
        flat: true,
        body: SafeArea(
          child: Column(
            children: [
              SettingsTopBar(
                title: _enabled && !_isEditing
                    ? 'PIN Paksaan (Duress)'
                    : (_isEditing ? 'Ubah PIN Paksaan' : 'Buat PIN Paksaan'),
                onBack: _isEditing
                    ? () {
                        setState(() {
                          _isEditing = false;
                          _pin = '';
                          _confirmPin = '';
                          _isConfirming = false;
                          _status = 'PIN Paksaan aktif.';
                        });
                      }
                    : null,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _isSetting
                        ? const Center(
                            child: MekaarStateView(
                              pose: MikaPose.neutral,
                              title: 'Memproses PIN Paksaan',
                              message:
                                  'Tunggu sebentar, kami mengamankan akun Anda.',
                              illustrationSize: 96,
                              semanticLabel: 'Memproses PIN Paksaan',
                            ),
                          )
                        : _enabled && !_isEditing
                            ? _buildActiveView()
                            : _buildInputView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
