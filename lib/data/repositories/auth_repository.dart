import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  final SupabaseService _supabaseService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthRepository(this._supabaseService);

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

  // Resolve email from username via profiles table
  Future<String?> resolveEmailFromUsername(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    // Fast path: if it looks like an email, skip resolve
    if (clean.contains('@')) return clean;

    // Try RPC first (if migration 05 applied)
    try {
      final response = await _supabaseService.client.rpc(
        'search_public_profiles',
        params: {'search_query': clean},
      );
      if (response is List && response.isNotEmpty) {
        final email = (response.first as Map)['email'] as String?;
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (_) {}

    // Fallback direct query
    try {
      final response = await _supabaseService.client
          .from('profiles')
          .select('email')
          .eq('username', clean)
          .maybeSingle();
      if (response != null) {
        final email = response['email'] as String?;
        if (email != null && email.isNotEmpty) return email;
      }
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

  // Sign out
  Future<void> signOut() async {
    try {
      await _secureStorage
          .delete(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pin_hash');
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

  // Hash PIN helper
  String _hashPIN(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // Set PIN in database and local secure storage
  Future<void> setPIN(String pin) async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final pinHash = _hashPIN(pin);

    // Save locally with Keystore timeout-fallback for MIUI/unsupported devices
    try {
      await _secureStorage
          .write(key: 'pin_hash', value: pinHash)
          .timeout(const Duration(seconds: 1));
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pin_hash', pinHash);
    }

    // Save to remote profiles table
    await _supabaseService.client
        .from('profiles')
        .update({'pin_hash': pinHash})
        .eq('id', userId);
  }

  // Validate entered PIN against stored PIN
  Future<bool> validatePIN(String pin) async {
    final enteredHash = _hashPIN(pin);

    // Try reading local hash first (offline friendly) with Keystore timeout-fallback
    String? localHash;
    try {
      localHash = await _secureStorage
          .read(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        localHash = prefs.getString('pin_hash');
      } catch (_) {}
    }

    if (localHash != null) {
      return localHash == enteredHash;
    }

    // Fallback to remote database check
    final profile = await getProfile();
    if (profile != null && profile.pinHash.isNotEmpty) {
      // Update local storage so it's offline friendly next time
      try {
        await _secureStorage
            .write(key: 'pin_hash', value: profile.pinHash)
            .timeout(const Duration(seconds: 1));
      } catch (_) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pin_hash', profile.pinHash);
        } catch (_) {}
      }
      return profile.pinHash == enteredHash;
    }

    return false;
  }

  // Check if PIN has been set
  Future<bool> isPINSet() async {
    String? localHash;
    try {
      localHash = await _secureStorage
          .read(key: 'pin_hash')
          .timeout(const Duration(seconds: 1));
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        localHash = prefs.getString('pin_hash');
      } catch (_) {}
    }
    if (localHash != null && localHash.isNotEmpty) return true;

    final profile = await getProfile();
    return profile != null && profile.pinHash.isNotEmpty;
  }
}
