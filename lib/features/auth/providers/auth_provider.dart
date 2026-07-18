import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/supabase_service.dart';

// Dependency Providers
final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(),
);
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepository(supabaseService);
});

// State definition
class AuthState {
  final User? user;
  final Profile? profile;
  final bool isLoading;
  final String? error;
  final bool isPinSet;
  final int pinAttempts;
  final DateTime? pinLockedUntil;
  final bool lastUnlockWasDuress;
  final bool newDeviceLogin;

  AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
    this.isPinSet = false,
    this.pinAttempts = 0,
    this.pinLockedUntil,
    this.lastUnlockWasDuress = false,
    this.newDeviceLogin = false,
  });

  bool get isPinLocked {
    if (pinLockedUntil == null) return false;
    return pinLockedUntil!.isAfter(DateTime.now());
  }

  int get remainingLockMinutes {
    if (pinLockedUntil == null) return 0;
    final diff = pinLockedUntil!.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  AuthState copyWith({
    User? user,
    Profile? profile,
    bool? isLoading,
    String? error,
    bool? isPinSet,
    int? pinAttempts,
    DateTime? pinLockedUntil,
    bool? lastUnlockWasDuress,
    bool? newDeviceLogin,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isPinSet: isPinSet ?? this.isPinSet,
      pinAttempts: pinAttempts ?? this.pinAttempts,
      pinLockedUntil: pinLockedUntil ?? this.pinLockedUntil,
      lastUnlockWasDuress: lastUnlockWasDuress ?? this.lastUnlockWasDuress,
      newDeviceLogin: newDeviceLogin ?? this.newDeviceLogin,
    );
  }
}

// State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState()) {
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        state = state.copyWith(user: session.user, isLoading: true);
        await loadProfile();
      }
    } catch (_) {
      // Supabase is not initialized in widget tests, ignore safely.
    }
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _authRepository.getProfile();
      final isPinSet = await _authRepository.isPINSet();
      state = state.copyWith(
        profile: profile,
        user: Supabase.instance.client.auth.currentUser,
        isPinSet: isPinSet,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update the in-memory profile without triggering a full reload.
  void setProfileSilently(Profile profile) {
    state = state.copyWith(profile: profile);
  }

  Future<bool> login(String input, String password) async {
    final configError = _configurationErrorMessage();
    if (configError != null) {
      state = state.copyWith(isLoading: false, error: configError);
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.signInWithUsernameOrEmail(
        input,
        password,
      );
      if (user != null) {
        state = state.copyWith(user: user);
        await loadProfile();
        final isNewDevice = await _recordDeviceLogin();
        state = state.copyWith(newDeviceLogin: isNewDevice);
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Login gagal');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _translateError(e));
      return false;
    }
  }

  /// Catat device login & kembalikan true jika device berbeda dari sebelumnya.
  Future<bool> _recordDeviceLogin() async {
    try {
      final deviceName = await _getDeviceName();
      return await _authRepository.recordLoginDevice(deviceName);
    } catch (_) {
      return false;
    }
  }

  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfo.iosInfo;
        return '${info.name} (${info.model})';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await deviceInfo.windowsInfo;
        return info.computerName;
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await deviceInfo.linuxInfo;
        return info.name;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final info = await deviceInfo.macOsInfo;
        return info.computerName;
      }
    } catch (_) {}
    return 'Perangkat tidak dikenal';
  }

  Future<bool> register(String email, String password, String username) async {
    final configError = _configurationErrorMessage();
    if (configError != null) {
      state = state.copyWith(isLoading: false, error: configError);
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.signUpWithEmail(
        email,
        password,
        username,
      );
      if (user != null) {
        state = state.copyWith(user: user);
        await loadProfile();
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Registrasi gagal');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _translateError(e));
      return false;
    }
  }

  // Update username
  Future<void> updateUsername(String username) async {
    final configError = _configurationErrorMessage();
    if (configError != null) {
      throw Exception(configError);
    }

    try {
      final updatedProfile = await _authRepository.updateUsername(username);
      state = state.copyWith(profile: updatedProfile);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('unique') ||
          errorStr.contains('duplicate') ||
          errorStr.contains('profiles_username_key')) {
        throw Exception('Username sudah digunakan oleh orang lain.');
      }
      throw Exception('Gagal memperbarui username: $e');
    }
  }

  Future<bool> loginWithGoogle() async {
    final configError = _configurationErrorMessage();
    if (configError != null) {
      state = state.copyWith(isLoading: false, error: configError);
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: null,
      );
      // OAuth mengalihkan ke browser; sesi dipulihkan saat kembali via
      // auth state change. Kita anggap sukses jika tidak melempar error.
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _translateError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    state = AuthState();
  }

  /// Bersihkan flag alert new-device setelah ditampilkan.
  void clearNewDeviceFlag() {
    if (state.newDeviceLogin) {
      state = state.copyWith(newDeviceLogin: false);
    }
  }

  // Setup dynamic PIN
  Future<void> setupPIN(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.setPIN(pin);
      state = state.copyWith(isPinSet: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _translateError(e));
    }
  }

  // Validate dynamic PIN with lockout check.
  // Jika [pin] cocok dengan Duress PIN, buka normal tapi tandai
  // lastUnlockWasDuress = true (konsumen harus memicu SOS silent diam-diam).
  Future<bool> validatePIN(String pin) async {
    if (state.isPinLocked) return false;

    state = state.copyWith(isLoading: true);

    // Cek Duress PIN lebih dulu — BUKAN dihitung sebagai gagal.
    final isDuress = await _authRepository.validateDuressPIN(pin);
    if (isDuress) {
      state = state.copyWith(
        pinAttempts: 0,
        pinLockedUntil: null,
        isLoading: false,
        lastUnlockWasDuress: true,
      );
      return true;
    }

    final isValid = await _authRepository.validatePIN(pin);

    if (isValid) {
      state = state.copyWith(
        pinAttempts: 0,
        pinLockedUntil: null,
        isLoading: false,
        lastUnlockWasDuress: false,
      );
      return true;
    } else {
      final newAttempts = state.pinAttempts + 1;
      DateTime? lockedUntil;
      if (newAttempts >= 5) {
        lockedUntil = DateTime.now().add(const Duration(minutes: 30));
      }
      state = state.copyWith(
        pinAttempts: newAttempts,
        pinLockedUntil: lockedUntil,
        isLoading: false,
        lastUnlockWasDuress: false,
      );
      return false;
    }
  }

  // Setup Duress PIN (PIN Paksaan)
  Future<void> setupDuressPIN(String pin) async {
    await _authRepository.setDuressPIN(pin);
  }

  Future<void> disableDuressPIN() async {
    await _authRepository.disableDuressPIN();
  }

  Future<bool> isDuressEnabled() async {
    return _authRepository.isDuressEnabled();
  }

  // Force unlock PIN — HANYA untuk debug. Di production build ini adalah no-op.
  void devForceUnlock() {
    if (kDebugMode) {
      state = state.copyWith(pinAttempts: 0, pinLockedUntil: null);
    }
  }

  String? _configurationErrorMessage() {
    if (!SupabaseService.hasConfigurationError) return null;

    final detail = SupabaseService.initializationError;
    if (kDebugMode && detail != null) {
      debugPrint('Supabase configuration error: $detail');
    }

    return 'Konfigurasi server belum aktif. Periksa file .env lalu lakukan full restart aplikasi.';
  }

  // Centralized Indonesian error message translator
  String _translateError(dynamic e) {
    final errorStr = e.toString();
    final lowerError = errorStr.toLowerCase();

    if (kDebugMode) {
      debugPrint('Auth error type: ${e.runtimeType}');
      debugPrint('Auth error: $errorStr');
    }

    if (_isConfigurationError(lowerError)) {
      return 'Konfigurasi server belum aktif. Periksa file .env lalu lakukan full restart aplikasi.';
    }

    // AuthException from Supabase — check type first before string matching
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials') ||
          msg.contains('invalid email or password') ||
          msg.contains('email not confirmed') ||
          msg.contains('email_not_confirmed') ||
          msg.contains('user not found') ||
          msg.contains('no user found')) {
        return 'Email atau password salah. Silakan periksa kembali.';
      }
      if (msg.contains('signup_disabled') ||
          msg.contains('signups not allowed')) {
        return 'Pendaftaran akun baru saat ini tidak tersedia.';
      }
      if (msg.contains('too many requests') || msg.contains('rate limit')) {
        return 'Terlalu banyak percobaan login. Tunggu beberapa saat lalu coba lagi.';
      }
      // Fallback for other AuthException — tampilkan pesan asli
      return e.message.isNotEmpty ? e.message : 'Autentikasi gagal. Coba lagi.';
    }

    // String-based matching for non-AuthException errors
    if (lowerError.contains('invalid login credentials') ||
        lowerError.contains('invalid_credentials') ||
        lowerError.contains('invalid email or password') ||
        lowerError.contains('email not confirmed') ||
        lowerError.contains('user tidak ditemukan') ||
        lowerError.contains('user not found')) {
      return 'Email atau password salah, atau akun tidak ditemukan.';
    }

    if (lowerError.contains('user already registered') ||
        lowerError.contains('email already registered') ||
        (lowerError.contains('already exists') &&
            lowerError.contains('email')) ||
        (lowerError.contains('unique_violation') &&
            lowerError.contains('email'))) {
      return 'Alamat email sudah terdaftar. Silakan masuk atau gunakan email lain.';
    }

    if ((lowerError.contains('already exists') &&
            lowerError.contains('username')) ||
        lowerError.contains('profiles_username_key') ||
        (lowerError.contains('unique_violation') &&
            lowerError.contains('username'))) {
      return 'Username sudah digunakan oleh orang lain. Silakan pilih username unik lainnya.';
    }

    if (lowerError.contains('password should be')) {
      return 'Password kurang aman. Minimal harus 6 karakter.';
    }

    if (_isConnectivityError(lowerError)) {
      return 'Koneksi internet gagal atau tidak stabil. Pastikan perangkat Anda terhubung ke internet dan coba lagi.';
    }

    // Server-level errors — harus dicek SETELAH semua pengecekan spesifik
    if (_isSupabaseServerError(lowerError)) {
      return 'Login belum bisa diproses. Periksa email/password atau coba beberapa saat lagi.';
    }

    // Final catch-all: jangan tampilkan raw technical error ke user
    // Jika error mengandung indikator jaringan/teknis, tampilkan pesan yang tepat
    if (lowerError.contains('exception') ||
        lowerError.contains('error') ||
        lowerError.contains('http') ||
        lowerError.contains('uri=') ||
        lowerError.contains('errno')) {
      if (lowerError.contains('host') ||
          lowerError.contains('lookup') ||
          lowerError.contains('socket') ||
          lowerError.contains('address') ||
          lowerError.contains('network') ||
          lowerError.contains('connect')) {
        return 'Koneksi internet gagal atau tidak stabil. Pastikan perangkat Anda terhubung ke internet dan coba lagi.';
      }
      return 'Terjadi kesalahan. Coba lagi beberapa saat.';
    }

    return errorStr;
  }

  bool _isConfigurationError(String lowerError) {
    return lowerError.contains('.env') ||
        lowerError.contains('supabase_url') ||
        lowerError.contains('supabase_anon_key') ||
        lowerError.contains('placeholder') ||
        lowerError.contains('konfigurasi supabase') ||
        lowerError.contains('koneksi database tidak aktif');
  }

  bool _isConnectivityError(String lowerError) {
    return lowerError.contains('socketexception') ||
        lowerError.contains('failed host lookup') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('connection timed out') ||
        lowerError.contains('network is unreachable') ||
        lowerError.contains('handshakeexception') ||
        lowerError.contains('no address associated with hostname');
  }

  bool _isSupabaseServerError(String lowerError) {
    // NOTE: 'authexception' dihapus dari sini karena AuthException sudah
    // ditangani secara eksplisit via type-check sebelum method ini dipanggil.
    return lowerError.contains('postgrestexception') ||
        lowerError.contains('clientexception') ||
        lowerError.contains('retryablefetch') ||
        lowerError.contains('status code') ||
        lowerError.contains('server error') ||
        lowerError.contains('bad request') ||
        lowerError.contains('unauthorized');
  }
}

// Global Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepo);
});

// App PIN Lock Enable/Disable preference provider
class PinLockEnabledNotifier extends StateNotifier<bool> {
  static const preferenceKey = 'is_pin_lock_enabled';

  final Future<SharedPreferences> _preferences;
  late final Future<void> initialized;

  PinLockEnabledNotifier({Future<SharedPreferences>? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance(),
      super(true) {
    initialized = _load();
  }

  Future<void> _load() async {
    final prefs = await _preferences;
    state = prefs.getBool(preferenceKey) ?? true;
  }

  Future<void> toggle(bool enabled) async {
    final prefs = await _preferences;
    final saved = await prefs.setBool(preferenceKey, enabled);
    if (!saved) {
      throw StateError('Preferensi kunci PIN gagal disimpan.');
    }
    state = enabled;
  }
}

final pinLockEnabledProvider =
    StateNotifierProvider<PinLockEnabledNotifier, bool>((ref) {
      return PinLockEnabledNotifier();
    });

// Default proteksi untuk room baru. Enforcement layar aktif dikelola oleh
// ScreenProtectionController berdasarkan room/surface yang sedang terbuka.
class ScreenshotBlockNotifier extends StateNotifier<bool> {
  ScreenshotBlockNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('is_screenshot_blocked') ?? true;
    } catch (_) {}
  }

  Future<void> toggle(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_screenshot_blocked', enabled);
      state = enabled;
    } catch (_) {}
  }
}

final screenshotBlockProvider =
    StateNotifierProvider<ScreenshotBlockNotifier, bool>((ref) {
      return ScreenshotBlockNotifier();
    });

// Notification Masking (blind spot #2): sembunyikan konten SOS/Alarm di layar
// kunci HP korban agar pelaku tidak curiga. Default AKTIF (fitur keamanan).
class NotificationMaskingNotifier extends StateNotifier<bool> {
  NotificationMaskingNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('is_notification_masked') ?? true;
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_notification_masked', enabled);
      state = enabled;
    } catch (_) {}
  }
}

final notificationMaskingProvider =
    StateNotifierProvider<NotificationMaskingNotifier, bool>((ref) {
      return NotificationMaskingNotifier();
    });
