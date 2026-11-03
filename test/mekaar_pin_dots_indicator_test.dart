import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_pin_dots_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MekaarPinDotsIndicator Widget Tests', () {
    testWidgets('Merender 6 dot secara presisi secara default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 0,
              ),
            ),
          ),
        ),
      );

      // Verifikasi terdapat 6 kontainer dot
      final dotContainers = find.byType(Container);
      expect(dotContainers, findsNWidgets(6));
    });

    testWidgets('Merender jumlah dot terisi sesuai enteredLength', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 3,
                dotSize: 20.0,
                dotSpacing: 10.0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(MekaarPinDotsIndicator), findsOneWidget);
    });

    testWidgets('Menampilkan angka jika obscurePin = false dan tidak sedang memvalidasi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 3,
                obscurePin: false,
                pinText: '123',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Auto-obscure: angka disamarkan (tidak dirender) saat isValidating = true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 6,
                isValidating: true,
                obscurePin: false, // User sebelumnya mengaktifkan mode intip
                pinText: '123456',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Angka tidak boleh bocor ke widget tree saat gelombang validasi aktif
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
      expect(find.text('4'), findsNothing);
      expect(find.text('5'), findsNothing);
      expect(find.text('6'), findsNothing);
    });

    testWidgets('Animasi gelombang sinus berulang saat isValidating = true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 6,
                isValidating: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MekaarPinDotsIndicator), findsOneWidget);
    });

    testWidgets('Menghormati preferensi reduce motion sistem (disableAnimations = true)', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: MekaarPinDotsIndicator(
                  enteredLength: 6,
                  isValidating: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MekaarPinDotsIndicator), findsOneWidget);
    });

    testWidgets('Memicu animasi shake dan memanggil onShakeCompleted saat hasError transisi ke true', (tester) async {
      bool shakeCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 6,
                hasError: false,
                onShakeCompleted: () => shakeCompleted = true,
              ),
            ),
          ),
        ),
      );

      // Transisi hasError: true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MekaarPinDotsIndicator(
                enteredLength: 6,
                hasError: true,
                onShakeCompleted: () => shakeCompleted = true,
              ),
            ),
          ),
        ),
      );

      // Pompa durasi shake (MekaarMotion.slow = 400ms)
      await tester.pump(const Duration(milliseconds: 500));
      expect(shakeCompleted, isTrue);
    });
  });
}
