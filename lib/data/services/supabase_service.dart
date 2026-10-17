import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/validators.dart';

class SupabaseService {
  static bool isInitialized = false;
  static String? initializationError;

  static bool get hasConfigurationError {
    return !isInitialized && initializationError != null;
  }

  static void markInitialized() {
    isInitialized = true;
    initializationError = null;
  }

  static void markInitializationFailed(String message) {
    isInitialized = false;
    initializationError = message;
  }

  SupabaseClient get client {
    if (!isInitialized) {
      throw Exception(
        initializationError ??
            'Koneksi database tidak aktif. Pastikan konfigurasi Supabase sudah benar.',
      );
    }
    return Supabase.instance.client;
  }

  User? get currentUser {
    if (!isInitialized) return null;
    return client.auth.currentUser;
  }

  /// ID pengguna aktif saat ini.
  /// Mengembalikan `null` jika pengguna belum login atau jika ID bernilai cacat (misal 'undefined').
  String? get currentUserId {
    final id = currentUser?.id;
    if (id == null || !MekaarValidators.isValidUuid(id)) {
      return null;
    }
    return id;
  }
}
