import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/error_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorResolver Tests', () {
    test('Timeout errors return human friendly Indonesian message with [ERR_TIMEOUT]', () {
      final msg1 = ErrorResolver.resolve(TimeoutException('Timed out'));
      expect(msg1, contains('Koneksi internet lambat'));
      expect(msg1, contains('[ERR_TIMEOUT]'));

      final msg2 = ErrorResolver.resolve('RealtimeSubscribeException(status: timedOut, details: null)');
      expect(msg2, contains('Koneksi internet lambat'));
      expect(msg2, contains('[ERR_TIMEOUT]'));
    });

    test('Network/Socket errors return human friendly Indonesian message with [ERR_NETWORK]', () {
      final msg1 = ErrorResolver.resolve(const SocketException('Failed host lookup'));
      expect(msg1, contains('Tidak dapat terhubung ke internet'));
      expect(msg1, contains('[ERR_NETWORK]'));

      final msg2 = ErrorResolver.resolve('ClientException: XMLHttpRequest error');
      expect(msg2, contains('Tidak dapat terhubung ke internet'));
      expect(msg2, contains('[ERR_NETWORK]'));
    });

    test('Supabase Realtime channel errors return [ERR_REALTIME]', () {
      final msg = ErrorResolver.resolve('Channel error occurred in realtime subscription');
      expect(msg, contains('Gagal menyinkronkan data secara langsung'));
      expect(msg, contains('[ERR_REALTIME]'));
    });

    test('Postgrest (Database) errors return [ERR_SERVER_DATA]', () {
      final msg = ErrorResolver.resolve(
        const PostgrestException(message: 'relation does not exist', code: '42P01'),
      );
      expect(msg, contains('Gagal memproses data di server'));
      expect(msg, contains('[ERR_SERVER_DATA]'));
    });

    test('Auth errors return [ERR_AUTH]', () {
      final msg = ErrorResolver.resolve(
        const AuthException('Invalid login credentials'),
      );
      expect(msg, contains('Invalid login credentials'));
      expect(msg, contains('[ERR_AUTH]'));
    });

    test('E2EE Crypto errors return [ERR_SECURITY_E2EE]', () {
      final msg = ErrorResolver.resolve('Gagal dekripsi pesan E2EE');
      expect(msg, contains('Kendala pada enkripsi keamanan obrolan'));
      expect(msg, contains('[ERR_SECURITY_E2EE]'));
    });

    test('Generic fallback returns [ERR_LOAD_FAILED]', () {
      final msg = ErrorResolver.resolve(Exception('Unexpected error'));
      expect(msg, contains('Terjadi kendala saat memuat data'));
      expect(msg, contains('[ERR_LOAD_FAILED]'));
    });

    test('Null error returns [ERR_UNKNOWN]', () {
      final msg = ErrorResolver.resolve(null);
      expect(msg, contains('Terjadi kendala yang tidak diketahui'));
      expect(msg, contains('[ERR_UNKNOWN]'));
    });
  });
}
