import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/mekaar_dialog.dart';
import '../../../data/services/notification_service.dart';
import 'auth_provider.dart';

/// Listener Realtime untuk mendeteksi perubahan Kata Sandi (Password) dari perangkat/sesi lain.
///
/// Channel `postgres_changes` dikelola bersama oleh `AppRealtimeListener`
/// (satu channel global terpadu, bukan per-listener). Listener `auth`
/// state lokal tetap dipegang di sini.
class PasswordChangeAlertListener {
  final Ref _ref;
  final Logger _log = Logger();
  bool _disposed = false;
  DateTime? _lastObservedPasswordUpdate;

  PasswordChangeAlertListener(this._ref);

  /// Berlangganan perubahan Auth State lokal (bukan Realtime DB).
  /// Dipanggil oleh `AppRealtimeListener.start()`.
  void startAuthListener() {
    final supabaseService = _ref.read(supabaseServiceProvider);
    final userId = supabaseService.currentUserId;
    if (userId == null) {
      _log.w('PasswordChangeAlertListener: user belum login, skip.');
      return;
    }

    // Berlangganan perubahan Auth State lokal
    supabaseService.client.auth.onAuthStateChange.listen((data) {
      if (_disposed) return;
      if (data.event == AuthChangeEvent.userUpdated) {
        _log.i('PasswordChangeAlertListener: Auth event USER_UPDATED terdeteksi.');
      }
    });
  }

  /// Dipanggil oleh `AppRealtimeListener` saat ada UPDATE di tabel profiles
  /// milik user yang sedang login.
  void handleProfileUpdated(PostgresChangePayload payload) async {
    if (_disposed) return;

    final newRow = payload.newRecord;
    final updatedReason = newRow['last_security_event'] as String?;
    final updatedAtStr = newRow['updated_at'] as String?;

    if (updatedReason == 'PASSWORD_CHANGED' || updatedReason == 'PASSWORD_UPDATE') {
      final updatedAt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : DateTime.now();
      
      if (_lastObservedPasswordUpdate != null &&
          updatedAt != null &&
          updatedAt.difference(_lastObservedPasswordUpdate!).inSeconds < 5) {
        return;
      }
      _lastObservedPasswordUpdate = updatedAt;

      _triggerSecurityAlert();
    }
  }

  void _triggerSecurityAlert() async {
    _log.w('🚨 PASSWORD CHANGE DETECTED FROM OTHER DEVICE!');

    await NotificationService.showNormalNotification(
      title: '🚨 PERINGATAN KEAMANAN AKUN',
      body: 'Kata sandi Anda baru saja diubah di perangkat lain. Ketuk untuk mengamankan akun.',
    );

    final context = AppNavigator.currentContext;
    if (context == null || !context.mounted) return;

    MekaarDialog.showConfirmation(
      context: context,
      title: '🚨 Password Diubah di Sesi Lain',
      message:
          'Sistem mendeteksi bahwa kata sandi akun MEKAAR Anda baru saja diubah melalui perangkat/sesi lain.\n\nDemi keamanan data & pesan E2EE Anda, harap verifikasi identitas atau keluar dari sesi ini.',
      icon: const Icon(Icons.security_rounded, color: MekaarColors.sosRed, size: 28),
      barrierDismissible: false,
      isDestructive: true,
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await _ref.read(authProvider.notifier).logout();
          },
          child: const Text('Keluar Sekarang', style: TextStyle(color: MekaarColors.sosRed)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(
              context,
              AppRoutes.pin,
              arguments: false,
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: MekaarColors.accentOf(context)),
          child: const Text('Verifikasi PIN'),
        ),
      ],
    );
  }

  void dispose() {
    _disposed = true;
  }
}

final passwordChangeAlertListenerProvider =
    Provider<PasswordChangeAlertListener>((ref) {
  final listener = PasswordChangeAlertListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});
