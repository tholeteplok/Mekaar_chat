import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:mekaar_chat/data/services/supabase_service.dart';
import 'app.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isDotEnvLoaded = false;
  // 1. Load Environment Variables
  try {
    await dotenv.load(fileName: ".env");
    isDotEnvLoaded = true;
    logger.i(".env loaded successfully");
  } catch (e) {
    final message =
        '.env belum terbaca. Pastikan .env terdaftar di pubspec.yaml assets dan lakukan full restart aplikasi.';
    SupabaseService.markInitializationFailed(message);
    logger.w("$message Error: $e");
  }

  // 2. Initialize Supabase
  if (isDotEnvLoaded) {
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    final configError = _validateSupabaseConfig(supabaseUrl, supabaseAnonKey);

    if (configError != null) {
      SupabaseService.markInitializationFailed(configError);
      logger.w(configError);
    } else {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
        SupabaseService.markInitialized();
        logger.i("Supabase initialized successfully");
      } catch (e) {
        final message =
            'Supabase gagal initialize. Periksa SUPABASE_URL, SUPABASE_ANON_KEY, dan koneksi ke server Supabase.';
        SupabaseService.markInitializationFailed(message);
        logger.e("$message Error: $e");
      }
    }
  }

  // 3. Run Application
  runApp(const ProviderScope(child: MekaarApp()));
}

String? _validateSupabaseConfig(String supabaseUrl, String supabaseAnonKey) {
  if (supabaseUrl.isEmpty) {
    return 'SUPABASE_URL kosong. Periksa file .env dan lakukan full restart aplikasi.';
  }

  if (supabaseAnonKey.isEmpty) {
    return 'SUPABASE_ANON_KEY kosong. Periksa file .env dan lakukan full restart aplikasi.';
  }

  final uri = Uri.tryParse(supabaseUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'SUPABASE_URL tidak valid. Gunakan URL Supabase lengkap dari project settings.';
  }

  if (uri.host == 'placeholder.supabase.co' ||
      supabaseAnonKey == 'placeholderKey') {
    return 'Konfigurasi Supabase masih memakai placeholder. Periksa file .env dan lakukan full restart aplikasi.';
  }

  if (!uri.host.endsWith('.supabase.co')) {
    return 'SUPABASE_URL tidak mengarah ke domain Supabase yang valid.';
  }

  return null;
}
