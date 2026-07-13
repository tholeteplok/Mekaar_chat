// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/app.dart';

void main() {
  testWidgets('MekaarApp build test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MekaarApp()));

    // Verify that the app builds without crashing.
    expect(find.byType(MekaarApp), findsOneWidget);

    // Pump timer to prevent pending timer assertion error
    await tester.pump(const Duration(seconds: 3));
  });
}
