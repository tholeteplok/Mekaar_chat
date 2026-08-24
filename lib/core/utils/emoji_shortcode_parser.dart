/// Tokenizer shortcode custom emoji MEKAAR.
///
/// Format pesan: token `:slug:` di dalam content terenkripsi, dengan
/// slug lowercase `[a-z0-9_]{2,32}` (kontrak kolom emoji_pack_items).
/// Token yang tidak memenuhi pola tetap diperlakukan sebagai teks biasa.
library;

/// Satu potong hasil parsing konten.
sealed class EmojiSegment {
  const EmojiSegment();
}

class TextSegment extends EmojiSegment {
  final String text;
  const TextSegment(this.text);
}

/// Token `:slug:` valid secara bentuk. Apakah slug dikenal katalog
/// diputuskan di lapisan render (fallback = teks literal).
class CustomEmojiSegment extends EmojiSegment {
  final String slug;
  const CustomEmojiSegment(this.slug);
}

final RegExp _tokenPattern = RegExp(r':([a-z0-9_]{2,32}):');

/// Parse [content] menjadi deretan segmen teks & token custom emoji.
///
/// Contoh:
/// - 'Hai :mika_wave: !' → [Text(Hai ), Custom(mika_wave), Text( !)]
/// - '::weird:'          → [Text(::weird:)]  (bukan format token)
List<EmojiSegment> parseEmojiContent(String content) {
  if (content.isEmpty) return const [TextSegment('')];
  final segments = <EmojiSegment>[];
  var last = 0;
  for (final match in _tokenPattern.allMatches(content)) {
    if (match.start > last) {
      segments.add(TextSegment(content.substring(last, match.start)));
    }
    segments.add(CustomEmojiSegment(match.group(1)!));
    last = match.end;
  }
  if (last < content.length) {
    segments.add(TextSegment(content.substring(last)));
  }
  return segments;
}

/// Hitung jumlah token custom emoji dalam [content].
int countCustomEmojiTokens(String content) =>
    _tokenPattern.allMatches(content).length;

/// True bila [content] hanya berisi SATU token custom emoji
/// (dengan spasi opsional di sekeliling) → jalur render emoji-only besar.
bool isSingleCustomEmoji(String content) {
  final trimmed = content.trim();
  final m = _tokenPattern.firstMatch(trimmed);
  return m != null &&
      m.start == 0 &&
      m.end == trimmed.length;
}

/// Ganti setiap token custom emoji menggunakan [replacer].
/// Berguna untuk preview notifikasi/reply ('[emoji]').
String replaceCustomEmojiTokens(
  String content,
  String Function(String slug) replacer,
) {
  return content.replaceAllMapped(
    _tokenPattern,
    (m) => replacer(m.group(1)!),
  );
}
