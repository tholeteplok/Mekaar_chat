import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/emoji_shortcode_parser.dart';

void main() {
  group('parseEmojiContent', () {
    test('teks polos tanpa token', () {
      final segs = parseEmojiContent('Hai, apa kabar?');
      expect(segs.length, 1);
      expect(segs.single, isA<TextSegment>());
    });

    test('token tunggal', () {
      final segs = parseEmojiContent(':mika_wave:');
      expect(segs.single, isA<CustomEmojiSegment>());
      expect((segs.single as CustomEmojiSegment).slug, 'mika_wave');
    });

    test('campuran teks dan token', () {
      final segs = parseEmojiContent('Hai :mika_wave: selamat pagi!');
      expect(segs, hasLength(3));
      expect((segs[0] as TextSegment).text, 'Hai ');
      expect((segs[1] as CustomEmojiSegment).slug, 'mika_wave');
      expect((segs[2] as TextSegment).text, ' selamat pagi!');
    });

    test('beberapa token berurutan dengan pemisah', () {
      final segs = parseEmojiContent(':a1::b_2:');
      // ':a1:' lalu ':b_2:' — tanpa teks di antara.
      final customs = segs.whereType<CustomEmojiSegment>().toList();
      expect(customs.map((c) => c.slug), ['a1', 'b_2']);
    });

    test('kolon ganda di depan jadi teks + token: ::weird:', () {
      final segs = parseEmojiContent('::weird:');
      expect((segs[0] as TextSegment).text, ':');
      expect((segs[1] as CustomEmojiSegment).slug, 'weird');
    });

    test('slug satu karakter ditolak (min 2)', () {
      final segs = parseEmojiContent(':x:');
      expect(segs.whereType<CustomEmojiSegment>(), isEmpty);
    });

    test('huruf besar ditolak (kontrak lowercase)', () {
      final segs = parseEmojiContent(':MikaWave:');
      expect(segs.whereType<CustomEmojiSegment>(), isEmpty);
    });

    test('angka & underscore valid', () {
      final segs = parseEmojiContent(':mika_wave_v2:');
      expect(
        (segs.single as CustomEmojiSegment).slug,
        'mika_wave_v2',
      );
    });

    test('string kosong aman', () {
      final segs = parseEmojiContent('');
      expect(segs, isNotEmpty);
    });
  });

  group('isSingleCustomEmoji', () {
    test('true untuk token tunggal murni', () {
      expect(isSingleCustomEmoji(':mika_wave:'), isTrue);
      expect(isSingleCustomEmoji(' :mika_wave: '), isTrue);
    });

    test('false bila ada teks tambahan', () {
      expect(isSingleCustomEmoji('hai :mika_wave:'), isFalse);
      expect(isSingleCustomEmoji(':mika_wave: hai'), isFalse);
    });

    test('false untuk dua token', () {
      expect(isSingleCustomEmoji(':aa: :bb:'), isFalse);
    });
  });

  group('replaceCustomEmojiTokens', () {
    test('ganti semua token dikenal', () {
      final out =
          replaceCustomEmojiTokens('x :mika_wave: y :zzz:', (_) => '[emoji]');
      expect(out, 'x [emoji] y [emoji]');
    });

    test('format bersih untuk notifikasi dan pratinjau pesan terakhir', () {
      expect(
        replaceCustomEmojiTokens('Halo :mika_wave: apa kabar?', (_) => '[emoji]'),
        'Halo [emoji] apa kabar?',
      );
      expect(
        replaceCustomEmojiTokens(':mika_love:', (_) => '[emoji]'),
        '[emoji]',
      );
    });
  });

  group('countCustomEmojiTokens', () {
    test('menghitung jumlah token custom emoji dengan benar', () {
      expect(countCustomEmojiTokens('Hai :mika_1: dan :mika_2:!'), 2);
      expect(countCustomEmojiTokens('Teks biasa tanpa token'), 0);
      expect(countCustomEmojiTokens(':satu: :dua: :tiga:'), 3);
    });
  });
}
