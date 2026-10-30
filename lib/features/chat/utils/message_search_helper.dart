import 'dart:math';
import 'package:flutter/material.dart';

/// Helper murni untuk operasi pencarian pesan (FTS5 query sanitizer & snippet generator).
/// Bebas dependensi jaringan dan framework backend.
class MessageSearchHelper {
  MessageSearchHelper._();

  static final RegExp _ftsSpecialChars = RegExp(r'["*\-():^+~]');
  static const Set<String> _ftsReservedKeywords = {'AND', 'OR', 'NOT', 'NEAR'};

  /// Membangun query FTS5 yang aman dari input pengguna.
  ///
  /// - Menghilangkan karakter khusus FTS (`"`, `*`, `-`, `(`, `)`, `:`, `^`, `+`, `~`).
  /// - Menghilangkan kata kunci operator FTS (`AND`, `OR`, `NOT`, `NEAR`).
  /// - Menolak query dengan total panjang token valid < 2 karakter (mengembalikan `null`).
  /// - Membungkus tiap token dalam tanda kutip dan memberi wildcard `*` pada token terakhir untuk prefix matching.
  ///
  /// Contoh: `halo dun` → `"halo" "dun"*`
  /// Contoh: `"a" OR b*` → `"a" "b"*`
  /// Contoh: `a` → `null` (kurang dari 2 karakter)
  static String? buildFtsQuery(String input) {
    final cleaned = input.replaceAll(_ftsSpecialChars, ' ').trim();
    if (cleaned.isEmpty) return null;

    final rawTokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final validTokens = <String>[];
    for (final token in rawTokens) {
      if (_ftsReservedKeywords.contains(token.toUpperCase())) {
        continue;
      }
      validTokens.add(token);
    }

    if (validTokens.isEmpty) return null;

    final totalLength = validTokens.fold<int>(0, (sum, t) => sum + t.length);
    if (totalLength < 2) return null;

    final buffer = StringBuffer();
    for (int i = 0; i < validTokens.length; i++) {
      final token = validTokens[i];
      // Escape tanda kutip ganda internal jika ada
      final escapedToken = token.replaceAll('"', '""');
      if (i == validTokens.length - 1) {
        buffer.write('"$escapedToken"*');
      } else {
        buffer.write('"$escapedToken" ');
      }
    }

    return buffer.toString().trim();
  }

  /// Membangun segmen cuplikan teks di sekitar kemunculan kata kunci pertama.
  static List<SearchSnippetSegment> buildSearchSnippetSegments(
    String text,
    String query, {
    int windowChars = 35,
  }) {
    final trimmedQuery = query.trim();
    if (text.isEmpty || trimmedQuery.length < 2) {
      return [SearchSnippetSegment(text: text, isMatch: false)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmedQuery.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      // Tidak ditemukan kecocokan persis pada string (misal stemming FTS)
      final maxLength = windowChars * 2;
      if (text.length <= maxLength) {
        return [SearchSnippetSegment(text: text, isMatch: false)];
      }
      return [
        SearchSnippetSegment(
          text: '${text.substring(0, maxLength)}...',
          isMatch: false,
        ),
      ];
    }

    final start = max(0, matchIndex - windowChars);
    final end = min(
      text.length,
      matchIndex + trimmedQuery.length + windowChars,
    );

    final hasPrefix = start > 0;
    final hasSuffix = end < text.length;

    final prefixText =
        (hasPrefix ? '...' : '') + text.substring(start, matchIndex);
    final matchText = text.substring(
      matchIndex,
      matchIndex + trimmedQuery.length,
    );
    final suffixText =
        text.substring(matchIndex + trimmedQuery.length, end) +
        (hasSuffix ? '...' : '');

    final segments = <SearchSnippetSegment>[];
    if (prefixText.isNotEmpty) {
      segments.add(SearchSnippetSegment(text: prefixText, isMatch: false));
    }
    segments.add(SearchSnippetSegment(text: matchText, isMatch: true));
    if (suffixText.isNotEmpty) {
      segments.add(SearchSnippetSegment(text: suffixText, isMatch: false));
    }

    return segments;
  }

  /// Menghasilkan daftar [InlineSpan] siap render untuk cuplikan pencarian.
  static List<InlineSpan> buildSearchSnippetSpans({
    required String text,
    required String query,
    required TextStyle normalStyle,
    required TextStyle matchStyle,
    int windowChars = 35,
  }) {
    final segments = buildSearchSnippetSegments(
      text,
      query,
      windowChars: windowChars,
    );

    return segments.map((seg) {
      return TextSpan(
        text: seg.text,
        style: seg.isMatch ? matchStyle : normalStyle,
      );
    }).toList();
  }
}

/// Representasi segmen cuplikan teks apakah merupakan kata kunci cocok atau teks normal.
class SearchSnippetSegment {
  final String text;
  final bool isMatch;

  const SearchSnippetSegment({required this.text, required this.isMatch});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSnippetSegment &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isMatch == other.isMatch;

  @override
  int get hashCode => text.hashCode ^ isMatch.hashCode;

  @override
  String toString() => 'SearchSnippetSegment(text: "$text", isMatch: $isMatch)';
}
