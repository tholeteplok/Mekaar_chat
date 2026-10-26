import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/constants/typography.dart';
import 'package:mekaar_chat/core/widgets/mekaar_section_header.dart';
import 'package:mekaar_chat/features/settings/widgets/settings_tiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MekaarSectionHeader Centralized Typography & Layout Tests', () {
    testWidgets('MekaarSectionHeader merender title dengan tipografi standar sectionHeader', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const MekaarSectionHeader(title: 'Mode Tema'),
          ),
        ),
      );

      final textFinder = find.text('Mode Tema');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontSize, equals(MekaarTypography.sectionHeader.fontSize));
      expect(textWidget.style?.fontWeight, equals(MekaarTypography.sectionHeader.fontWeight));
      expect(textWidget.style?.letterSpacing, equals(MekaarTypography.sectionHeader.letterSpacing));
    });

    testWidgets('MekaarSectionHeader merender subtitle dan trailing widget dengan proporsional', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MekaarSectionHeader(
              title: 'Preset Tema',
              subtitle: 'Pilih preset tema chat favorit Anda',
              trailing: const Text('Geser & pilih'),
            ),
          ),
        ),
      );

      expect(find.text('Preset Tema'), findsOneWidget);
      expect(find.text('Pilih preset tema chat favorit Anda'), findsOneWidget);
      expect(find.text('Geser & pilih'), findsOneWidget);
    });

    testWidgets('MekaarSectionHeader menghormati titleColor kustom (misal warna bahaya SOS)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const MekaarSectionHeader(
              title: 'Zona Bahaya',
              titleColor: MekaarColors.sosRed,
            ),
          ),
        ),
      );

      final textFinder = find.text('Zona Bahaya');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, equals(MekaarColors.sosRed));
    });

    testWidgets('SettingsSectionHeader mewarisi MekaarSectionHeader tanpa memutus kompatibilitas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SettingsSectionHeader(title: 'Keamanan'),
          ),
        ),
      );

      // Verifikasi widget SettingsSectionHeader merender MekaarSectionHeader di pohon widget
      expect(find.byType(SettingsSectionHeader), findsOneWidget);
      expect(find.byType(MekaarSectionHeader), findsOneWidget);
      expect(find.text('Keamanan'), findsOneWidget);
    });
  });
}
