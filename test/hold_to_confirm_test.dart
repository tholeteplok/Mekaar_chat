import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/core/widgets/sos_button.dart';
import 'package:mekaar_chat/core/widgets/hold_to_confirm_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SOSButton Hold-to-Confirm Widget Tests', () {
    testWidgets('Single tap cepat (< holdDuration) tidak memicu onPressed saat idle', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SOSButton(
                onPressed: () => triggered = true,
                isActive: false,
                holdDuration: const Duration(seconds: 2),
              ),
            ),
          ),
        ),
      );

      // Tap biasa (tap down lalu tap up instan)
      await tester.tap(find.byType(SOSButton));
      await tester.pump(const Duration(milliseconds: 200));

      expect(triggered, isFalse, reason: 'Single tap tidak boleh memicu SOS');
    });

    testWidgets('Tahan selama 2 detik memicu onPressed', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SOSButton(
                onPressed: () => triggered = true,
                isActive: false,
                holdDuration: const Duration(seconds: 2),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
      await tester.pump(const Duration(milliseconds: 100)); // Tap down resolved
      await tester.pump(const Duration(milliseconds: 1000)); // 1s
      expect(triggered, isFalse);

      await tester.pump(const Duration(milliseconds: 1100)); // > 2s
      expect(triggered, isTrue, reason: 'Tahan penuh 2 detik harus memicu SOS');

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Dilepas sebelum 2 detik membatalkan aktivasi SOS', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SOSButton(
                onPressed: () => triggered = true,
                isActive: false,
                holdDuration: const Duration(seconds: 2),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(SOSButton)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1000)); // Tahan 1.1s total (belum 2s)
      await gesture.up(); // Lepas sebelum 2s
      await tester.pump(const Duration(milliseconds: 500));

      expect(triggered, isFalse, reason: 'Dilepas sebelum durasi selesai tidak boleh memicu SOS');
    });

    testWidgets('Saat isActive == true, single-tap langsung memicu onPressed', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SOSButton(
                onPressed: () => triggered = true,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SOSButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(triggered, isTrue, reason: 'Saat aktif, 1-tap harus membuka info/layar status darurat');
    });
  });

  group('HoldToConfirmButton Widget Tests', () {
    testWidgets('Single tap cepat tidak memicu onTrigger', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToConfirmButton(
                label: 'Akhiri SOS',
                duration: const Duration(seconds: 3),
                onTrigger: () => triggered = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(HoldToConfirmButton));
      await tester.pump(const Duration(milliseconds: 200));

      expect(triggered, isFalse);
    });

    testWidgets('Tahan penuh sesuai durasi memicu onTrigger', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToConfirmButton(
                label: 'Akhiri SOS',
                duration: const Duration(seconds: 2),
                onTrigger: () => triggered = true,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
      await tester.pump(const Duration(milliseconds: 100)); // Tap down resolved
      await tester.pump(const Duration(milliseconds: 1000)); // 1s
      expect(triggered, isFalse);

      await tester.pump(const Duration(milliseconds: 1100)); // > 2s
      expect(triggered, isTrue);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Dilepas sebelum durasi selesai membatalkan trigger', (tester) async {
      var triggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldToConfirmButton(
                label: 'Akhiri SOS',
                duration: const Duration(seconds: 3),
                onTrigger: () => triggered = true,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1500)); // Tahan 1.6s dari 3s
      await gesture.up(); // Lepas
      await tester.pump(const Duration(milliseconds: 500));

      expect(triggered, isFalse);
    });
  });
}
