import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/widgets/mekaar_tab_header.dart';
import 'package:mekaar_chat/core/widgets/mekaar_wordmark.dart';

Widget _host(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: themeMode,
    home: Scaffold(body: SafeArea(child: child)),
  );
}

void main() {
  group('MekaarWordmark', () {
    testWidgets('memakai dua segmen warna brand dan satu label semantics', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MekaarWordmark()));

      final richText = tester.widget<RichText>(find.byType(RichText));
      final root = richText.text as TextSpan;
      final segments = root.children!.cast<TextSpan>();

      expect(segments[0].text, 'Mek');
      expect(segments[0].style?.color, MekaarColors.yellow);
      expect(segments[1].text, 'aar');
      expect(segments[1].style?.color, MekaarColors.cyan);
      expect(find.bySemanticsLabel('Mekaar'), findsOneWidget);
    });

    testWidgets('mengikuti ukuran hero dan compact tanpa overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [MekaarWordmark(), MekaarWordmark(fontSize: 30)],
          ),
        ),
      );

      final texts = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text as TextSpan)
          .toList();

      expect(texts[0].style?.fontSize, 38);
      expect(texts[1].style?.fontSize, 30);
      expect(tester.takeException(), isNull);
    });
  });

  group('MekaarTabHeader', () {
    testWidgets('menampilkan title dan action opsional', (tester) async {
      await tester.pumpWidget(
        _host(
          const MekaarTabHeader(
            title: 'Pesan',
            action: IconButton(
              onPressed: null,
              icon: Icon(Icons.shield_outlined),
            ),
          ),
        ),
      );

      expect(find.text('Pesan'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('render stabil pada tema ${mode.name}', (tester) async {
        await tester.pumpWidget(
          _host(const MekaarTabHeader(title: 'Pengaturan'), themeMode: mode),
        );

        expect(find.text('Pengaturan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
