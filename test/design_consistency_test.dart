import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    testWidgets('memakai teks Mekaar satu warna brand.blue dan label semantics', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MekaarWordmark()));

      expect(find.text('Mekaar'), findsOneWidget);
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
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == 'Mekaar')
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
