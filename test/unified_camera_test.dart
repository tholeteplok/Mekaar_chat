import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/features/chat/screens/unified_camera_screen.dart';
import 'package:mekaar_chat/features/chat/widgets/chat_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraCaptureResult Model Tests', () {
    test('Memverifikasi model CameraCaptureResult untuk foto', () {
      final file = File('/tmp/photo.jpg');
      final result = CameraCaptureResult(
        file: file,
        isVideo: false,
      );

      expect(result.file.path, '/tmp/photo.jpg');
      expect(result.isVideo, isFalse);
      expect(result.duration, isNull);
    });

    test('Memverifikasi model CameraCaptureResult untuk video', () {
      final file = File('/tmp/video.mp4');
      const duration = Duration(seconds: 12);
      final result = CameraCaptureResult(
        file: file,
        isVideo: true,
        duration: duration,
      );

      expect(result.file.path, '/tmp/video.mp4');
      expect(result.isVideo, isTrue);
      expect(result.duration, duration);
    });
  });

  group('UnifiedCameraScreen Widget Tests', () {
    testWidgets('Menampilkan pesan ramah jika tidak ada kamera yang tersedia', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnifiedCameraScreen(
            initialCameras: [],
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Tidak ada sensor kamera yang terdeteksi di perangkat ini.'),
        findsOneWidget,
      );
      expect(find.text('Kembali'), findsOneWidget);
    });

    testWidgets('Menampilkan tombol Kembali yang menutup layar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const UnifiedCameraScreen(
                      initialCameras: [],
                    ),
                  ),
                );
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Kembali'), findsOneWidget);

      await tester.tap(find.text('Kembali'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Buka'), findsOneWidget);
    });

    testWidgets('ChatComposer attachment sheet menampilkan label "Buka Kamera"', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChatComposer(
                  controller: controller,
                  focusNode: focusNode,
                  replyMessage: null,
                  onCancelReply: () {},
                  enabled: true,
                  canSend: true,
                  onSend: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Cari tombol lampiran (paperclip)
      final paperclipBtn = find.byIcon(SolarIconsOutline.paperclip);
      expect(paperclipBtn, findsOneWidget);

      await tester.tap(paperclipBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifikasi label "Buka Kamera" muncul (bukan lagi "Ambil Foto / Video")
      expect(find.text('Buka Kamera'), findsOneWidget);
      expect(find.text('Ambil Foto / Video'), findsNothing);

      controller.dispose();
      focusNode.dispose();
    });
  });
}
