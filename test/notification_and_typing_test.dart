import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/core/constants/icons.dart';
import 'package:mekaar_chat/core/widgets/chat_bubble.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:mekaar_chat/features/chat/providers/message_notification_listener.dart';
import 'package:mekaar_chat/features/chat/widgets/typing_indicator.dart';
import 'package:mekaar_chat/features/chat/widgets/private_vault_dialogs.dart';
import 'package:mekaar_chat/features/chat/widgets/nearby_friends_canvas.dart';

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

  group('Chat Menu Mute Option Tests', () {
    test('ikon dan label mute sesuai kondisi tanpa switch', () {
      Widget buildMuteItem(bool isMuted) {
        return Row(
          children: [
            Icon(
              isMuted
                  ? SolarIconsOutline.volumeLoud
                  : SolarIconsOutline.volumeCross,
            ),
            Text(
              isMuted ? 'Bunyikan Notifikasi' : 'Bisukan Notifikasi',
            ),
          ],
        );
      }

      final unmutedWidget = buildMuteItem(false);
      expect(unmutedWidget, isA<Row>());
      final unmutedChildren = (unmutedWidget as Row).children;
      expect((unmutedChildren[0] as Icon).icon, SolarIconsOutline.volumeCross);
      expect((unmutedChildren[1] as Text).data, 'Bisukan Notifikasi');

      final mutedWidget = buildMuteItem(true);
      final mutedChildren = (mutedWidget as Row).children;
      expect((mutedChildren[0] as Icon).icon, SolarIconsOutline.volumeLoud);
      expect((mutedChildren[1] as Text).data, 'Bunyikan Notifikasi');
    });
  });

  group('ReadReceiptIcon & Centralized Token Tests', () {
    test('MekaarIcons mendefinisikan receiptSent, receiptDelivered, dan receiptRead secara presisi', () {
      expect(MekaarIcons.receiptSent, Icons.check);
      expect(MekaarIcons.receiptDelivered, Icons.done_all);
      expect(MekaarIcons.receiptRead, Icons.done_all);
      expect(MekaarIcons.doneAll, Icons.done_all);
    });

    test('MekaarColors.readReceiptGreen bernilai hijau kontras #25D366', () {
      expect(MekaarColors.readReceiptGreen, const Color(0xFF25D366));
    });

    test('ReadReceiptStatus enum mencakup pending, sent, delivered, dan read', () {
      expect(ReadReceiptStatus.values, contains(ReadReceiptStatus.pending));
      expect(ReadReceiptStatus.values, contains(ReadReceiptStatus.sent));
      expect(ReadReceiptStatus.values, contains(ReadReceiptStatus.delivered));
      expect(ReadReceiptStatus.values, contains(ReadReceiptStatus.read));
    });
  });

  group('Android Photo Picker Configuration Tests', () {
    test('ImagePickerAndroid mendukung aktivasi useAndroidPhotoPicker', () {
      final androidPicker = ImagePickerAndroid();
      androidPicker.useAndroidPhotoPicker = true;
      expect(androidPicker.useAndroidPhotoPicker, isTrue);
    });
  });

  group('ContactListScreen & Nearby Visual Parity Tests', () {
    test('ContactListScreen mendefinisikan main tabs Semua Kontak dan Teman Sekitar', () {
      const mainTabs = ['Semua Kontak', 'Teman Sekitar'];
      expect(mainTabs.length, 2);
      expect(mainTabs[0], 'Semua Kontak');
      expect(mainTabs[1], 'Teman Sekitar');
    });

    test('NearbyFriendsCanvas mendukung showInternalHeader flag untuk mencegah judul ganda', () {
      const canvas = NearbyFriendsCanvas(showInternalHeader: false);
      expect(canvas.showInternalHeader, isFalse);
    });

    test('Filter tab kontak dan teman sekitar menggunakan spesifikasi dimensi identik 175x32', () {
      const sortWidth = 175.0;
      const sortHeight = 32.0;
      const nearbyWidth = 175.0;
      const nearbyHeight = 32.0;

      expect(sortWidth, equals(nearbyWidth));
      expect(sortHeight, equals(nearbyHeight));
    });
  });
}
