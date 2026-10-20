import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../core/widgets/mekaar_snackbar.dart';
import '../../../data/services/location_service.dart';
import '../providers/nearby_friends_provider.dart';

/// NearbyPermissionHelper — Koordinator terpusat untuk perizinan lokasi & mitigasi fitur Teman Sekitar.
class NearbyPermissionHelper {
  NearbyPermissionHelper._();

  /// Menguji status izin dan mengaktifkan fitur Teman Sekitar.
  ///
  /// Mengembalikan `true` jika fitur berhasil diaktifkan.
  /// Jika izin ditolak permanen, menampilkan `MekaarDialog.showLocationPermissionRequiredDialog`.
  /// Jika pengguna memilih membuka Pengaturan HP, [onSettingsOpened] dipanggil sebelum navigasi.
  static Future<bool> activateWithPermissionCheck(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onSettingsOpened,
  }) async {
    try {
      // 1. Cek status izin saat ini
      final status = await Permission.location.status;

      // Kasus A: Izin sudah ditolak permanen sebelumnya
      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        final openSettings =
            await MekaarDialog.showLocationPermissionRequiredDialog(
          context: context,
        );
        if (openSettings) {
          onSettingsOpened?.call();
          await openAppSettings();
        }
        return false;
      }

      // Kasus B: Belum pernah diberikan / ditolak 1x
      if (!status.isGranted) {
        final reqStatus = await Permission.location.request();

        if (reqStatus.isPermanentlyDenied) {
          if (!context.mounted) return false;
          final openSettings =
              await MekaarDialog.showLocationPermissionRequiredDialog(
            context: context,
          );
          if (openSettings) {
            onSettingsOpened?.call();
            await openAppSettings();
          }
          return false;
        }

        if (!reqStatus.isGranted) {
          if (context.mounted) {
            MekaarSnackbar.warning(
              context,
              'Izin lokasi diperlukan untuk mendeteksi keberadaan teman sekitar.',
            );
          }
          return false;
        }
      }

      // 2. Izin aplikasi sudah aktif, pastikan sakelar GPS perangkat menyala
      final serviceEnabled = await LocationService.isServiceEnabled();
      if (!serviceEnabled) {
        final serviceGranted = await LocationService.requestService();
        if (!serviceGranted) {
          if (context.mounted) {
            MekaarSnackbar.warning(
              context,
              'Layanan GPS perangkat belum aktif. Nyalakan GPS untuk menggunakan radar.',
            );
          }
          return false;
        }
      }

      // 3. Eksekusi aktivasi pada provider
      final success = await ref
          .read(nearbyFriendsProvider.notifier)
          .toggleSharing(true);

      if (!success && context.mounted) {
        final errMsg = ref.read(nearbyFriendsProvider).errorMessage;
        MekaarSnackbar.error(
          context,
          errMsg ?? 'Gagal mengaktifkan Teman Sekitar. Silakan coba lagi.',
        );
      }

      return success;
    } catch (e) {
      if (context.mounted) {
        MekaarSnackbar.error(
          context,
          'Terjadi kesalahan saat memeriksa izin lokasi: $e',
        );
      }
      return false;
    }
  }
}
