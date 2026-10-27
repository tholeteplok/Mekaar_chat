import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/storage/mekaar_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/e2ee_service.dart';
import '../services/local_message_database.dart';
import '../services/supabase_service.dart';
import 'device_repository.dart';

class AuthRepository {
  final SupabaseService _supabaseService;
  final FlutterSecureStorage _secureStorage = MekaarSecureStorage.instance;

  AuthRepository(this._supabaseService);

  Future<User?> signInWithGoogle() async {
    const webClientId =
        '5478970655-cc7ai5bm7370leogup4pkv32rkrs1lae.apps.googleusercontent.com';
    final googleSignIn = GoogleSignIn(serverClientId: webClientId);

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // Dibatalkan oleh pengguna

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Gagal memperoleh ID Token dari Google. Pastikan Google Auth terkonfigurasi dengan benar.',
      );
    }

    final response = await _supabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return response.user;
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      // 1. Coba RPC aman is_username_available (Remediasi H2)
      try {
        final rpcRes = await _supabaseService.client.rpc(
          'is_username_available',
          params: {'p_username': username.trim()},
        );
        if (rpcRes is bool) return rpcRes;
      } catch (_) {}

      // 2. Fallback query langsung jika RPC belum termigrasi di database lokal
      final res = await _supabaseService.client
          .from('public_profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      return res == null;
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadAndUpdateAvatar(File imageFile) async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final rawExt = imageFile.path.split('.').last.toLowerCase();
      final ext =
          (rawExt == 'jpeg' ||
              rawExt == 'jpg' ||
              rawExt == 'png' ||
              rawExt == 'webp')
          ? rawExt
          : 'jpg';
      final fileName = 'avatar.$ext';
      final storagePath = '${user.id}/$fileName';

      // Upload to Supabase Storage bucket 'avatars'
      await _supabaseService.client.storage
          .from('avatars')
          .upload(
            storagePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL
      final publicUrl = _supabaseService.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      // Add timestamp to avoid caching issues on client side
      final timestampUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Update profile
      await _supabaseService.client
          .from('profiles')
          .update({'avatar_url': timestampUrl})
          .eq('id', user.id);

      return timestampUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      rethrow;
    }
  }

  Future<void> deleteAvatar() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // 1. Update profiles table: set avatar_url = null
      await _supabaseService.client
          .from('profiles')
          .update({
            'avatar_url': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // 2. Best-effort cleanup files in Supabase storage bucket 'avatars'
      try {
        final files = await _supabaseService.client.storage
            .from('avatars')
            .list(path: user.id);
        if (files.isNotEmpty) {
          final paths = files.map((f) => '${user.id}/${f.name}').toList();
          await _supabaseService.client.storage.from('avatars').remove(paths);
        }
      } catch (e) {
        debugPrint('Best-effort avatar storage cleanup: $e');
      }
    } catch (e) {
      debugPrint('Error deleting avatar: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    final response = await _supabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
  }

  /// Send password reset OTP code to user's email.
  /// Resolves username to email if necessary.
  Future<String> sendPasswordResetEmail(String input) async {
    final email = await resolveEmailFromUsername(input);
    if (email == null || email.isEmpty) {
      throw Exception('Akun dengan email/username tersebut tidak ditemukan.');
    }
    await _supabaseService.client.auth.resetPasswordForEmail(email);
    return email;
  }

  /// Verify recovery OTP code/token and update user's password.
  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final session = _supabaseService.client.auth.currentSession;
    if (session == null) {
      await _supabaseService.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
    }
    await _supabaseService.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Sign up with email, password, and username
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    final response = await _supabaseService.client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    final user = response.user;

    // Fallback upsert to profiles in case trigger didn't persist username
    if (user != null) {
      try {
        await _supabaseService.client.from('profiles').upsert({
          'id': user.id,
          'username': username,
          'email': email,
          'pin_hash': '',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
      } catch (_) {
        // Trigger already handled it or RLS blocks; not fatal for register flow.
      }
    }

    return user;
  }

  // Resolve email from username or email string.
  // Uses resolve_login_email RPC which is accessible by anon role (before login).
  Future<String?> resolveEmailFromUsername(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    // Fast path: if it looks like an email, return as-is
    if (clean.contains('@')) return clean;

    // Use dedicated RPC accessible by anon role (pre-login)
    try {
      final response = await _supabaseService.client.rpc(
        'resolve_login_email',
        params: {'input_query': clean},
      );
      if (response is String && response.isNotEmpty) return response;
    } catch (_) {}

    return null;
  }

  // Sign in with username or email
  Future<User?> signInWithUsernameOrEmail(String input, String password) async {
    final clean = input.trim();
    if (clean.isEmpty) throw Exception('Username atau email wajib diisi');

    // 1. Jika pengguna memasukkan email secara langsung
    if (clean.contains('@')) {
      return signInWithEmail(clean, password);
    }

    // 2. Jika memasukkan username: Autentikasi via Edge Function login-with-username (Remediasi H3)
    // Menghilangkan kebocoran alamat email pengguna ke publik
    try {
      final response = await _supabaseService.client.functions.invoke(
        'login-with-username',
        body: {'username': clean, 'password': password},
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final sessionMap = data['session'] as Map<String, dynamic>?;
        if (sessionMap != null) {
          final refreshToken = sessionMap['refresh_token'] as String?;
          if (refreshToken != null && refreshToken.isNotEmpty) {
            final authResponse =
                await _supabaseService.client.auth.setSession(refreshToken);
            return authResponse.user;
          }
        }
      }

      final errorMsg = response.data is Map
          ? (response.data['error'] as String? ?? 'Username atau kata sandi tidak valid')
          : 'Username atau kata sandi tidak valid';
      throw Exception(errorMsg);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Akun ditangguhkan')) {
        rethrow;
      }

      // Coba fallback jika Edge Function mengalami kendala koneksi / cold start
      try {
        final email = await resolveEmailFromUsername(clean);
        if (email != null && email.isNotEmpty) {
          return await signInWithEmail(email, password);
        }
      } catch (fallbackError) {
        debugPrint('Fallback resolve_login_email failed: $fallbackError');
        if (fallbackError is AuthException) {
          rethrow;
        }
      }

      // Jika exception awal adalah FunctionException dengan payload error
      if (e is FunctionException && e.details is Map) {
        final detailsMap = e.details as Map;
        final serverError = detailsMap['error'] as String?;
        if (serverError != null && serverError.isNotEmpty) {
          throw Exception(serverError);
        }
      }
      rethrow;
    }
  }

  // Update username in profiles table (dengan validasi cooldown via RPC / timestamp)
  Future<Profile> updateUsername(String username) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final clean = username.trim().toLowerCase();

    // 1. Coba panggil RPC change_username yang memvalidasi format, keunikan, dan cooldown 60 hari
    try {
      await _supabaseService.client.rpc(
        'change_username',
        params: {'p_new_username': clean},
      );
      final refreshed = await getProfile();
      if (refreshed != null) return refreshed;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('tunggu') ||
          msg.contains('digunakan') ||
          msg.contains('karakter') ||
          msg.contains('huruf kecil')) {
        rethrow;
      }
      // Fallback update langsung jika RPC belum tersedia di server
      final response = await _supabaseService.client
          .from('profiles')
          .update({
            'username': clean,
            'username_last_changed_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromJson(response);
    }

    final p = await getProfile();
    if (p == null) throw Exception('Profil tidak ditemukan');
    return p;
  }

  // Update display name in profiles table
  Future<Profile> updateDisplayName(String displayName) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({
          'display_name': displayName,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Update bio in profiles table
  Future<Profile> updateBio(String bio) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({'bio': bio, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Update last_seen_privacy preference
  Future<Profile> updateLastSeenPrivacy(String privacyValue) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({
          'last_seen_privacy': privacyValue,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Update read_receipts_enabled preference
  Future<Profile> updateReadReceipts(bool enabled) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({
          'read_receipts_enabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Update chat_invitation_mode preference
  Future<Profile> updateChatInvitationMode(String mode) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({
          'chat_invitation_mode': mode,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Update default auto-delete (disappearing messages) hours
  Future<Profile> updateAutoDeleteDefault(int hours) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({
          'auto_delete_default_hours': hours,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Enable 2FA: store TOTP secret and activate.
  Future<Profile> enableTwoFa(String secret) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    await _supabaseService.client.rpc('enable_2fa', params: {'secret': secret});
    final profile = await getProfile();
    if (profile == null) throw Exception('Profil tidak ditemukan');
    return profile;
  }

  // Disable 2FA: remove secret and deactivate (dengan verifikasi password).
  Future<Profile> disableTwoFa({String? password}) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final provider =
        _supabaseService.currentUser?.appMetadata['provider'] as String? ??
        'email';
    if (provider == 'email' && (password != null && password.isNotEmpty)) {
      final verified = await verifyPassword(password);
      if (!verified) throw Exception('Password konfirmasi salah.');
    }

    await _supabaseService.client.rpc('disable_2fa');
    final profile = await getProfile();
    if (profile == null) throw Exception('Profil tidak ditemukan');
    return profile;
  }

  /// Catat device login. Mengembalikan true jika device BERBEDA dari sebelumnya.
  Future<bool> recordLoginDevice(String deviceName) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return false;
    try {
      final response = await _supabaseService.client.rpc(
        'record_login_device',
        params: {'device_name': deviceName},
      );
      return response == true;
    } catch (_) {
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Hapus FCM token dari server SEBELUM signout
    // Menggunakan DeviceRepository agar hanya token device ini yang dihapus
    // (bukan semua device user), mendukung multi-device.
    try {
      if (SupabaseService.isInitialized) {
        final repo = DeviceRepository(_supabaseService.client);
        await repo.clearFcmTokenForThisDevice();
      }
    } catch (_) {
      // Lanjutkan signout meskipun gagal clear token
    }

    try {
      await _secureStorage
          .delete(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
      await _secureStorage
          .delete(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
      await _secureStorage
          .delete(key: 'decoy_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      E2eeService.instance.clearSession();
      await LocalMessageDatabase.instance.clearAll();
    } catch (_) {}

    if (SupabaseService.isInitialized) {
      await _supabaseService.client.auth.signOut();
    }
  }

  // Get current user profile from database
  Future<Profile?> getProfile() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Profile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Hash PIN helper using Argon2id
  Future<String> _hashPIN(String pin, {List<int>? salt}) async {
    final argon2 = Argon2id(
      memory: 12000,
      iterations: 2,
      parallelism: 1,
      hashLength: 32,
    );
    final secretKey = SecretKey(utf8.encode(pin));

    // Generate salt if not provided
    final actualSalt =
        salt ??
        List<int>.generate(16, (i) => math.Random.secure().nextInt(256));

    final derivedKey = await argon2.deriveKey(
      secretKey: secretKey,
      nonce: actualSalt,
    );

    final derivedBytes = await derivedKey.extractBytes();
    final saltBase64 = base64Encode(actualSalt);
    final hashBase64 = base64Encode(derivedBytes);
    return '$saltBase64:$hashBase64';
  }

  // Helper to extract salt from stored hash
  List<int>? _extractSalt(String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length == 2) {
      try {
        return base64Decode(parts[0]);
      } catch (_) {}
    }
    return null;
  }

  // Verify account password for sensitive actions (like PIN reset)
  Future<bool> verifyPassword(String password) async {
    final user = _supabaseService.client.auth.currentUser;
    final email = user?.email;
    if (email == null) return false;
    try {
      final res = await _supabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user != null;
    } catch (_) {
      return false;
    }
  }

  // Reset PIN (hancurkan hash lokal & remote agar user bisa setup PIN baru)
  Future<void> resetPIN() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    try {
      await _secureStorage
          .delete(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
      await _secureStorage
          .delete(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
      await _secureStorage
          .delete(key: 'decoy_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    await _supabaseService.client
        .from('profiles')
        .update({
          'pin_hash': '',
          'duress_pin_hash': null,
          'duress_enabled': false,
        })
        .eq('id', userId);
  }

  // Set PIN in database and local secure storage
  Future<void> setPIN(String pin) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final pinHash = await _hashPIN(pin);

    try {
      await _secureStorage
          .write(key: 'pin_hash', value: pinHash)
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    // Save to remote profiles table
    await _supabaseService.client
        .from('profiles')
        .update({'pin_hash': pinHash})
        .eq('id', userId);
  }

  // Validate entered PIN against stored PIN
  Future<bool> validatePIN(String pin) async {
    String? storedHash;
    try {
      storedHash = await _secureStorage
          .read(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    if (storedHash == null || storedHash.isEmpty) {
      // Fallback to remote database check
      final profile = await getProfile();
      if (profile != null && profile.pinHash.isNotEmpty) {
        storedHash = profile.pinHash;
        try {
          await _secureStorage
              .write(key: 'pin_hash', value: storedHash)
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
      }
    }

    if (storedHash != null && storedHash.isNotEmpty) {
      // Backward compatibility: If stored hash doesn't contain ':', it's legacy SHA-256.
      if (!storedHash.contains(':')) {
        final bytes = utf8.encode(pin);
        final legacyHash = crypto.sha256.convert(bytes).toString();
        if (storedHash == legacyHash) {
          // Transparently upgrade to Argon2id in background
          setPIN(pin);
          return true;
        }
        return false;
      }

      final salt = _extractSalt(storedHash);
      final enteredHash = await _hashPIN(pin, salt: salt);
      return storedHash == enteredHash;
    }

    return false;
  }

  // Check if PIN has been set
  Future<bool> isPINSet() async {
    try {
      final localHash = await _secureStorage
          .read(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
      if (localHash != null && localHash.isNotEmpty) return true;
    } catch (_) {}

    final profile = await getProfile();
    return profile != null && profile.pinHash.isNotEmpty;
  }

  // ── Duress PIN (PIN Paksaan) ──────────────────────────────
  // PIN terpisah yang, bila dimasukkan saat dipaksa, membuka aplikasi
  // normal namun diam-diam memicu SOS silent.

  Future<void> setDuressPIN(String pin) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final pinHash = await _hashPIN(pin);

    try {
      await _secureStorage
          .write(key: 'duress_pin_hash', value: pinHash)
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    await _supabaseService.client
        .from('profiles')
        .update({'duress_pin_hash': pinHash, 'duress_enabled': true})
        .eq('id', userId);
  }

  Future<bool> isDuressEnabled() async {
    try {
      final local = await _secureStorage
          .read(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
      if (local == 'none' || local == 'disabled') return false;
      if (local != null && local.isNotEmpty) return true;
    } catch (_) {}
    final profile = await getProfile();
    return profile != null &&
        profile.pinHash.isNotEmpty &&
        (profile.duressPinHash?.isNotEmpty ?? false);
  }

  /// Sinkronkan status hash duress ke secure storage lokal agar tidak memicu query HTTP remote.
  Future<void> cacheDuressPinStatus(String? remoteHash) async {
    try {
      final val = (remoteHash != null && remoteHash.isNotEmpty) ? remoteHash : 'none';
      await _secureStorage
          .write(key: 'duress_pin_hash', value: val)
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  // Mengembalikan true bila [pin] cocok dengan duress PIN (bukan PIN utama).
  Future<bool> validateDuressPIN(String pin) async {
    String? storedHash;
    try {
      storedHash = await _secureStorage
          .read(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    // Jika hash ditandai 'none' atau 'disabled', berarti duress PIN memang tidak diatur.
    // Hindari melakukan network call ke getProfile() demi mempertahankan unlock instant (<300ms).
    if (storedHash == 'none' || storedHash == 'disabled') {
      return false;
    }

    if (storedHash == null || storedHash.isEmpty) {
      final profile = await getProfile();
      if (profile != null && profile.duressPinHash != null && profile.duressPinHash!.isNotEmpty) {
        storedHash = profile.duressPinHash;
        try {
          await _secureStorage
              .write(key: 'duress_pin_hash', value: storedHash)
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
      } else {
        // Tandai bahwa duress PIN tidak diatur sehingga unlock berikutnya 0ms tanpa request HTTP
        try {
          await _secureStorage
              .write(key: 'duress_pin_hash', value: 'none')
              .timeout(const Duration(seconds: 1));
        } catch (_) {}
        return false;
      }
    }

    if (storedHash != null && storedHash.isNotEmpty && storedHash != 'none') {
      // Backward compatibility: If stored hash doesn't contain ':', it's legacy SHA-256.
      if (!storedHash.contains(':')) {
        final bytes = utf8.encode(pin);
        final legacyHash = crypto.sha256.convert(bytes).toString();
        if (storedHash == legacyHash) {
          // Transparently upgrade to Argon2id in background
          setDuressPIN(pin);
          return true;
        }
        return false;
      }

      final salt = _extractSalt(storedHash);
      final enteredHash = await _hashPIN(pin, salt: salt);
      return storedHash == enteredHash;
    }

    return false;
  }

  Future<void> saveDuressUnlockStatus(bool wasDuress) async {
    try {
      if (wasDuress) {
        await _secureStorage.write(
          key: 'last_unlock_was_duress',
          value: 'true',
        );
      } else {
        await _secureStorage.delete(key: 'last_unlock_was_duress');
      }
    } catch (_) {}
  }

  Future<bool> getDuressUnlockStatus() async {
    try {
      final val = await _secureStorage.read(key: 'last_unlock_was_duress');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> disableDuressPIN() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    try {
      await _secureStorage
          .write(key: 'duress_pin_hash', value: 'none')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      await _supabaseService.client
          .from('profiles')
          .update({'duress_enabled': false, 'duress_pin_hash': null})
          .eq('id', userId);
    } catch (_) {}
  }

  // ── Decoy PIN (PIN Tamu / Decoy) ──────────────────────────
  // PIN terpisah yang digunakan saat meminjamkan ponsel ke pihak ketiga.
  // Membuka database decoy lokal tanpa memicu sinyal darurat SOS.

  Future<void> setDecoyPIN(String pin) async {
    final pinHash = await _hashPIN(pin);
    try {
      await _secureStorage
          .write(key: 'decoy_pin_hash', value: pinHash)
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  Future<bool> isDecoyEnabled() async {
    try {
      final local = await _secureStorage
          .read(key: 'decoy_pin_hash')
          .timeout(const Duration(seconds: 1));
      return local != null && local.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> validateDecoyPIN(String pin) async {
    String? storedHash;
    try {
      storedHash = await _secureStorage
          .read(key: 'decoy_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    if (storedHash != null && storedHash.isNotEmpty) {
      if (!storedHash.contains(':')) {
        final bytes = utf8.encode(pin);
        final legacyHash = crypto.sha256.convert(bytes).toString();
        if (storedHash == legacyHash) {
          setDecoyPIN(pin);
          return true;
        }
        return false;
      }
      final salt = _extractSalt(storedHash);
      final enteredHash = await _hashPIN(pin, salt: salt);
      return storedHash == enteredHash;
    }
    return false;
  }

  Future<void> disableDecoyPIN() async {
    try {
      await _secureStorage
          .delete(key: 'decoy_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  // ── Unlock Mode Persistence ──────────────────────────────
  Future<void> saveUnlockMode(String mode) async {
    try {
      await _secureStorage.write(key: 'last_unlock_mode', value: mode);
      if (mode == 'duress') {
        await _secureStorage.write(
          key: 'last_unlock_was_duress',
          value: 'true',
        );
      } else {
        await _secureStorage.delete(key: 'last_unlock_was_duress');
      }
    } catch (_) {}
  }

  Future<String> getUnlockMode() async {
    try {
      final mode = await _secureStorage.read(key: 'last_unlock_mode');
      if (mode != null && mode.isNotEmpty) return mode;
      final duress = await _secureStorage.read(key: 'last_unlock_was_duress');
      if (duress == 'true') return 'duress';
      return 'master';
    } catch (_) {
      return 'master';
    }
  }

  /// Dapatkan waktu server terverifikasi (UTC) untuk menghindari manipulasi jam lokal
  Future<DateTime> getServerTime() async {
    try {
      if (SupabaseService.isInitialized) {
        final res = await _supabaseService.client.rpc('get_server_time');
        if (res != null) {
          return DateTime.parse(res as String).toUtc();
        }
      }
    } catch (_) {}
    return DateTime.now().toUtc();
  }

  // ── Persistent PIN Lockout & 2FA State ──────────────────────
  Future<void> savePinLockout(int attempts, DateTime? lockedUntil) async {
    try {
      await _secureStorage.write(
        key: 'pin_attempts',
        value: attempts.toString(),
      );
      if (lockedUntil != null) {
        await _secureStorage.write(
          key: 'pin_locked_until',
          value: lockedUntil.toUtc().toIso8601String(),
        );
      } else {
        await _secureStorage.delete(key: 'pin_locked_until');
      }
    } catch (e) {
      debugPrint('Error saving PIN lockout state: $e');
    }
  }

  Future<Map<String, dynamic>> getPinLockout() async {
    try {
      final attemptsStr = await _secureStorage.read(key: 'pin_attempts');
      final lockedUntilStr = await _secureStorage.read(key: 'pin_locked_until');

      final attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
      DateTime? lockedUntil;
      if (lockedUntilStr != null && lockedUntilStr.isNotEmpty) {
        lockedUntil = DateTime.tryParse(lockedUntilStr)?.toUtc();
      }

      return {'attempts': attempts, 'lockedUntil': lockedUntil};
    } catch (_) {
      return {'attempts': 0, 'lockedUntil': null};
    }
  }

  Future<void> clearPinLockout() async {
    try {
      await _secureStorage.delete(key: 'pin_attempts');
      await _secureStorage.delete(key: 'pin_locked_until');
    } catch (_) {}
  }

  Future<void> save2faVerified(bool verified) async {
    try {
      if (verified) {
        await _secureStorage.write(key: '2fa_verified_session', value: 'true');
      } else {
        await _secureStorage.delete(key: '2fa_verified_session');
      }
    } catch (_) {}
  }

  Future<bool> is2faVerified() async {
    try {
      final val = await _secureStorage.read(key: '2fa_verified_session');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }
}
