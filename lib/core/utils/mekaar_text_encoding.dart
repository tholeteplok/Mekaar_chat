import 'dart:convert';
import 'package:flutter/widgets.dart';

/// Utilitas terpusat untuk penanganan multi-encoding byte teks, grapheme cluster,
/// sanitasi karakter berbahaya (Bidi spoofing & unpaired surrogates), serta
/// deteksi arah tulisan (RTL/LTR) di seluruh aplikasi MEKAAR.
class MekaarTextEncoding {
  MekaarTextEncoding._();

  /// Pola regex untuk menghapus karakter kontrol Bidi, zero-width spoofing,
  /// BOM, serta karakter kontrol ASCII (`0x00–0x1F`, `0x7F`).
  static final RegExp _unsafeFileNameChars = RegExp(
    r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
  );

  /// Pola untuk membersihkan karakter tak terlihat / kontrol di awal grapheme inisial.
  static final RegExp _leadingInvisibleChars = RegExp(
    r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
  );

  /// Pemetaan kode Windows-1252 (CP1252) pada rentang `0x80–0x9F` ke Unicode.
  static const Map<int, int> _cp1252Map = {
    0x80: 0x20AC, // €
    0x82: 0x201A, // ‚
    0x83: 0x0192, // ƒ
    0x84: 0x201E, // „
    0x85: 0x2026, // …
    0x86: 0x2020, // †
    0x87: 0x2021, // ‡
    0x88: 0x02C6, // ˆ
    0x89: 0x2030, // ‰
    0x8A: 0x0160, // Š
    0x8B: 0x2039, // ‹
    0x8C: 0x0152, // Œ
    0x8E: 0x017D, // Ž
    0x91: 0x2018, // ‘
    0x92: 0x2019, // ’
    0x93: 0x201C, // “
    0x94: 0x201D, // ”
    0x95: 0x2022, // •
    0x96: 0x2013, // –
    0x97: 0x2014, // —
    0x98: 0x02DC, // ˜
    0x99: 0x2122, // ™
    0x9A: 0x0161, // š
    0x9B: 0x203A, // ›
    0x9C: 0x0153, // œ
    0x9E: 0x017E, // ž
    0x9F: 0x0178, // Ÿ
  };

  /// Mendekode [bytes] teks lintas platform dengan deteksi otomatis:
  /// 1. UTF-8 BOM (`EF BB BF`)
  /// 2. UTF-16 LE BOM (`FF FE`) dan UTF-16 BE BOM (`FE FF`)
  /// 3. Heuristik UTF-16 LE/BE tanpa BOM
  /// 4. Strict UTF-8
  /// 5. Fallback Windows-1252 (CP1252) / ISO-8859-1 (Latin-1)
  static String decodeBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // 1. UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      final payload = bytes.sublist(3);
      return _decodeUtf8OrCp1252(payload);
    }

    // 2. UTF-16 LE BOM (FF FE)
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes, startOffset: 2, littleEndian: true);
    }

    // 3. UTF-16 BE BOM (FE FF)
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes, startOffset: 2, littleEndian: false);
    }

    // 4. Deteksi heuristik UTF-16 tanpa BOM (berbasis pola null-byte ASCII)
    if (bytes.length >= 4 && bytes.length.isEven) {
      final pairs = bytes.length ~/ 2;
      int oddNulls = 0;
      int evenNulls = 0;
      for (int i = 0; i < bytes.length; i += 2) {
        if ((bytes[i] & 0xFF) == 0) evenNulls++;
        if ((bytes[i + 1] & 0xFF) == 0) oddNulls++;
      }
      final oddRatio = oddNulls / pairs;
      final evenRatio = evenNulls / pairs;

      if (oddRatio >= 0.30 && evenRatio < 0.10) {
        return _decodeUtf16(bytes, startOffset: 0, littleEndian: true);
      }
      if (evenRatio >= 0.30 && oddRatio < 0.10) {
        return _decodeUtf16(bytes, startOffset: 0, littleEndian: false);
      }
    }

    // 5. Strict UTF-8 lalu fallback CP1252/Latin-1
    return _decodeUtf8OrCp1252(bytes);
  }

  static String _decodeUtf8OrCp1252(List<int> bytes) {
    if (bytes.isEmpty) return '';
    try {
      return sanitizeUnpairedSurrogates(
        utf8.decode(bytes, allowMalformed: false),
      );
    } on FormatException {
      return _decodeWindows1252(bytes);
    }
  }

  static String _decodeUtf16(
    List<int> bytes, {
    required int startOffset,
    required bool littleEndian,
  }) {
    if (bytes.length <= startOffset) return '';
    final units = <int>[];
    int i = startOffset;
    while (i + 1 < bytes.length) {
      final b0 = bytes[i] & 0xFF;
      final b1 = bytes[i + 1] & 0xFF;
      final unit = littleEndian ? (b0 | (b1 << 8)) : ((b0 << 8) | b1);
      units.add(unit);
      i += 2;
    }
    if (i < bytes.length) {
      // Byte ganjil tersisa di ujung stream UTF-16 diganti U+FFFD
      units.add(0xFFFD);
    }
    return sanitizeUnpairedSurrogates(String.fromCharCodes(units));
  }

  static String _decodeWindows1252(List<int> bytes) {
    final codePoints = List<int>.generate(bytes.length, (index) {
      final b = bytes[index] & 0xFF;
      if (b >= 0x80 && b <= 0x9F) {
        return _cp1252Map[b] ?? 0xFFFD;
      }
      return b;
    });
    return String.fromCharCodes(codePoints);
  }

  /// Mengambil grapheme cluster pertama yang aman dari pemotongan surrogate pair UTF-16
  /// (mis. emoji `💬`, bendera `🇮🇩`, atau aksara dengan combining marks).
  static String firstGrapheme(String? text, {String fallback = '?'}) {
    if (text == null || text.isEmpty) return fallback;
    final sanitized = sanitizeUnpairedSurrogates(text)
        .replaceAll(_leadingInvisibleChars, '')
        .trim();
    if (sanitized.isEmpty) return fallback;
    return sanitized.characters.first.toUpperCase();
  }

  /// Mengganti UTF-16 high/low surrogate yatim (*unpaired surrogates*) menjadi
  /// karakter pengganti `\uFFFD` agar aman untuk serialisasi JSON, UTF-8, dan SQLite.
  static String sanitizeUnpairedSurrogates(String text) {
    if (text.isEmpty) return text;
    final units = text.codeUnits;
    final len = units.length;
    List<int>? fixed;

    int i = 0;
    while (i < len) {
      final u = units[i];
      if (u >= 0xD800 && u <= 0xDBFF) {
        if (i + 1 < len && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF) {
          if (fixed != null) {
            fixed.add(u);
            fixed.add(units[i + 1]);
          }
          i += 2;
          continue;
        }
        fixed ??= units.sublist(0, i).toList();
        fixed.add(0xFFFD);
        i += 1;
        continue;
      }
      if (u >= 0xDC00 && u <= 0xDFFF) {
        fixed ??= units.sublist(0, i).toList();
        fixed.add(0xFFFD);
        i += 1;
        continue;
      }
      if (fixed != null) {
        fixed.add(u);
      }
      i += 1;
    }

    return fixed == null ? text : String.fromCharCodes(fixed);
  }

  /// Membersihkan nama berkas dari karakter kontrol Bidirectional (seperti RLO `U+202E`),
  /// karakter zero-width, BOM, dan kontrol ASCII untuk mencegah *extension spoofing*.
  static String sanitizeFileName(
    String? rawFileName, {
    String fallback = 'Berkas Dokumen',
  }) {
    if (rawFileName == null) return fallback;
    final cleaned = sanitizeUnpairedSurrogates(rawFileName)
        .replaceAll(_unsafeFileNameChars, '')
        .trim();
    if (cleaned.isEmpty) return fallback;
    return cleaned;
  }

  /// Mendeteksi arah tulisan berdasarkan karakter berarah kuat pertama
  /// (*first strong directional character*). Mengembalikan [TextDirection.rtl]
  /// untuk teks Arab/Ibrani/Thaana/Syriac dan [TextDirection.ltr] untuk lainnya.
  static TextDirection detectTextDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;

    for (final rune in text.runes) {
      // Abaikan spasi, kontrol, tanda baca ASCII, angka, dan karakter Bidi/ZWJ
      if (rune <= 0x40 ||
          (rune >= 0x5B && rune <= 0x60) ||
          (rune >= 0x7B && rune <= 0xBF) ||
          (rune >= 0x2000 && rune <= 0x2BFF) ||
          rune == 0xFEFF ||
          (rune >= 0xFE00 && rune <= 0xFE0F) ||
          (rune >= 0x1F000 && rune <= 0x1FAFF)) {
        continue;
      }

      // Blok skrip RTL kuat: Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan,
      // Mandaic, Arabic Extended, dan Arabic/Hebrew Presentation Forms.
      if ((rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFE)) {
        return TextDirection.rtl;
      }

      // Karakter huruf berarah kuat lainnya adalah LTR
      return TextDirection.ltr;
    }

    return TextDirection.ltr;
  }
}
