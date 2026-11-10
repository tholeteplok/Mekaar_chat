import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/mekaar_badge.dart';
import '../../../core/widgets/mekaar_change_pin_sheet.dart';
import '../../../core/widgets/mekaar_pin_verification_sheet.dart';
import '../../../core/widgets/mekaar_scaffold.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sos/providers/sos_provider.dart';
import '../widgets/settings_tiles.dart';

/// Layar Manajemen PIN Terpusat (Tritunggal PIN & Zero-Knowledge Camouflage)
///
/// Mengelola 3 lapis kredensial:
/// 1. PIN Master (Wajib, Akses Penuh, Membuka Vault)
/// 2. PIN Tamu (Mode Camouflage Bersih, Tanpa Obrolan Rahasia)
/// 3. PIN Darurat (Mode Ancaman / Silent SOS ke Guardian)
///
/// Pada Sesi Mode Tamu (Decoy), layar ini otomatis berkamuflase
/// hanya menampilkan 1 kartu tunggal ("PIN Keamanan Aplikasi") tanpa jejak
/// opsi Master, Tamu, maupun Darurat (Zero-Knowledge Honeypot).
class PinManagementScreen extends ConsumerStatefulWidget {
  const PinManagementScreen({super.key});

  @override
  ConsumerState<PinManagementScreen> createState() =>
      _PinManagementScreenState();
}

class _PinManagementScreenState extends ConsumerState<PinManagementScreen> {
  bool _isLoading = true;
  bool _isDecoyEnabled = false;
  bool _isDuressEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final decoy = await ref.read(authProvider.notifier).isDecoyEnabled();
      final duress = await ref.read(authProvider.notifier).isDuressEnabled();
      if (mounted) {
        setState(() {
          _isDecoyEnabled = decoy;
          _isDuressEnabled = duress;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aksi PIN Master (Utama)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleChangeMasterPin() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Master',
      subtitle: 'Masukkan 6 digit PIN Master saat ini untuk melanjutkan',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!verified || !mounted) return;

    final success = await MekaarChangePinSheet.show(
      context,
      title: 'Ganti PIN Master',
      onConfirmPin: (newPin) async {
        final isSameDecoy = await ref
            .read(authRepositoryProvider)
            .validateDecoyPIN(newPin);
        if (isSameDecoy) {
          if (mounted) {
            MekaarSnackbar.error(
              context,
              'PIN Master tidak boleh sama dengan PIN Tamu.',
            );
          }
          return false;
        }

        final isSameDuress = await ref
            .read(authRepositoryProvider)
            .validateDuressPIN(newPin);
        if (isSameDuress) {
          if (mounted) {
            MekaarSnackbar.error(
              context,
              'PIN Master tidak boleh sama dengan PIN Darurat.',
            );
          }
          return false;
        }

        return await ref.read(authProvider.notifier).updateActivePin(newPin);
      },
    );

    if (success && mounted) {
      MekaarSnackbar.success(context, 'PIN Master berhasil diperbarui.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aksi PIN Tamu (Decoy Mode)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleSetOrChangeGuestPin() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Master',
      subtitle:
          'Masukkan PIN Master Anda untuk ${_isDecoyEnabled ? "mengubah" : "mengatur"} PIN Tamu',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!verified || !mounted) return;

    final success = await MekaarChangePinSheet.show(
      context,
      title: _isDecoyEnabled ? 'Ganti PIN Tamu' : 'Atur PIN Tamu',
      onConfirmPin: (newPin) async {
        final isSamePrimary = await ref
            .read(authProvider.notifier)
            .validatePIN(newPin, allowDuress: false, allowDecoy: false);
        if (isSamePrimary) {
          if (mounted) {
            MekaarSnackbar.error(
              context,
              'PIN Tamu tidak boleh sama dengan PIN Master.',
            );
          }
          return false;
        }

        final isSameDuress = await ref
            .read(authRepositoryProvider)
            .validateDuressPIN(newPin);
        if (isSameDuress) {
          if (mounted) {
            MekaarSnackbar.error(
              context,
              'PIN Tamu tidak boleh sama dengan PIN Darurat.',
            );
          }
          return false;
        }

        await ref.read(authProvider.notifier).setupDecoyPIN(newPin);
        return true;
      },
    );

    if (success && mounted) {
      await _loadStatus();
      if (mounted) {
        MekaarSnackbar.success(
          context,
          _isDecoyEnabled
              ? 'PIN Tamu berhasil diperbarui.'
              : 'PIN Tamu berhasil diaktifkan.',
        );
      }
    }
  }

  Future<void> _handleDisableGuestPin() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Master',
      subtitle: 'Masukkan PIN Master Anda untuk menonaktifkan PIN Tamu',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!verified || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MekaarColors.surface2Of(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        title: const Text('Nonaktifkan PIN Tamu?'),
        content: const Text(
          'PIN Tamu akan dihapus. Pengguna tidak akan dapat mengakses mode tamu hingga PIN diatur kembali.',
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

    if (confirm != true || !mounted) return;

    await ref.read(authProvider.notifier).disableDecoyPIN();
    await _loadStatus();
    if (mounted) {
      MekaarSnackbar.success(context, 'PIN Tamu telah dinonaktifkan.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aksi PIN Darurat (SOS / Duress)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleSetOrChangeDuressPin() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final isSosEnabled = ref.read(sosFeatureEnabledProvider);
    if (!isSosEnabled) {
      if (mounted) {
        MekaarSnackbar.info(
          context,
          'Fitur Darurat SOS sedang dinonaktifkan di Pengaturan. Aktifkan fitur SOS untuk mengatur PIN Darurat.',
        );
      }
      return;
    }

    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Master',
      subtitle:
          'Masukkan PIN Master Anda untuk ${_isDuressEnabled ? "mengubah" : "mengatur"} PIN Darurat',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!verified || !mounted) return;

    final success = await MekaarChangePinSheet.show(
      context,
      title: _isDuressEnabled ? 'Ganti PIN Darurat' : 'Atur PIN Darurat',
      onConfirmPin: (newPin) async {
        final isSamePrimary = await ref
            .read(authProvider.notifier)
            .validatePIN(newPin, allowDuress: false, allowDecoy: false);
        if (isSamePrimary) {
          if (mounted) {
            MekaarSnackbar.error(
              context,
              'PIN Darurat tidak boleh sama dengan PIN Master.',
            );
          }
          return false;
        }

        final isSameDecoy = await ref
            .read(authRepositoryProvider)
            .validateDecoyPIN(newPin);
        if (isSameDecoy) {
          if (mounted) {
            MekaarSnackbar.error(
              context,
              'PIN Darurat tidak boleh sama dengan PIN Tamu.',
            );
          }
          return false;
        }

        await ref.read(authProvider.notifier).setupDuressPIN(newPin);
        return true;
      },
    );

    if (success && mounted) {
      await _loadStatus();
      if (mounted) {
        MekaarSnackbar.success(
          context,
          _isDuressEnabled
              ? 'PIN Darurat berhasil diperbarui.'
              : 'PIN Darurat berhasil diaktifkan.',
        );
      }
    }
  }

  Future<void> _handleDisableDuressPin() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Master',
      subtitle: 'Masukkan PIN Master Anda untuk menonaktifkan PIN Darurat',
      allowDuress: false,
      allowDecoy: false,
    );
    if (!verified || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MekaarColors.surface2Of(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        title: const Text('Nonaktifkan PIN Darurat?'),
        content: const Text(
          'PIN Darurat akan dihapus. Memasukkan PIN ini di layar kunci tidak akan memicu Silent SOS lagi.',
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

    if (confirm != true || !mounted) return;

    await ref.read(authProvider.notifier).disableDuressPIN();
    await _loadStatus();
    if (mounted) {
      MekaarSnackbar.success(context, 'PIN Darurat telah dinonaktifkan.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aksi Ganti PIN di Mode Tamu (Honeypot Decoy Swap)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleChangeGuestAppPin() async {
    HapticService.trigger(MekaarHapticIntent.selection);
    final verified = await MekaarPinVerificationSheet.verify(
      context,
      title: 'Verifikasi PIN Saat Ini',
      subtitle: 'Masukkan 6 digit PIN Anda yang aktif untuk melanjutkan',
      allowDuress: false,
      allowDecoy: true,
    );
    if (!verified || !mounted) return;

    final success = await MekaarChangePinSheet.show(
      context,
      title: 'Ganti PIN Aplikasi',
      onConfirmPin: (newPin) async {
        return await ref.read(authProvider.notifier).updateActivePin(newPin);
      },
    );

    if (success && mounted) {
      MekaarSnackbar.success(context, 'PIN berhasil diperbarui.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Komponen Tampilan (Widgets)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDecoy = ref.watch(authProvider).isDecoyActive;

    return MekaarScaffold(
      flat: true,
      body: SafeArea(
        child: Column(
          children: [
            SettingsTopBar(
              title: isDecoy ? 'PIN Keamanan' : 'Manajemen PIN Keamanan',
              subtitle: isDecoy
                  ? 'Kelola kode akses keamanan'
                  : 'PIN Master, Tamu & Darurat',
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: isDecoy
                          ? [_buildGuestCamouflageCard(context)]
                          : _buildMasterViewCards(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan Kamuflase Sempurna di Mode Tamu (Zero-Knowledge)
  Widget _buildGuestCamouflageCard(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderRadius: MekaarRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MekaarColors.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  SolarIconsBold.shieldKeyhole,
                  color: MekaarColors.brandPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PIN Keamanan Aplikasi',
                      style: MekaarTypography.headingSM.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kode akses 6 digit untuk mengunci aplikasi',
                      style: MekaarTypography.caption.copyWith(
                        color: MekaarColors.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              MekaarBadge(
                label: 'Aktif',
                color: MekaarColors.successTextOf(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'PIN ini digunakan untuk melindungi data dan obrolan pribadi Anda dari akses pihak lain yang tidak diinginkan.',
            style: MekaarTypography.bodySM.copyWith(
              color: MekaarColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          const Divider(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleChangeGuestAppPin,
              icon: const Icon(SolarIconsOutline.pen, size: 18),
              label: const Text('Ganti PIN Aplikasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MekaarColors.primaryOf(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MekaarRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan Penuh di Mode Master (Tritunggal PIN)
  List<Widget> _buildMasterViewCards(BuildContext context) {
    return [
      // ── 1. Kartu PIN Master ──
      CustomCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        borderRadius: MekaarRadius.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MekaarColors.brandPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsBold.keySquare,
                    color: MekaarColors.brandPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIN Master (Utama)',
                        style: MekaarTypography.headingSM.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Akses Penuh & Kunci Brankas',
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                MekaarBadge(
                  label: 'Wajib & Aktif',
                  color: MekaarColors.brandPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'PIN utama memberikan akses penuh ke seluruh percakapan serta secara otomatis membuka dan mengelola seluruh kompartemen Brankas Rahasia (Private Vault).',
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleChangeMasterPin,
                icon: const Icon(SolarIconsOutline.pen, size: 18),
                label: const Text('Ganti PIN Master'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MekaarColors.primaryOf(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MekaarRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── 2. Kartu PIN Tamu (Decoy Mode) ──
      CustomCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        borderRadius: MekaarRadius.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MekaarColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsOutline.usersGroupTwoRounded,
                    color: MekaarColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIN Tamu (Decoy)',
                        style: MekaarTypography.headingSM.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Akses Bersih Saat Dipinjamkan',
                        style: MekaarTypography.caption.copyWith(
                          color: MekaarColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                MekaarBadge(
                  label: _isDecoyEnabled ? 'Aktif' : 'Belum Diatur',
                  color: _isDecoyEnabled
                      ? MekaarColors.successTextOf(context)
                      : MekaarColors.textMutedOf(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Gunakan saat ponsel Anda dipinjam oleh teman atau keluarga. Membuka obrolan reguler tanpa menampilkan obrolan brankas, tanpa gestur brankas, dan tanpa memicu sinyal darurat.',
              style: MekaarTypography.bodySM.copyWith(
                color: MekaarColors.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleSetOrChangeGuestPin,
                    icon: Icon(
                      _isDecoyEnabled
                          ? SolarIconsOutline.pen
                          : SolarIconsOutline.addCircle,
                      size: 18,
                    ),
                    label: Text(
                      _isDecoyEnabled ? 'Ganti PIN Tamu' : 'Atur PIN Tamu',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MekaarColors.surface2Of(context),
                      foregroundColor: MekaarColors.textPrimaryOf(context),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                        side: BorderSide(
                          color: MekaarColors.borderOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isDecoyEnabled) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _handleDisableGuestPin,
                    icon: const Icon(SolarIconsOutline.trashBinTrash, size: 20),
                    color: MekaarColors.sosRed,
                    tooltip: 'Nonaktifkan PIN Tamu',
                    style: IconButton.styleFrom(
                      backgroundColor: MekaarColors.sosRed.withValues(
                        alpha: 0.1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MekaarRadius.md),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),

      // ── 3. Kartu PIN Darurat (Silent SOS / Duress) ──
      Builder(
        builder: (context) {
          final isSosEnabled = ref.watch(sosFeatureEnabledProvider);
          return CustomCard(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            borderRadius: MekaarRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isSosEnabled
                                ? MekaarColors.sosCoral
                                : MekaarColors.textMutedOf(context))
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        SolarIconsBold.shieldKeyhole,
                        color: isSosEnabled
                            ? MekaarColors.sosCoral
                            : MekaarColors.textMutedOf(context),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PIN Darurat (Silent SOS)',
                            style: MekaarTypography.headingSM.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSosEnabled
                                ? 'Akses di Bawah Ancaman'
                                : 'Dinonaktifkan di Pengaturan',
                            style: MekaarTypography.caption.copyWith(
                              color: MekaarColors.textMutedOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    MekaarBadge(
                      label: !isSosEnabled
                          ? 'Nonaktif (SOS Mati)'
                          : (_isDuressEnabled ? 'Aktif' : 'Belum Diatur'),
                      color: !isSosEnabled
                          ? MekaarColors.textMutedOf(context)
                          : (_isDuressEnabled
                              ? MekaarColors.sosCoral
                              : MekaarColors.textMutedOf(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  !isSosEnabled
                      ? 'Fitur Darurat SOS sedang dinonaktifkan di Pengaturan. Untuk menggunakan PIN Darurat di bawah ancaman dan menyiarkan sinyal SOS senyap, aktifkan Fitur Darurat SOS terlebih dahulu.'
                      : 'Gunakan jika Anda dipaksa membuka ponsel oleh pihak yang mengancam keselamatan Anda. Aplikasi membuka tampilan obrolan kosong alami sekaligus mengirimkan sinyal SOS senyap dan lokasi GPS terkini ke Guardian.',
                  style: MekaarTypography.bodySM.copyWith(
                    color: MekaarColors.textSecondaryOf(context),
                    height: 1.4,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleSetOrChangeDuressPin,
                        icon: Icon(
                          !isSosEnabled
                              ? SolarIconsOutline.shieldCross
                              : (_isDuressEnabled
                                  ? SolarIconsOutline.pen
                                  : SolarIconsOutline.addCircle),
                          size: 18,
                        ),
                        label: Text(
                          !isSosEnabled
                              ? 'Fitur SOS Nonaktif'
                              : (_isDuressEnabled
                                  ? 'Ganti PIN Darurat'
                                  : 'Atur PIN Darurat'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.surface2Of(context),
                          foregroundColor: isSosEnabled
                              ? MekaarColors.textPrimaryOf(context)
                              : MekaarColors.textMutedOf(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(MekaarRadius.md),
                            side: BorderSide(
                              color: MekaarColors.borderOf(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isDuressEnabled && isSosEnabled) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _handleDisableDuressPin,
                        icon:
                            const Icon(SolarIconsOutline.trashBinTrash, size: 20),
                        color: MekaarColors.sosRed,
                        tooltip: 'Nonaktifkan PIN Darurat',
                        style: IconButton.styleFrom(
                          backgroundColor: MekaarColors.sosRed.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(MekaarRadius.md),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ];
  }
}
