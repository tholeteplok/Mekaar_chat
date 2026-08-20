import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/repositories/reconnect_policy.dart';

void main() {
  group('ReconnectPolicy', () {
    const policy = ReconnectPolicy();

    test('backoff eksponensial: 1s, 2s, 4s', () {
      expect(policy.delayForAttempt(1), const Duration(seconds: 1));
      expect(policy.delayForAttempt(2), const Duration(seconds: 2));
      expect(policy.delayForAttempt(3), const Duration(seconds: 4));
    });

    test('delay ter-cap di 8 detik', () {
      expect(policy.delayForAttempt(4), const Duration(seconds: 8));
      expect(policy.delayForAttempt(5), const Duration(seconds: 8));
      expect(policy.delayForAttempt(10), const Duration(seconds: 8));
    });

    test('maksimal 3 percobaan otomatis secara default', () {
      expect(policy.maxAttempts, 3);
    });

    test('konfigurasi kustom maxAttempts & baseDelay dihormati', () {
      const custom = ReconnectPolicy(maxAttempts: 2, baseDelay: Duration(milliseconds: 500));
      expect(custom.maxAttempts, 2);
      expect(custom.delayForAttempt(1), const Duration(milliseconds: 500));
      expect(custom.delayForAttempt(2), const Duration(seconds: 1));
    });
  });
}