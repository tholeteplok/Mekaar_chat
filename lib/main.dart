import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'app.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Load Environment Variables
  try {
    await dotenv.load(fileName: ".env");
    logger.i(".env loaded successfully");
  } catch (e) {
    logger.w("Warning: Could not load .env file. Using default values. Error: $e");
  }

  // 2. Initialize Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://placeholder.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'placeholderKey';

  if (supabaseUrl != 'https://placeholder.supabase.co' && supabaseAnonKey != 'placeholderKey') {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      logger.i("Supabase initialized successfully");
    } catch (e) {
      logger.e("Error initializing Supabase: $e. Running in offline/fallback mode.");
    }
  } else {
    logger.w("Supabase credentials not set in .env. Running in offline/fallback mode.");
  }

  // 3. Run Application
  runApp(
    const ProviderScope(
      child: MekaarApp(),
    ),
  );
}
