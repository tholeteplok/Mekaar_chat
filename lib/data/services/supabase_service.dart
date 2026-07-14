import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool isInitialized = false;

  SupabaseClient get client {
    if (!isInitialized) {
      throw Exception("Koneksi database tidak aktif. Pastikan file .env Anda telah dikonfigurasi dengan benar.");
    }
    return Supabase.instance.client;
  }

  User? get currentUser {
    if (!isInitialized) return null;
    return client.auth.currentUser;
  }
  
  String? get currentUserId => currentUser?.id;
}
