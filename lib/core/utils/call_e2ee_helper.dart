import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helper untuk menghasilkan sidik jari E2EE (End-to-End Encryption) visual
/// berbasis 4 emoji ala Telegram untuk validasi keamanan panggilan WebRTC.
class CallE2eeHelper {
  CallE2eeHelper._();

  /// 128 emoji universal terpilih yang mudah dibedakan dan didukung luas di seluruh OS.
  static const List<String> emojiList = [
    // Buah & Makanan (16)
    '🍎', '🍌', '🍇', '🍓', '🍒', '🍍', '🍑', '🍉',
    '🍋', '🥑', '🥕', '🌽', '🍕', '🍔', '🍩', '🍦',
    // Hewan (16)
    '🐶', '🐱', '🐭', '🦊', '🐻', '🐼', '🦁', '🐯',
    '🐨', '🐵', '🐸', '🐙', '🦋', '🐝', '🐬', '🦉',
    // Alam & Cuaca (16)
    '☀️', '🌙', '⭐', '⚡', '🌈', '❄️', '🔥', '🌊',
    '🌸', '🍀', '🌲', '🌴', '🍁', '🍄', '🌍', '🪐',
    // Transportasi & Teknologi (16)
    '🚀', '🚗', '✈️', '🚲', '⛵', '🛸', '🔑', '🔔',
    '💎', '💡', '⏰', '🛡️', '🧭', '🎯', '🎨', '🎸',
    // Permainan & Rekreasi (16)
    '⚽', '🏀', '🎾', '🎲', '🏆', '🥇', '🎪', '🎭',
    '🧩', '🪁', '🏹', '🛹', '🛷', '🎳', '🥊', '🥋',
    // Simbol & Ikon Unik (16)
    '❤️', '💙', '💚', '💛', '💜', '🧡', '🤍', '💖',
    '🌟', '✨', '⚓', '🪄', '🪶', '🪔', '🧿', '👑',
    // Objek Sehari-hari (16)
    '☕', '🍰', '🍪', '🍫', '🍿', '🧁', '🎁', '🎈',
    '📷', '🔭', '🎧', '📻', '🔋', '🕯️', '📦', '🏷️',
    // Bunga & Tanaman Tambahan (16)
    '🌻', '🌺', '🌷', '💐', '🌾', '🌿', '🌱', '🌵',
    '🪴', '🎋', '🎍', '🍂', '🍃', '🪻', '🪷', '🪸',
  ];

  /// Menghasilkan 4 emoji deterministik dari parameter panggilan.
  /// Urutan [userId1] dan [userId2] diurutkan secara leksikografis sehingga
  /// kedua belah pihak (pemanggil dan penerima) menghasilkan 4 emoji yang persis sama.
  static List<String> getCallEmojis({
    required String callId,
    required String userId1,
    required String userId2,
    String? sdpFingerprint,
  }) {
    final sortedUsers = [userId1.trim(), userId2.trim()]..sort();
    final rawSeed = '$callId:${sortedUsers[0]}:${sortedUsers[1]}${sdpFingerprint != null ? ':$sdpFingerprint' : ''}';

    final bytes = utf8.encode(rawSeed);
    final digest = sha256.convert(bytes);
    final hashBytes = digest.bytes;

    final emojis = <String>[];
    final total = emojiList.length;

    // Ambil 4 pasang byte (2 byte per emoji) untuk distribusi yang merata
    for (int i = 0; i < 4; i++) {
      final val = (hashBytes[i * 2] << 8) | hashBytes[i * 2 + 1];
      final index = val % total;
      emojis.add(emojiList[index]);
    }

    return emojis;
  }
}
