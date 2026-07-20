import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final SupabaseService _supabaseService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthRepository(this._supabaseService);

  Future<String?> uploadAndUpdateAvatar(File imageFile) async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final ext = imageFile.path.split('.').last;
      final fileName = 'avatar.$ext';
      final storagePath = '${user.id}/$fileName';

      // Upload to Supabase Storage bucket 'avatars'
      await _supabaseService.client.storage.from('avatars').upload(
        storagePath,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      // Get public URL
      final publicUrl = _supabaseService.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);
          
      // Add timestamp to avoid caching issues on client side
      final timestampUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

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

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    final response = await _supabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
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
    final email = await resolveEmailFromUsername(input);
    if (email == null) {
      throw Exception('User tidak ditemukan');
    }
    return signInWithEmail(email, password);
  }

  // Update username in profiles table
  Future<Profile> updateUsername(String username) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _supabaseService.client
        .from('profiles')
        .update({
          'username': username,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
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
    await _supabaseService.client.rpc(
      'enable_2fa',
      params: {'secret': secret},
    );
    final profile = await getProfile();
    if (profile == null) throw Exception('Profil tidak ditemukan');
    return profile;
  }

  // Disable 2FA: remove secret and deactivate.
  Future<Profile> disableTwoFa() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('Not authenticated');
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
    try {
      await _secureStorage
          .delete(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
      await _secureStorage
          .delete(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
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
    final actualSalt = salt ?? List<int>.generate(16, (i) => math.Random.secure().nextInt(256));
    
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

    await _supabaseService.client.from('profiles').update({
      'duress_pin_hash': pinHash,
      'duress_enabled': true,
    }).eq('id', userId);
  }

  Future<bool> isDuressEnabled() async {
    try {
      final local = await _secureStorage
          .read(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
      if (local != null && local.isNotEmpty) return true;
    } catch (_) {}
    final profile = await getProfile();
    return profile != null &&
        profile.pinHash.isNotEmpty &&
        (profile.duressPinHash?.isNotEmpty ?? false);
  }

  // Mengembalikan true bila [pin] cocok dengan duress PIN (bukan PIN utama).
  Future<bool> validateDuressPIN(String pin) async {
    String? storedHash;
    try {
      storedHash = await _secureStorage
          .read(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}

    if (storedHash == null || storedHash.isEmpty) {
      final profile = await getProfile();
      if (profile != null && profile.duressPinHash != null) {
        storedHash = profile.duressPinHash;
        try {
          await _secureStorage
              .write(key: 'duress_pin_hash', value: storedHash)
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

  Future<void> disableDuressPIN() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    try {
      await _secureStorage
          .delete(key: 'duress_pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      await _supabaseService.client
          .from('profiles')
          .update({'duress_enabled': false, 'duress_pin_hash': null}).eq('id', userId);
    } catch (_) {}
  }
}
