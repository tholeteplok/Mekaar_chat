import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/services/notification_service.dart';
import '../../chat/providers/private_vault_provider.dart';
import 'auth_provider.dart';

/// Opsi batas waktu kunci otomatis aplikasi (Auto-Lock Timeout).
enum AutoLockTimeout {
  system(
    keyName: 'system',
    label: 'Saat Layar Terkunci',
    description: 'Aplikasi terkunci seketika saat layar ponsel mati atau terkunci.',
    duration: Duration.zero,
  ),
  thirtySeconds(
    keyName: '30s',
    label: '30 Detik',
    description: 'Terkunci jika aplikasi berada di latar belakang selama 30 detik.',
    duration: Duration(seconds: 30),
  ),
  oneMinute(
    keyName: '1m',
    label: '1 Menit',
    description: 'Terkunci jika aplikasi berada di latar belakang selama 1 menit.',
    duration: Duration(minutes: 1),
  ),
  fiveMinutes(
    keyName: '5m',
    label: '5 Menit',
    description: 'Terkunci jika aplikasi berada di latar belakang selama 5 menit.',
    duration: Duration(minutes: 5),
  ),
  off(
    keyName: 'off',
    label: 'Saat Aplikasi Ditutup',
    description: 'Hanya meminta PIN saat aplikasi dibuka ulang dari awal (cold start).',
    duration: null,
  );

  final String keyName;
  final String label;
  final String description;
  final Duration? duration;

  const AutoLockTimeout({
    required this.keyName,
    required this.label,
    required this.description,
    required this.duration,
  });

  static AutoLockTimeout fromKey(String? key) {
    if (key == null) return AutoLockTimeout.thirtySeconds;
    return AutoLockTimeout.values.firstWhere(
      (e) => e.keyName == key,
      orElse: () => AutoLockTimeout.thirtySeconds,
    );
  }
}

/// Notifier untuk mengelola preferensi Auto-Lock Timeout pengguna.
class AutoLockTimeoutNotifier extends StateNotifier<AutoLockTimeout> {
  static const String prefKey = 'mekaar_auto_lock_timeout';
  final SharedPreferences? _prefs;

  AutoLockTimeoutNotifier([this._prefs]) : super(AutoLockTimeout.thirtySeconds) {
    _load();
  }

  Future<void> _load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final savedKey = prefs.getString(prefKey);
    state = AutoLockTimeout.fromKey(savedKey);
  }

  Future<void> setTimeout(AutoLockTimeout timeout) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    state = timeout;
    await prefs.setString(prefKey, timeout.keyName);
  }
}

/// Provider preferensi AutoLockTimeout.
final autoLockTimeoutProvider =
    StateNotifierProvider<AutoLockTimeoutNotifier, AutoLockTimeout>((ref) {
  return AutoLockTimeoutNotifier();
});

/// Controller terpusat untuk memantau lifecycle background dan mengeksekusi Auto-Lock.
class AutoLockController {
  DateTime? _lastPausedAt;
  bool _isLockScreenActive = false;
  NotificationRoute? _pendingNotificationRoute;

  bool get isLockScreenActive => _isLockScreenActive;
  NotificationRoute? get pendingNotificationRoute => _pendingNotificationRoute;

  void markPinScreenActive(bool active) {
    _isLockScreenActive = active;
  }

  void onAppPaused() {
    _lastPausedAt = DateTime.now().toUtc();
  }

  /// Mendaftarkan rute notifikasi yang tertahan saat aplikasi terkunci.
  void setPendingRoute(NotificationRoute route) {
    _pendingNotificationRoute = route;
  }

  /// Mengambil rute yang tertunda jika PIN master sukses, atau membuang jika duress/decoy.
  NotificationRoute? consumePendingRoute({required bool isMasterAuth}) {
    final route = _pendingNotificationRoute;
    _pendingNotificationRoute = null;
    return isMasterAuth ? route : null;
  }

  /// Mengevaluasi apakah aplikasi sedang dalam status terkunci.
  bool isAppLockedWithContainer(ProviderContainer container) {
    if (_isLockScreenActive) return true;

    final routeName = AppNavigator.currentRouteName;
    if (routeName == AppRoutes.pin || routeName == AppRoutes.splash) {
      return true;
    }

    final authState = container.read(authProvider);
    if (!authState.isPinSet) return false;

    // Evaluasi batas waktu latar belakang
    final pausedAt = _lastPausedAt;
    if (pausedAt != null) {
      final timeout = container.read(autoLockTimeoutProvider);
      if (timeout == AutoLockTimeout.system) {
        return true;
      } else if (timeout.duration != null) {
        final elapsed = DateTime.now().toUtc().difference(pausedAt);
        if (elapsed >= timeout.duration!) {
          return true;
        }
      }
    }

    return false;
  }

  bool isAppLocked(WidgetRef ref) {
    if (_isLockScreenActive) return true;

    final routeName = AppNavigator.currentRouteName;
    if (routeName == AppRoutes.pin || routeName == AppRoutes.splash) {
      return true;
    }

    final authState = ref.read(authProvider);
    if (!authState.isPinSet) return false;

    final pausedAt = _lastPausedAt;
    if (pausedAt != null) {
      final timeout = ref.read(autoLockTimeoutProvider);
      if (timeout == AutoLockTimeout.system) {
        return true;
      } else if (timeout.duration != null) {
        final elapsed = DateTime.now().toUtc().difference(pausedAt);
        if (elapsed >= timeout.duration!) {
          return true;
        }
      }
    }

    return false;
  }

  /// Mengevaluasi apakah aplikasi perlu dikunci saat kembali aktif (resumed).
  Future<void> handleAppResumed(WidgetRef ref) async {
    final pausedAt = _lastPausedAt;
    _lastPausedAt = null;

    if (pausedAt == null || _isLockScreenActive) return;

    final timeout = ref.read(autoLockTimeoutProvider);
    if (timeout == AutoLockTimeout.off) return;

    final now = DateTime.now().toUtc();
    final elapsed = now.difference(pausedAt);

    bool shouldLock = false;
    if (timeout == AutoLockTimeout.system) {
      // Saat layar mati atau dialihkan ke system background, anggap terkunci
      shouldLock = true;
    } else if (timeout.duration != null) {
      shouldLock = elapsed >= timeout.duration!;
    }

    if (shouldLock) {
      final authState = ref.read(authProvider);
      // Hanya kunci jika pengguna sudah login dan memiliki PIN
      if (authState.user != null && authState.isPinSet) {
        lockApplication(ref);
      }
    }
  }

  /// Mengunci aplikasi secara instan menggunakan ProviderContainer
  void lockApplicationWithContainer(ProviderContainer container) {
    if (_isLockScreenActive) return;

    container.read(unlockedVaultSlotsProvider.notifier).state = {};
    container.read(privateVaultUnlockedProvider.notifier).state = false;

    final nav = AppNavigator.navigatorKey.currentState;
    if (nav != null) {
      _isLockScreenActive = true;
      nav.pushNamedAndRemoveUntil(
        AppRoutes.pin,
        (route) => false,
        arguments: false, // isSetup: false
      );
    }
  }

  /// Mengunci aplikasi secara instan dan mengarahkan ke PinScreen
  void lockApplication(WidgetRef ref) {
    if (_isLockScreenActive) return;

    // 1. Segel brankas dari memori (RAM)
    ref.read(unlockedVaultSlotsProvider.notifier).state = {};
    ref.read(privateVaultUnlockedProvider.notifier).state = false;

    // 2. Arahkan navigator ke PinScreen
    final nav = AppNavigator.navigatorKey.currentState;
    if (nav != null) {
      _isLockScreenActive = true;
      nav.pushNamedAndRemoveUntil(
        AppRoutes.pin,
        (route) => false,
        arguments: false, // isSetup: false
      );
    }
  }
}

final autoLockControllerProvider = Provider<AutoLockController>((ref) {
  return AutoLockController();
});
