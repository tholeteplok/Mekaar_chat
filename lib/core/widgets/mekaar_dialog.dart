import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../constants/icons.dart';

class MekaarDialog extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? message;
  final Widget? customContent;
  final List<Widget> actions;
  final bool isDestructive;

  const MekaarDialog({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.customContent,
    required this.actions,
    this.isDestructive = false,
  });

  static Future<T?> showConfirmation<T>({
    required BuildContext context,
    required String title,
    required String message,
    required List<Widget> actions,
    Widget? icon,
    bool barrierDismissible = true,
    bool isDestructive = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => MekaarDialog(
        icon: icon,
        title: title,
        message: message,
        actions: actions,
        isDestructive: isDestructive,
      ),
    );
  }

  /// Dialog konfirmasi sederhana: judul + body + tombol konfirmasi.
  ///
  /// [confirmLabel] default "OK", [confirmColor] untuk warna tombol konfirmasi.
  /// [onConfirm] dipanggil setelah dialog tertutup jika user tekan konfirmasi.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String body,
    String confirmLabel = 'OK',
    Color? confirmColor,
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: confirmColor ??
                    (isDestructive
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (result == true) onConfirm?.call();
  }

  static Future<bool> showNoActiveGuardianWarning({
    required BuildContext context,
  }) async {
    final shouldContinue = await showConfirmation<bool>(
      context: context,
      barrierDismissible: false,
      isDestructive: true,
      icon: Icon(
        MekaarIcons.shieldOutline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: 'Belum Ada Guardian Aktif',
      message:
          'Tidak ada Guardian aktif yang akan menerima notifikasi SOS Anda. '
          'Anda tetap dapat mengaktifkan SOS untuk merekam sesi dan lokasi darurat.',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Tetap Aktifkan SOS'),
        ),
      ],
    );
    return shouldContinue ?? false;
  }

  /// Dialog peringatan 1-tap saat izin lokasi ditolak permanen pada pemicuan SOS
  static Future<bool> showLocationPermissionDeniedWarning({
    required BuildContext context,
  }) async {
    final shouldContinue = await showConfirmation<bool>(
      context: context,
      barrierDismissible: false,
      isDestructive: true,
      icon: Icon(
        MekaarIcons.locationPin,
        color: Theme.of(context).colorScheme.error,
      ),
      title: 'Izin Lokasi Tidak Aktif',
      message:
          'Izin lokasi dinonaktifkan di perangkat ini sehingga koordinat GPS tidak dapat dilacak secara langsung oleh wali darurat Anda. '
          'Perekaman audio darurat dan status SOS akan tetap berjalan.',
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Mengerti & Lanjutkan SOS'),
        ),
      ],
    );
    return shouldContinue ?? true;
  }

  /// Dialog mitigasi sentralisasi untuk mengarahkan pengguna ke Pengaturan HP saat izin lokasi ditolak permanen
  static Future<bool> showLocationPermissionRequiredDialog({
    required BuildContext context,
    String title = 'Izin Lokasi Diperlukan',
    String message =
        'Fitur Teman Sekitar membutuhkan akses lokasi untuk mendeteksi jarak kasar secara aman dan anonim. '
        'Karena izin sebelumnya dinonaktifkan di perangkat ini, silakan aktifkan izin lokasi di Pengaturan Aplikasi.',
    String confirmLabel = 'Buka Pengaturan',
    String cancelLabel = 'Nanti Saja',
  }) async {
    final confirmed = await showConfirmation<bool>(
      context: context,
      barrierDismissible: true,
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MekaarColors.guardianTeal.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          SolarIconsOutline.mapPointWave,
          color: MekaarColors.guardianTeal,
          size: 28,
        ),
      ),
      title: title,
      message: message,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelLabel,
            style: TextStyle(
              color: MekaarColors.textSecondaryOf(context),
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MekaarColors.guardianTeal,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = isDestructive ? colorScheme.error : colorScheme.primary;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MekaarRadius.lg),
      ),
      titlePadding: MekaarSpacing.dialog,
      contentPadding: const EdgeInsets.symmetric(horizontal: MekaarSpacing.xl),
      actionsPadding: const EdgeInsets.fromLTRB(
        MekaarSpacing.lg,
        MekaarSpacing.md,
        MekaarSpacing.lg,
        MekaarSpacing.lg,
      ),
      title: Row(
        children: [
          icon ??
              Icon(
                isDestructive
                    ? MekaarIcons.warningAmberRounded
                    : MekaarIcons.infoOutline,
                color: accentColor,
              ),
          const SizedBox(width: MekaarSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: customContent ??
          (message != null
              ? Text(
                  message!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null),
      actions: actions,
    );
  }
}
