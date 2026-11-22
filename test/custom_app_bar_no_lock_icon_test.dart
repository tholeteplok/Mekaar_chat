import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/custom_app_bar.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  testWidgets('CustomAppBar tidak menampilkan ikon gembok di sebelah judul', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: CustomAppBar(
            isMaterialHeader: true,
            title: 'Salma',
            avatarInitial: 'S',
            showOnlineIndicator: true,
            subtitle: 'Terakhir dilihat 14:18',
          ),
        ),
      ),
    );

    expect(find.text('Salma'), findsOneWidget);
    expect(find.byIcon(SolarIconsBold.lockKeyhole), findsNothing);
  });
}
