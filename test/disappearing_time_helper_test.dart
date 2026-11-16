import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/utils/disappearing_time_helper.dart';
import 'package:mekaar_chat/features/chat/widgets/custom_disappearing_picker_sheet.dart';

void main() {
  group('DisappearingTimeHelper Unit Tests', () {
    test('1. toMinutes menghitung konversi dari menit, jam, dan hari secara presisi', () {
      expect(const DisappearingDuration(15, DisappearingUnit.minute).toMinutes(), 15);
      expect(const DisappearingDuration(30, DisappearingUnit.minute).toMinutes(), 30);
      expect(const DisappearingDuration(1, DisappearingUnit.hour).toMinutes(), 60);
      expect(const DisappearingDuration(2, DisappearingUnit.hour).toMinutes(), 120);
      expect(const DisappearingDuration(1, DisappearingUnit.day).toMinutes(), 1440);
      expect(const DisappearingDuration(3, DisappearingUnit.day).toMinutes(), 4320);
      expect(const DisappearingDuration(7, DisappearingUnit.day).toMinutes(), 10080);
      expect(const DisappearingDuration(0, DisappearingUnit.day).toMinutes(), 0);
      expect(const DisappearingDuration(-5, DisappearingUnit.hour).toMinutes(), 0);
    });

    test('2. fromMinutes memetakan kembali nilai menit ke angka dan satuan paling manusiawi', () {
      expect(DisappearingDuration.fromMinutes(0).value, 0);
      expect(DisappearingDuration.fromMinutes(15).value, 15);
      expect(DisappearingDuration.fromMinutes(15).unit, DisappearingUnit.minute);

      expect(DisappearingDuration.fromMinutes(60).value, 1);
      expect(DisappearingDuration.fromMinutes(60).unit, DisappearingUnit.hour);

      expect(DisappearingDuration.fromMinutes(120).value, 2);
      expect(DisappearingDuration.fromMinutes(120).unit, DisappearingUnit.hour);

      expect(DisappearingDuration.fromMinutes(1440).value, 1);
      expect(DisappearingDuration.fromMinutes(1440).unit, DisappearingUnit.day);

      expect(DisappearingDuration.fromMinutes(4320).value, 3);
      expect(DisappearingDuration.fromMinutes(4320).unit, DisappearingUnit.day);

      expect(DisappearingDuration.fromMinutes(10080).value, 7);
      expect(DisappearingDuration.fromMinutes(10080).unit, DisappearingUnit.day);
    });

    test('3. format menghasilkan label cerdas (Mati, Menit, Jam, Hari)', () {
      expect(DisappearingTimeHelper.format(0), 'Mati');
      expect(DisappearingTimeHelper.format(-10), 'Mati');
      expect(DisappearingTimeHelper.format(5), '5 Menit');
      expect(DisappearingTimeHelper.format(30), '30 Menit');
      expect(DisappearingTimeHelper.format(60), '1 Jam');
      expect(DisappearingTimeHelper.format(120), '2 Jam');
      expect(DisappearingTimeHelper.format(1440), '1 Hari');
      expect(DisappearingTimeHelper.format(4320), '3 Hari');
      expect(DisappearingTimeHelper.format(10080), '7 Hari');
      expect(DisappearingTimeHelper.format(43200), '30 Hari');
    });

    test('4. clampValue menjaga nilai dalam rentang wajar', () {
      expect(DisappearingTimeHelper.clampValue(0, DisappearingUnit.minute), 1);
      expect(DisappearingTimeHelper.clampValue(2000, DisappearingUnit.minute), 1440);
      expect(DisappearingTimeHelper.clampValue(15, DisappearingUnit.minute), 15);

      expect(DisappearingTimeHelper.clampValue(0, DisappearingUnit.hour), 1);
      expect(DisappearingTimeHelper.clampValue(1000, DisappearingUnit.hour), 720);

      expect(DisappearingTimeHelper.clampValue(0, DisappearingUnit.day), 1);
      expect(DisappearingTimeHelper.clampValue(500, DisappearingUnit.day), 365);
    });

    test('5. quickPresetsFor memberikan daftar chip preset cepat per satuan', () {
      expect(DisappearingTimeHelper.quickPresetsFor(DisappearingUnit.minute), [5, 15, 30, 45]);
      expect(DisappearingTimeHelper.quickPresetsFor(DisappearingUnit.hour), [2, 6, 12, 48]);
      expect(DisappearingTimeHelper.quickPresetsFor(DisappearingUnit.day), [3, 7, 14, 30, 90]);
    });
  });

  group('CustomDisappearingPickerSheet Widget Tests', () {
    testWidgets('Merender picker dengan tab Menit/Jam/Hari dan chip preset', (tester) async {
      int? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await CustomDisappearingPickerSheet.show(
                    context: context,
                    initialMinutes: 15,
                  );
                },
                child: const Text('Buka Picker'),
              ),
            ),
          ),
        ),
      );

      // Buka sheet
      await tester.tap(find.text('Buka Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Kustom Pesan Menghilang'), findsOneWidget);
      expect(find.text('Menit'), findsWidgets);
      expect(find.text('Jam'), findsWidgets);
      expect(find.text('Hari'), findsWidgets);
      expect(find.text('15'), findsOneWidget);

      // Tap chip 30 Menit
      expect(find.text('30 Menit'), findsOneWidget);
      await tester.tap(find.text('30 Menit'));
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);

      // Tap Terapkan Durasi
      await tester.tap(find.text('Terapkan Durasi'));
      await tester.pumpAndSettle();

      expect(selectedResult, 30);
    });

    testWidgets('Ganti tab ke Hari dan pilih chip 7 Hari', (tester) async {
      int? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await CustomDisappearingPickerSheet.show(
                    context: context,
                    initialMinutes: 0,
                  );
                },
                child: const Text('Buka Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Picker'));
      await tester.pumpAndSettle();

      // Tap tab 'Hari'
      await tester.tap(find.text('Hari').first);
      await tester.pumpAndSettle();

      // Pilih chip 7 Hari
      expect(find.text('7 Hari'), findsOneWidget);
      await tester.tap(find.text('7 Hari'));
      await tester.pumpAndSettle();

      // Tap Terapkan Durasi
      await tester.tap(find.text('Terapkan Durasi'));
      await tester.pumpAndSettle();

      expect(selectedResult, 7 * 1440); // 10080 menit
    });
  });
}
