import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mekaar_chat/core/constants/themes.dart';
import 'package:mekaar_chat/features/chat/widgets/document_send_preview_sheet.dart';
import 'package:mekaar_chat/features/chat/widgets/image_send_preview_sheet.dart';
import 'package:solar_icons/solar_icons.dart';

void main() {
  late Directory tempDir;
  late File sampleImageFile;
  late File sampleDocFile;

  // 1x1 transparent PNG
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('mekaar_preview_test_');
    sampleImageFile = File('${tempDir.path}/sample.png')
      ..writeAsBytesSync(pngBytes);
    sampleDocFile = File('${tempDir.path}/sample.pdf')
      ..writeAsStringSync('dummy pdf');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Regresi InputDecorationTheme pada pratinjau media (Light Mode)', () {
    test('MekaarTheme.borderlessInputDecoration mematikan fill & seluruh border', () {
      final decoration = MekaarTheme.borderlessInputDecoration(
        hintText: 'Uji hint',
      );

      expect(decoration.filled, isFalse);
      expect(decoration.fillColor, Colors.transparent);
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
    });

    testWidgets(
      'ImageSendPreviewSheet di Light Theme tidak bocor fill putih & caption terbaca',
      (tester) async {
        ImageSendResult? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: MekaarTheme.lightTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<ImageSendResult>(
                        MaterialPageRoute(
                          builder: (_) => ImageSendPreviewSheet(
                            imageFile: sampleImageFile,
                          ),
                        ),
                      );
                    },
                    child: const Text('Buka'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        final textField = tester.widget<TextField>(textFieldFinder);
        final decoration = textField.decoration!;
        expect(decoration.filled, isFalse);
        expect(decoration.fillColor, Colors.transparent);
        expect(decoration.border, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        expect(textField.style?.color, Colors.white);
        expect(textField.cursorColor, Colors.white);

        await tester.enterText(textFieldFinder, 'Foto uji tema terang');
        await tester.tap(find.byIcon(SolarIconsBold.plain));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.caption, 'Foto uji tema terang');
      },
    );

    testWidgets(
      'DocumentSendPreviewSheet di Light Theme bebas dari kebocoran fill & border tema',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: MekaarTheme.lightTheme(),
            home: DocumentSendPreviewSheet(
              file: sampleDocFile,
              fileName: 'sample.pdf',
              fileSize: 9,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(find.byType(TextField));
        final decoration = textField.decoration!;
        expect(decoration.filled, isFalse);
        expect(decoration.fillColor, Colors.transparent);
        expect(decoration.border, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
      },
    );
  });
}
