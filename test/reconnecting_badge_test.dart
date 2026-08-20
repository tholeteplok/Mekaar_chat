import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/features/chat/screens/chat_screen.dart';

void main() {
  testWidgets('ReconnectingBadge menampilkan indikator "Menyambung ulang…"',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReconnectingBadge()),
      ),
    );

    expect(find.text('Menyambung ulang…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}