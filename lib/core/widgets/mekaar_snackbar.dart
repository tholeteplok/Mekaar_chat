import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';
import '../services/haptic_service.dart';

/// MekaarSnackbar — Snackbar terpusat bergaya MEKAAR.
///
/// Gantikan semua [ScaffoldMessenger.showSnackBar] dengan helper statis ini.
/// Tampilan: floating, radius pill, ikon Solar semantik, haptic ringan.
///
/// Contoh:
/// ```dart
/// MekaarSnackbar.success(context, 'Pesan terkirim');
/// MekaarSnackbar.error(context, 'Gagal mengirim');
/// MekaarSnackbar.info(context, 'Mode Sekali Lihat aktif');
/// ```
class MekaarSnackbar {
  MekaarSnackbar._();

  static const Duration _durationShort = Duration(seconds: 2);
  static const Duration _durationLong = Duration(seconds: 4);

  /// Sukses — teal, ikon ceklis.
  static void success(
    BuildContext context,
    String message, {
    Duration duration = _durationShort,
  }) {
    HapticService.trigger(MekaarHapticIntent.success);
    _show(context, message, MekaarColors.safeTeal, SolarIconsOutline.checkCircle,
        duration);
  }

  /// Info netral — cyan, ikon info.
  static void info(
    BuildContext context,
    String message, {
    Duration duration = _durationShort,
  }) {
    HapticService.trigger(MekaarHapticIntent.selection);
    _show(context, message, MekaarColors.cyan, SolarIconsOutline.infoCircle,
        duration);
  }

  /// Error / destruktif — coral, ikon warning.
  static void error(
    BuildContext context,
    String message, {
    Duration duration = _durationLong,
  }) {
    HapticService.trigger(MekaarHapticIntent.destructive);
    _show(context, message, MekaarColors.sosCoral,
        SolarIconsOutline.dangerCircle, duration);
  }

  /// Peringatan — amber, ikon segitiga.
  static void warning(
    BuildContext context,
    String message, {
    Duration duration = _durationShort,
  }) {
    HapticService.trigger(MekaarHapticIntent.warning);
    _show(context, message, MekaarColors.warnAmber,
        SolarIconsOutline.dangerTriangle, duration);
  }

  static void _show(
    BuildContext context,
    String message,
    Color accentColor,
    IconData icon,
    Duration duration,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    // Hapus snackbar existing agar tidak bertumpuk
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: MekaarSpacing.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          MekaarSpacing.lg,
          0,
          MekaarSpacing.lg,
          MekaarSpacing.lg + 90, // Di atas nav bar
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MekaarSpacing.lg,
          vertical: MekaarSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MekaarRadius.lg),
        ),
        backgroundColor: MekaarColors.surfaceOf(context),
        elevation: 8,
      ),
    );
  }
}
