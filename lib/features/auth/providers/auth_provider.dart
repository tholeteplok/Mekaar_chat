import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/supabase_service.dart';

// Dependency Providers
final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());
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

  AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
    this.isPinSet = false,
    this.pinAttempts = 0,
    this.pinLockedUntil,
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
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isPinSet: isPinSet ?? this.isPinSet,
      pinAttempts: pinAttempts ?? this.pinAttempts,
      pinLockedUntil: pinLockedUntil ?? this.pinLockedUntil,
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

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.signInWithEmail(email, password);
      if (user != null) {
        state = state.copyWith(user: user);
        await loadProfile();
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Login gagal');
      return false;
    } catch (e) {
      String friendlyError = e.toString();
      final lowerError = friendlyError.toLowerCase();
      if (lowerError.contains('invalid login credentials') || lowerError.contains('invalid_credentials')) {
        friendlyError = 'Email atau password salah. Silakan periksa kembali.';
      }
      state = state.copyWith(isLoading: false, error: friendlyError);
      return false;
    }
  }

  Future<bool> register(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepository.signUpWithEmail(email, password, username);
      if (user != null) {
        state = state.copyWith(user: user);
        await loadProfile();
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Registrasi gagal');
      return false;
    } catch (e) {
      String friendlyError = e.toString();
      final lowerError = friendlyError.toLowerCase();
      
      if (lowerError.contains('user already registered') || 
          lowerError.contains('email already registered') || 
          (lowerError.contains('already exists') && lowerError.contains('email')) ||
          lowerError.contains('unique_violation') && lowerError.contains('email')) {
        friendlyError = 'Alamat email sudah terdaftar. Silakan masuk atau gunakan email lain.';
      } else if (lowerError.contains('already exists') && lowerError.contains('username') || 
                 lowerError.contains('profiles_username_key') ||
                 lowerError.contains('unique_violation') && lowerError.contains('username')) {
        friendlyError = 'Username sudah digunakan oleh orang lain. Silakan pilih username unik lainnya.';
      } else if (lowerError.contains('password should be')) {
        friendlyError = 'Password kurang aman. Minimal harus 6 karakter.';
      }
      
      state = state.copyWith(isLoading: false, error: friendlyError);
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    state = AuthState();
  }

  // Setup dynamic PIN
  Future<void> setupPIN(String pin) async {
    state = state.copyWith(isLoading: true);
    await _authRepository.setPIN(pin);
    state = state.copyWith(isPinSet: true, isLoading: false);
  }

  // Validate dynamic PIN with lockout check
  Future<bool> validatePIN(String pin) async {
    if (state.isPinLocked) return false;

    state = state.copyWith(isLoading: true);
    final isValid = await _authRepository.validatePIN(pin);
    
    if (isValid) {
      state = state.copyWith(pinAttempts: 0, pinLockedUntil: null, isLoading: false);
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
      );
      return false;
    }
  }

  // Force unlock PIN — HANYA untuk debug. Di production build ini adalah no-op.
  void devForceUnlock() {
    if (kDebugMode) {
      state = state.copyWith(pinAttempts: 0, pinLockedUntil: null);
    }
  }
}

// Global Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepo);
});
