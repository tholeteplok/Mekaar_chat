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
  Future<User?> signUpWithEmail(String email, String password, String username) async {
    final response = await _supabaseService.client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
      },
    );
    return response.user;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _secureStorage.delete(key: 'pin_hash').timeout(const Duration(seconds: 1));
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
      await _secureStorage.write(key: 'pin_hash', value: pinHash).timeout(const Duration(seconds: 1));
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
      localHash = await _secureStorage.read(key: 'pin_hash').timeout(const Duration(seconds: 1));
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
        await _secureStorage.write(key: 'pin_hash', value: profile.pinHash).timeout(const Duration(seconds: 1));
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
      localHash = await _secureStorage.read(key: 'pin_hash').timeout(const Duration(seconds: 1));
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
