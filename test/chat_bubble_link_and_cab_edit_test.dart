import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/widgets/mekaar_link_text.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_selection_app_bar.dart';

void main() {
  group('ChatBubble Link & Contextual Action Bar Edit Tests', () {
    testWidgets('MekaarLinkText mendeteksi URL dan merender RichText dengan TextSpan link', (tester) async {
      const sampleText = 'Silakan kunjungi https://mekaar.id untuk panduan resmi.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MekaarLinkText(
              text: sampleText,
              baseStyle: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ),
      );

      final richTextFinder = find.descendant(
        of: find.byType(MekaarLinkText),
        matching: find.byType(RichText),
      );
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      final outerSpan = richText.text as TextSpan;
      final textSpan = (outerSpan.children != null &&
              outerSpan.children!.length == 1 &&
              outerSpan.text == null)
          ? outerSpan.children!.first as TextSpan
          : outerSpan;

      // Verifikasi seluruh teks dan child spans
      expect(outerSpan.toPlainText(), equals(sampleText));
      expect(textSpan.children, isNotNull);
      expect(textSpan.children!.length, equals(3));

      // Verifikasi span link
      final linkSpan = textSpan.children![1] as TextSpan;
      expect(linkSpan.text, equals('https://mekaar.id'));
      expect(linkSpan.recognizer, isNotNull);
      expect(linkSpan.style?.decoration, equals(TextDecoration.underline));
    });

    testWidgets('MekaarLinkText merender Text biasa jika tidak ada URL', (tester) async {
      const sampleText = 'Halo apa kabar, ini pesan tanpa tautan.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MekaarLinkText(
              text: sampleText,
              baseStyle: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ),
      );

      expect(find.text(sampleText), findsOneWidget);
    });

    testWidgets('ChatSelectionAppBar menampilkan tombol Edit (Pensil) saat canEdit bernilai true', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatSelectionAppBar(
              selectedCount: 1,
              canEdit: true,
              canReply: true,
              onEdit: () {
                editTapped = true;
              },
              onClose: () {},
              onDelete: () {},
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        ),
      );

      // Pastikan icon pensil (SolarIconsOutline.pen) ditemukan
      final penIconFinder = find.byIcon(SolarIconsOutline.pen);
      expect(penIconFinder, findsOneWidget);

      // Tap tombol edit
      await tester.tap(penIconFinder);
      await tester.pump();

      expect(editTapped, isTrue);
    });

    testWidgets('ChatSelectionAppBar TIDAK menampilkan tombol Edit saat canEdit false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatSelectionAppBar(
              selectedCount: 2, // Multi-pesan, tidak boleh diedit
              canEdit: false,
              canReply: false,
              onClose: () {},
              onDelete: () {},
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        ),
      );

      expect(find.byIcon(SolarIconsOutline.pen), findsNothing);
    });
  });
}
