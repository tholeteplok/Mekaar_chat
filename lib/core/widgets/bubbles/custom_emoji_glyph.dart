import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/chat/providers/emoji_pack_provider.dart';
import '../../constants/colors.dart';
import '../../constants/dimensions.dart';
import '../../utils/emoji_shortcode_parser.dart';

class EmojiPlaceholder extends StatelessWidget {
  final String slug;
  final double size;
  const EmojiPlaceholder({super.key, required this.slug, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: size, maxHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MekaarColors.surface2Of(context),
        borderRadius: BorderRadius.circular(MekaarRadius.sm),
      ),
      child: Center(
        child: Text(
          ':$slug:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (size * 0.18).clamp(9.0, 13.0),
            color: MekaarColors.textMutedOf(context),
            fontStyle: FontStyle.italic,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class CustomEmojiGlyph extends ConsumerWidget {
  final String slug;
  final double size;
  const CustomEmojiGlyph(
      {super.key, required this.slug, this.size = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(emojiCatalogProvider);
    final service = ref.read(emojiPackServiceProvider);

    return FutureBuilder<File?>(
      future: service.resolveLocalFile(slug),
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }

        // Jika pengecekan disk masih berjalan
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(width: size, height: size);
        }

        // Cek URL dari katalog jika belum terpasang lokal
        final url = ref.read(emojiCatalogProvider.notifier).urlFor(slug);
        if (url != null) {
          return Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                EmojiPlaceholder(slug: slug, size: size),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : SizedBox(width: size, height: size),
          );
        }

        // Sedang memuat katalog (offline atau initial startup)
        if (catalogAsync.isLoading) {
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: (size * 0.3).clamp(12.0, 24.0),
                height: (size * 0.3).clamp(12.0, 24.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MekaarColors.guardianTeal.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }

        // Katalog selesai dimuat namun slug tidak dikenal
        return EmojiPlaceholder(slug: slug, size: size);
      },
    );
  }
}

/// Konten teks campuran dengan token custom emoji inline.
class RichEmojiContent extends StatelessWidget {
  final String content;
  final TextStyle baseStyle;
  const RichEmojiContent(
      {super.key, required this.content, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final segments = parseEmojiContent(content);
    final inlineSize = baseStyle.fontSize != null
        ? baseStyle.fontSize! * 1.65
        : 28.0;
    final spans = <InlineSpan>[];
    for (final seg in segments) {
      switch (seg) {
        case TextSegment(:final text):
          if (text.isEmpty) break;
          spans.add(TextSpan(text: text));
        case CustomEmojiSegment(:final slug):
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: CustomEmojiGlyph(slug: slug, size: inlineSize),
              ),
            ),
          );
      }
    }
    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
