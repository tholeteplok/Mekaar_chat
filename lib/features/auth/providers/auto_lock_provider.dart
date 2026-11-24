import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/guest_session_guard.dart';
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
  custom(
    keyName: 'custom',
    label: 'Kustom',
    description: 'Atur sendiri batas waktu kunci otomatis aplikasi.',
    duration: Duration(minutes: 5),
  ),
  off(
    keyName: 'off',
    label: 'Nonaktif (Tanpa Kunci)',
    description:
        'Aplikasi tidak meminta PIN saat dibuka maupun saat di latar belakang.',
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
    if (key == '5m') return AutoLockTimeout.custom;
    return AutoLockTimeout.values.firstWhere(
      (e) => e.keyName == key,
      orElse: () => AutoLockTimeout.thirtySeconds,
    );
  }
}

/// Notifier untuk mengelola preferensi Auto-Lock Timeout pengguna.
class AutoLockTimeoutNotifier extends StateNotifier<AutoLockTimeout>
    with EphemeralSettingGuard {
  static const String prefKey = 'mekaar_auto_lock_timeout';
  static const String customDurationSecondsKey =
      'mekaar_auto_lock_custom_seconds';
  static const Duration defaultCustomDuration = Duration(minutes: 5);

  final SharedPreferences? _prefs;
  AutoLockTimeout _persistedTimeout = AutoLockTimeout.thirtySeconds;
  Duration _customDuration = defaultCustomDuration;
  Duration _persistedCustomDuration = defaultCustomDuration;
  final ValueNotifier<Duration> customDurationListenable =
      ValueNotifier<Duration>(defaultCustomDuration);
  late final Future<void> initialized;

  AutoLockTimeoutNotifier([this._prefs]) : super(AutoLockTimeout.thirtySeconds) {
    if (_prefs != null) {
      final saved = AutoLockTimeout.fromKey(_prefs.getString(prefKey));
      final savedSeconds = _prefs.getInt(customDurationSecondsKey);
      final loadedCustom = (savedSeconds != null && savedSeconds >= 5)
          ? Duration(seconds: savedSeconds)
          : defaultCustomDuration;
      _persistedTimeout = saved;
      _customDuration = loadedCustom;
      _persistedCustomDuration = loadedCustom;
      customDurationListenable.value = loadedCustom;
      state = saved;
      initialized = Future.value();
    } else {
      initialized = _load();
    }
  }

  /// Timeout sebenarnya milik pemilik (tetap ditegakkan meski Guest mengubah tampilan RAM).
  AutoLockTimeout get enforcedTimeout =>
      isEphemeralSession ? _persistedTimeout : state;

  /// Durasi kustom yang aktif untuk tampilan UI (termasuk saat sesi tamu).
  Duration get customDuration => _customDuration;

  /// Durasi kustom sebenarnya milik pemilik.
  Duration get enforcedCustomDuration =>
      isEphemeralSession ? _persistedCustomDuration : _customDuration;

  /// Durasi efektif yang ditegakkan oleh AutoLockController.
  Duration? get enforcedDuration {
    final t = enforcedTimeout;
    if (t == AutoLockTimeout.custom) return enforcedCustomDuration;
    return t.duration;
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final savedKey = prefs.getString(prefKey);
    final loaded = AutoLockTimeout.fromKey(savedKey);
    final savedSeconds = prefs.getInt(customDurationSecondsKey);
    final loadedCustom = (savedSeconds != null && savedSeconds >= 5)
        ? Duration(seconds: savedSeconds)
        : defaultCustomDuration;
    _persistedTimeout = loaded;
    _persistedCustomDuration = loadedCustom;
    _customDuration = loadedCustom;
    if (mounted) {
      customDurationListenable.value = loadedCustom;
      state = loaded;
    }
  }

  Future<void> setTimeout(AutoLockTimeout timeout) async {
    state = timeout;
    if (isEphemeralSession) return;
    _persistedTimeout = timeout;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(prefKey, timeout.keyName);
  }

  Future<void> setCustomDuration(Duration duration) async {
    final clampedSeconds = duration.inSeconds.clamp(5, 86400);
    final sanitized = Duration(seconds: clampedSeconds);
    _customDuration = sanitized;
    customDurationListenable.value = sanitized;
    state = AutoLockTimeout.custom;
    if (isEphemeralSession) return;
    _persistedTimeout = AutoLockTimeout.custom;
    _persistedCustomDuration = sanitized;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(prefKey, AutoLockTimeout.custom.keyName);
    await prefs.setInt(customDurationSecondsKey, clampedSeconds);
  }

  @override
  void dispose() {
    customDurationListenable.dispose();
    super.dispose();
  }
}

/// Provider preferensi AutoLockTimeout.
final autoLockTimeoutProvider =
    StateNotifierProvider<AutoLockTimeoutNotifier, AutoLockTimeout>((ref) {
  return AutoLockTimeoutNotifier()
    ..attachEphemeralGuard(() => ref.read(authProvider).isDecoyActive);
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

    // Evaluasi batas waktu latar belakang (selalu tegakkan nilai persisten Master)
    final pausedAt = _lastPausedAt;
    if (pausedAt != null) {
      final notifier = container.read(autoLockTimeoutProvider.notifier);
      final timeout = notifier.enforcedTimeout;
      final effectiveDuration = notifier.enforcedDuration;
      if (timeout == AutoLockTimeout.system) {
        return true;
      } else if (effectiveDuration != null) {
        final elapsed = DateTime.now().toUtc().difference(pausedAt);
        if (elapsed >= effectiveDuration) {
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
      final notifier = ref.read(autoLockTimeoutProvider.notifier);
      final timeout = notifier.enforcedTimeout;
      final effectiveDuration = notifier.enforcedDuration;
      if (timeout == AutoLockTimeout.system) {
        return true;
      } else if (effectiveDuration != null) {
        final elapsed = DateTime.now().toUtc().difference(pausedAt);
        if (elapsed >= effectiveDuration) {
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

    final notifier = ref.read(autoLockTimeoutProvider.notifier);
    final timeout = notifier.enforcedTimeout;
    if (timeout == AutoLockTimeout.off) return;

    final now = DateTime.now().toUtc();
    final elapsed = now.difference(pausedAt);

    bool shouldLock = false;
    final effectiveDuration = notifier.enforcedDuration;
    if (timeout == AutoLockTimeout.system) {
      // Saat layar mati atau dialihkan ke system background, anggap terkunci
      shouldLock = true;
    } else if (effectiveDuration != null) {
      shouldLock = elapsed >= effectiveDuration;
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
    unawaited(GuestSessionGuard.restoreMasterPreferences(container));

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

    // 1. Segel brankas dari memori (RAM) dan bersihkan override sesi tamu
    ref.read(unlockedVaultSlotsProvider.notifier).state = {};
    ref.read(privateVaultUnlockedProvider.notifier).state = false;
    unawaited(GuestSessionGuard.restoreMasterPreferences(ref));

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
