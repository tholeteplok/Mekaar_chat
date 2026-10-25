import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/widgets/mekaar_top_bar.dart';
import 'package:mekaar_chat/features/settings/widgets/settings_tiles.dart';

void main() {
  group('MekaarTopBar & SettingsTopBar Sub-Screen Header Tests', () {
    testWidgets('Renders back button, title, and handles tap callback', (tester) async {
      bool backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MekaarTopBar(
              title: 'Info Kontak',
              onBack: () => backPressed = true,
            ),
            body: const Center(child: Text('Konten')),
          ),
        ),
      );

      // Verifikasi judul besar dan tombol kembali
      expect(find.text('Info Kontak'), findsOneWidget);
      expect(find.byIcon(SolarIconsOutline.altArrowLeft), findsOneWidget);

      // Ketuk tombol kembali
      await tester.tap(find.byIcon(SolarIconsOutline.altArrowLeft));
      await tester.pumpAndSettle();

      expect(backPressed, isTrue);
    });

    testWidgets('Renders subtitle and action buttons without horizontal collision', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: MekaarTopBar(
              title: 'Detail Guardian Terpercaya',
              subtitle: 'Pengaturan izin darurat real-time',
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
            body: const SizedBox(),
          ),
        ),
      );

      expect(find.text('Detail Guardian Terpercaya'), findsOneWidget);
      expect(find.text('Pengaturan izin darurat real-time'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Verifikasi preferredSize dengan subtitle
      final topBarFinder = find.byType(MekaarTopBar);
      final MekaarTopBar topBar = tester.widget(topBarFinder);
      expect(topBar.preferredSize.height, equals(136.0));
    });

    testWidgets('SettingsTopBar inherits from MekaarTopBar and works seamlessly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: SettingsTopBar(
              title: 'Pengaturan Privasi Lanjutan',
              subtitle: 'Kelola vault dan keamanan',
            ),
            body: SizedBox(),
          ),
        ),
      );

      expect(find.byType(SettingsTopBar), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is MekaarTopBar), findsOneWidget);
      expect(find.text('Pengaturan Privasi Lanjutan'), findsOneWidget);
      expect(find.text('Kelola vault dan keamanan'), findsOneWidget);
    });

    testWidgets('SafeArea applies top padding correctly when status bar padding exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 48.0),
            ),
            child: Scaffold(
              appBar: MekaarTopBar(
                title: 'Layar dengan Status Bar',
                onBack: () {},
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );

      final backBtnFinder = find.byIcon(SolarIconsOutline.altArrowLeft);
      expect(backBtnFinder, findsOneWidget);

      final backBtnTop = tester.getTopLeft(backBtnFinder).dy;
      // Top position tombol kembali harus >= 48.0 (karena SafeArea status bar)
      expect(backBtnTop, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Clamped text scaling prevents layout overflow with large accessibility fonts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              appBar: MekaarTopBar(
                title: 'Judul Panjang Sekali Untuk Menguji Ketahanan Layout Aksesibilitas',
                subtitle: 'Sub-judul deskripsi pelengkap',
              ),
              body: SizedBox(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Judul Panjang Sekali Untuk Menguji Ketahanan Layout Aksesibilitas'), findsOneWidget);
      expect(find.text('Sub-judul deskripsi pelengkap'), findsOneWidget);
    });
  });
}
