import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/database_key_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/auto_lock_provider.dart';

/// Layanan terpusat untuk proteksi sesi terbatas (Mode Tamu / Decoy & Mode Darurat / Duress).
///
/// Mengorkestrasi strategi Hybrid 3-Lapis:
/// - Lapis 1 (Ephemeral RAM-Only): Toggle pengaturan ringan hanya hidup di memori sesi tamu
///   dan dipulihkan ke nilai persisten Master saat dikunci / dibuka ulang oleh pemilik.
/// - Lapis 2 (Honeypot PIN Terisolasi): Dikelola di `AuthNotifier`.
/// - Lapis 3 (Safe Silent Close): Aksi destruktif (Logout, ubah profil/foto, hapus/putus/blokir
///   Guardian) tidak pernah mengeksekusi mutasi server/lokal, melainkan mengunci sesi dan
///   menutup aktivitas OS secara bersih (`SystemNavigator.pop`, bebas korupsi SQLite WAL).
class GuestSessionGuard {
  const GuestSessionGuard._();

  /// Jeda mikro sebelum aplikasi menutup jendela aktivitas agar terasa alami.
  /// Dapat disetel ke `Duration.zero` dalam pengujian otomatis.
  static Duration silentCloseDelay = const Duration(milliseconds: 250);

  /// Callback penutupan aktivitas OS secara bersih (default `SystemNavigator.pop()`).
  /// Dapat di-override dalam unit/widget test.
  static Future<void> Function() exitAppCallback =
      () => SystemNavigator.pop();

  /// Mengembalikan `true` bila sesi aktif saat ini adalah Mode Tamu atau Mode Darurat.
  static bool isRestrictedSession(WidgetRef ref) =>
      ref.read(authProvider).isDecoyActive;

  /// Mengembalikan `true` bila sesi aktif terbatas melalui [Ref].
  static bool isRestrictedSessionRef(Ref ref) =>
      ref.read(authProvider).isDecoyActive;

  /// Memulihkan preferensi persisten milik Master ke memori (diimplementasikan penuh pada T20).
  static Future<void> restoreMasterPreferences(dynamic ref) async {}

  /// Menjalankan Lapis 3 (*Safe Silent Close*): membatalkan mutasi apa pun secara implisit,
  /// memulihkan preferensi Master di RAM, menyegel brankas + mengunci aplikasi ke `PinScreen`,
  /// lalu menutup aktivitas OS secara bersih tanpa memicu korupsi WAL SQLite.
  static Future<void> triggerSafeSilentClose(WidgetRef ref) async {
    if (silentCloseDelay > Duration.zero) {
      await Future.delayed(silentCloseDelay);
    }
    await restoreMasterPreferences(ref);
    ref.read(autoLockControllerProvider).lockApplication(ref);
    await DatabaseKeyService.instance.lockVault();
    await exitAppCallback();
  }
}
