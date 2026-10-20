import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/features/chat/widgets/typing_indicator.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_dialogs.dart';

void main() {
  group('MessageNotificationListener.formatNotificationBody Tests', () {
    test('format teks biasa', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'text',
          content: 'Halo apa kabar?',
        ),
        'Halo apa kabar?',
      );
    });

    test('format jenis media foto/gambar', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'image',
          content: 'https://storage/image.jpg',
        ),
        '📷 Foto',
      );
    });

    test('format jenis media pesan suara/voice note', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'voice',
          content: 'https://storage/voice.m4a',
        ),
        '🎤 Pesan suara',
      );
    });

    test('format jenis media video', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'video',
          content: 'https://storage/video.mp4',
        ),
        '🎬 Video',
      );
    });

    test('format jenis berkas/dokumen', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'file',
          content: 'laporan.pdf',
        ),
        '📎 Dokumen',
      );
    });

    test('format lokasi', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'location',
          content: '-6.2,106.8',
        ),
        '📍 Lokasi',
      );
    });

    test('format pesan terenkripsi diprioritaskan', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'text',
          content: 'secret',
          isEncrypted: true,
        ),
        '🔒 Pesan terenkripsi',
      );
    });

    test('format stealth preview menyamarkan isi pesan', () {
      expect(
        MessageNotificationListener.formatNotificationBody(
          msgType: 'text',
          content: 'Halo rahasia',
          isStealthPreview: true,
        ),
        '••••••••',
      );
    });
  });

  group('TypingIndicator Widget Tests', () {
    testWidgets('merender 3 titik dengan warna aksen kustom', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(
              dotColor: Colors.teal,
            ),
          ),
        ),
      );

      expect(find.byType(TypingIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Sedang mengetik'), findsOneWidget);

      // Pastikan ada 3 titik Container di dalam Row
      final row = tester.widget<Row>(find.descendant(
        of: find.byType(TypingIndicator),
        matching: find.byType(Row),
      ));
      expect(row.children.length, 3);
    });
  });

  group('PrivateVaultDialogs Tests', () {
    test('showUnlockPasscodeDialog dapat diakses secara statis', () {
      expect(PrivateVaultDialogs.showUnlockPasscodeDialog, isNotNull);
    });
  });
}
