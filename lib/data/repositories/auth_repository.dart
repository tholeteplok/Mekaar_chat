import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    final user = response.user;
    if (user != null) {
      // Create initial profile in the database
      // The default pin_hash can be empty initially
      await _supabaseService.client.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'email': email,
        'pin_hash': '', // Empty until setup
      });
    }
    return user;
  }

  // Sign out
  Future<void> signOut() async {
    await _secureStorage.delete(key: 'pin_hash');
    await _supabaseService.client.auth.signOut();
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

    // Save locally
    await _secureStorage.write(key: 'pin_hash', value: pinHash);

    // Save to remote profiles table
    await _supabaseService.client
        .from('profiles')
        .update({'pin_hash': pinHash})
        .eq('id', userId);
  }

  // Validate entered PIN against stored PIN
  Future<bool> validatePIN(String pin) async {
    final enteredHash = _hashPIN(pin);

    // Try reading local hash first (offline friendly)
    final localHash = await _secureStorage.read(key: 'pin_hash');
    if (localHash != null) {
      return localHash == enteredHash;
    }

    // Fallback to remote database check
    final profile = await getProfile();
    if (profile != null && profile.pinHash.isNotEmpty) {
      // Update local storage so it's offline friendly next time
      await _secureStorage.write(key: 'pin_hash', value: profile.pinHash);
      return profile.pinHash == enteredHash;
    }

    return false;
  }

  // Check if PIN has been set
  Future<bool> isPINSet() async {
    final localHash = await _secureStorage.read(key: 'pin_hash');
    if (localHash != null && localHash.isNotEmpty) return true;

    final profile = await getProfile();
    return profile != null && profile.pinHash.isNotEmpty;
  }
}
