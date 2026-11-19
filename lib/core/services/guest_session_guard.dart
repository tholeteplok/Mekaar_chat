import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/database_key_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/auto_lock_provider.dart';
import '../../features/settings/providers/notification_preferences_provider.dart';
import '../../features/settings/providers/privacy_provider.dart';
import '../providers/theme_provider.dart';

/// Mixin ringan agar notifier preferensi mendukung Lapis 1 (Ephemeral RAM-Only)
/// saat sesi Tamu / Duress aktif tanpa menulis perubahan ke disk persisten.
mixin EphemeralSettingGuard {
  bool Function()? _isEphemeralSession;

  void attachEphemeralGuard(bool Function() guard) {
    _isEphemeralSession = guard;
  }

  bool get isEphemeralSession => _isEphemeralSession?.call() ?? false;
}

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

  static T? _tryRead<T>(dynamic ref, ProviderListenable<T> provider) {
    try {
      if (ref is WidgetRef) return ref.read(provider);
      if (ref is Ref) return ref.read(provider);
      if (ref is ProviderContainer) return ref.read(provider);
    } catch (_) {}
    return null;
  }

  /// Memulihkan seluruh preferensi persisten milik Master ke memori (membersihkan
  /// override sementara dari sesi Tamu / Duress).
  static Future<void> restoreMasterPreferences(dynamic ref) async {
    final tasks = <Future<void>>[];

    void scheduleReload(Future<void> Function()? fn) {
      if (fn == null) return;
      tasks.add(() async {
        try {
          await fn();
        } catch (_) {}
      }());
    }

    scheduleReload(_tryRead(ref, autoLockTimeoutProvider.notifier)?.reload);
    scheduleReload(_tryRead(ref, screenshotBlockProvider.notifier)?.reload);
    scheduleReload(_tryRead(ref, stealthChatPreviewProvider.notifier)?.reload);
    scheduleReload(_tryRead(ref, notificationMaskingProvider.notifier)?.reload);
    scheduleReload(_tryRead(ref, allowGuardianAlarmProvider.notifier)?.reload);
    scheduleReload(
      _tryRead(ref, notificationPreferencesProvider.notifier)?.reload,
    );
    scheduleReload(_tryRead(ref, themePreferenceProvider.notifier)?.reload);

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

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
