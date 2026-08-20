import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// ErrorResolver — Resolusi pesan error teknis menjadi bahasa manusia yang ramah,
/// dengan tetap menyertakan kode alias error ringkas (misal: `[ERR_TIMEOUT]`)
/// untuk mempermudah developer melakukan penelusuran masalah (debugging).
class ErrorResolver {
  /// Mengubah objek error teknis menjadi pesan yang mudah dipahami pengguna awam.
  ///
  /// Contoh:
  /// - `RealtimeSubscribeException(timedOut)` -> "Koneksi internet lambat atau terputus. Mohon periksa jaringan Anda lalu coba lagi. [ERR_TIMEOUT]"
  /// - `SocketException` -> "Tidak dapat terhubung ke internet. Pastikan perangkat Anda terhubung ke jaringan. [ERR_NETWORK]"
  /// - `PostgrestException` -> "Gagal memproses data di server. Silakan coba beberapa saat lagi. [ERR_SERVER_DATA]"
  static String resolve(
    dynamic error, {
    String defaultAction = 'Silakan coba beberapa saat lagi.',
  }) {
    if (error == null) {
      return 'Terjadi kendala yang tidak diketahui. $defaultAction [ERR_UNKNOWN]';
    }

    final errStr = error.toString().toLowerCase();

    // 1. Timeout / Realtime subscribe timeout
    if (errStr.contains('timedout') ||
        errStr.contains('timeout') ||
        error is TimeoutException) {
      return 'Koneksi internet lambat atau terputus. Mohon periksa jaringan Anda lalu coba lagi. [ERR_TIMEOUT]';
    }

    // 2. Network / Socket / Host lookup failure
    if (error is SocketException ||
        errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection reset') ||
        errStr.contains('clientexception')) {
      return 'Tidak dapat terhubung ke internet. Pastikan perangkat Anda terhubung ke jaringan. [ERR_NETWORK]';
    }

    // 3. Supabase Realtime errors
    if (errStr.contains('realtimesubscribeexception') ||
        errStr.contains('channel error') ||
        errStr.contains('realtime')) {
      return 'Gagal menyinkronkan data secara langsung. Periksa koneksi Anda lalu coba lagi. [ERR_REALTIME]';
    }

    // 4. Supabase Postgrest (Database) errors
    if (error is PostgrestException || errStr.contains('postgrestexception')) {
      return 'Gagal memproses data di server. $defaultAction [ERR_SERVER_DATA]';
    }

    // 5. Supabase Auth errors
    if (error is AuthException || errStr.contains('authexception')) {
      final msg = (error is AuthException) ? error.message : '';
      if (msg.isNotEmpty && !msg.toLowerCase().contains('exception')) {
        return '$msg [ERR_AUTH]';
      }
      return 'Sesi autentikasi bermasalah. Silakan masuk kembali jika kendala berlanjut. [ERR_AUTH]';
    }

    // 6. E2EE Crypto errors
    if (errStr.contains('e2ee') ||
        errStr.contains('crypto') ||
        errStr.contains('dekripsi') ||
        errStr.contains('enkripsi')) {
      return 'Kendala pada enkripsi keamanan obrolan. $defaultAction [ERR_SECURITY_E2EE]';
    }

    // 7. Fallback untuk error lain tanpa menampilkan stack trace mentah
    return 'Terjadi kendala saat memuat data. $defaultAction [ERR_LOAD_FAILED]';
  }
}
