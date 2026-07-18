import 'dart:math';
import 'package:crypto/crypto.dart';

/// Utilitas TOTP (RFC 6238) mandiri — tanpa dependensi eksternal.
/// Used for Two-Factor Authentication (Verifikasi 2 Langkah).
class TotpUtil {
  static const int _digits = 6;
  static const int _period = 30;
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Generate secret base32 acak (16 karakter = 80 bit).
  static String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(10, (_) => random.nextInt(256));
    // 10 byte -> 16 char base32
    return _base32Encode(bytes);
  }

  /// Berikan otpauth URI untuk di-scan aplikasi authenticator.
  static String otpAuthUri(String account, String secret) {
    final label = Uri.encodeComponent(account);
    return 'otpauth://totp/MEKAAR:$label?secret=$secret&issuer=MEKAAR&period=$_period&digits=$_digits';
  }

  /// Hitung kode TOTP saat ini untuk secret tertentu.
  static String currentCode(String secret) {
    final counter = (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ _period;
    return _generateCode(secret, counter);
  }

  /// Verifikasi kode (toleransi ±1 interval untuk clock skew).
  static bool verify(String secret, String code) {
    final cleaned = code.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length != _digits) return false;
    final now = (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ _period;
    for (final counter in [now - 1, now, now + 1]) {
      if (_generateCode(secret, counter) == cleaned) return true;
    }
    return false;
  }

  // ──────────────────────────── intern ────────────────────────────
  static String _generateCode(String secret, int counter) {
    final key = _base32Decode(secret);
    final msg = [
      (counter >> 56) & 0xff,
      (counter >> 48) & 0xff,
      (counter >> 40) & 0xff,
      (counter >> 32) & 0xff,
      (counter >> 24) & 0xff,
      (counter >> 16) & 0xff,
      (counter >> 8) & 0xff,
      counter & 0xff,
    ];
    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(msg).bytes;
    final offset = hash.last & 0xf;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
    final otp = binary % pow(10, _digits).toInt();
    return otp.toString().padLeft(_digits, '0');
  }

  static List<int> _base32Decode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final bytes = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (final ch in clean.codeUnits) {
      final val = _base32Alphabet.indexOf(String.fromCharCode(ch));
      if (val < 0) continue;
      buffer = (buffer << 5) | val;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xff);
      }
    }
    return bytes;
  }

  static String _base32Encode(List<int> data) {
    final out = <String>[];
    var buffer = 0;
    var bitsLeft = 0;
    for (final b in data) {
      buffer = (buffer << 8) | b;
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        out.add(_base32Alphabet[(buffer >> bitsLeft) & 0x1f]);
      }
    }
    if (bitsLeft > 0) {
      out.add(_base32Alphabet[(buffer << (5 - bitsLeft)) & 0x1f]);
    }
    return out.join();
  }
}
