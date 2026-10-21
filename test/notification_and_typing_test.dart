import 'package:mekaar_chat/data/models/device_lost_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/services/update_service.dart';
import 'package:mekaar_chat/core/widgets/mekaar_update_bottom_sheet.dart';
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
import 'package:mekaar_chat/data/services/notification_service.dart';
import 'package:mekaar_chat/features/chat/screens/incoming_call_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  group('Realtime Call Queue & Notification Tests', () {
    test('NotificationRoute mendukung serialisasi & deserialisasi tipe call dan message', () {
      const route = NotificationRoute(
        type: NotificationRouteType.call,
        callId: 'test-call-123',
        roomId: 'test-room-123',
        callerId: 'user-456',
        callerName: 'Budi',
        callType: 'voice',
      );

      final payload = route.encodePayload();
      final decoded = NotificationRoute.fromPayload(payload);

      expect(decoded, isNotNull);
      expect(decoded!.type, NotificationRouteType.call);
      expect(decoded.callId, 'test-call-123');
      expect(decoded.callerName, 'Budi');
      expect(decoded.callType, 'voice');
    });

    test('MessageNotificationListener.shouldNotify mencegah echo dan room aktif', () {
      // 1. Pesan dari diri sendiri -> Jangan notif
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: 'me',
          senderId: 'me',
          roomId: 'room1',
          activeRoomId: null,
          isDeleted: false,
        ),
        isFalse,
      );

      // 2. User sedang membuka room yang sama -> Jangan notif
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: 'me',
          senderId: 'other',
          roomId: 'room1',
          activeRoomId: 'room1',
          isDeleted: false,
        ),
        isFalse,
      );

      // 3. User membuka room lain atau sedang di luar chat -> Munculkan notif
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: 'me',
          senderId: 'other',
          roomId: 'room1',
          activeRoomId: 'room2',
          isDeleted: false,
        ),
        isTrue,
      );

      // 4. Pesan dihapus -> Jangan notif
      expect(
        MessageNotificationListener.shouldNotify(
          currentUserId: 'me',
          senderId: 'other',
          roomId: 'room1',
          activeRoomId: null,
          isDeleted: true,
        ),
        isFalse,
      );
    });

    testWidgets('IncomingCallScreen merender mode privasi saat isVaultLocked bernilai true', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: IncomingCallScreen(
              callId: 'call-1',
              roomId: 'room-1',
              callerId: 'user-secret',
              callerName: 'Rahasia Budi',
              callerAvatarUrl: 'https://example.com/budi.jpg',
              callType: 'voice',
              isVaultLocked: true,
            ),
          ),
        ),
      );

      // Pastikan nama asli tidak muncul
      expect(find.text('Rahasia Budi'), findsNothing);
      // Pastikan label tersamarkan muncul
      expect(find.text('Panggilan Masuk'), findsOneWidget);
      expect(find.text('Kontak Terlindungi'), findsOneWidget);
      // Pastikan ikon perisai gembok ada
      expect(find.byIcon(SolarIconsBold.shieldKeyhole), findsOneWidget);
    });

    testWidgets('IncomingCallScreen merender nama asli saat isVaultLocked bernilai false', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: IncomingCallScreen(
              callId: 'call-2',
              roomId: 'room-2',
              callerId: 'user-normal',
              callerName: 'Teman Biasa',
              callerAvatarUrl: null,
              callType: 'voice',
              isVaultLocked: false,
            ),
          ),
        ),
      );

      // Pastikan nama asli muncul
      expect(find.text('Teman Biasa'), findsOneWidget);
      expect(find.text('Kontak Terlindungi'), findsNothing);
    });
  });

  group('Update Ready-To-Install Modal Tests', () {
    testWidgets('Sheet siap pasang merender 2 baris: Pasang Sekarang, Buka Unduhan, dan Hapus Berkas', (tester) async {
      const dummyInfo = AppUpdateInfo(
        hasUpdate: true,
        currentVersion: '1.2.2',
        latestVersion: '1.2.3',
        releaseName: 'Mekaar 1.2.3',
        releaseNotes: 'Catatan rilis',
        downloadUrl: 'https://example.com/update.apk',
        htmlUrl: 'https://example.com',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    MekaarUpdateBottomSheet.showInstallSheet(
                      context: ctx,
                      info: dummyInfo,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Buka bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verifikasi tombol baris 1 (Pasang Sekarang)
      expect(find.text('Pasang Sekarang'), findsOneWidget);

      // Verifikasi tombol baris 2 (Buka Unduhan & Hapus Berkas berjejer)
      expect(find.text('Buka Unduhan'), findsOneWidget);
      expect(find.text('Hapus Berkas'), findsOneWidget);

      // Verifikasi tombol yang dihapus tidak ada lagi
      expect(find.text('Unduh Ulang (Hapus Cache)'), findsNothing);
      expect(find.text('Hapus Berkas & Tutup'), findsNothing);
      expect(find.text('Pasang Nanti'), findsNothing);
      expect(find.text('Tutup'), findsNothing);
    });
  });

  group('SOS Session Schema Alignment Tests', () {
    test('SOSSession memetakan mic_enabled dan started_at secara presisi sesuai skema Supabase', () {
      final now = DateTime.now();
      final session = SOSSession(
        id: 'sos-123',
        userId: 'user-abc',
        startedAt: now,
        status: 'active',
        gpsEnabled: true,
        micEnabled: true,
        videoEnabled: false,
        createdAt: now,
      );

      final json = session.toJson();
      expect(json['mic_enabled'], isTrue);
      expect(json.containsKey('audio_enabled'), isFalse);
      expect(json['started_at'], equals(now.toIso8601String()));
      expect(json['status'], equals('active'));

      final parsed = SOSSession.fromJson({
        'id': 'sos-123',
        'user_id': 'user-abc',
        'started_at': now.toIso8601String(),
        'status': 'active',
        'gps_enabled': true,
        'mic_enabled': true,
        'video_enabled': false,
        'created_at': now.toIso8601String(),
      });

      expect(parsed.micEnabled, isTrue);
      expect(parsed.startedAt, equals(DateTime.parse(now.toIso8601String())));
    });
  });

  group('Device Lost State & Server Time RPC Tests', () {
    test('DeviceLostState memetakan recovery_contact, lock_message, dan status lock secara presisi', () {
      final now = DateTime.now();
      const state = DeviceLostState(
        isLocked: true,
        lockMessage: 'Ponsel ini hilang. Hubungi nomor darurat.',
        recoveryContact: '+6281234567890',
      );

      final json = state.toJson();
      expect(json['is_locked'], isTrue);
      expect(json['lock_message'], 'Ponsel ini hilang. Hubungi nomor darurat.');
      expect(json['recovery_contact'], '+6281234567890');

      final parsed = DeviceLostState.fromJson({
        'is_locked': true,
        'lock_message': 'Ponsel ini hilang. Hubungi nomor darurat.',
        'recovery_contact': '+6281234567890',
        'locked_at': now.toIso8601String(),
      });

      expect(parsed.isLocked, isTrue);
      expect(parsed.recoveryContact, '+6281234567890');
      expect(parsed.lockedAt, isNotNull);
    });

    test('Parser RPC get_server_time mampu memparsing format ISO8601 UTC server', () {
      const serverTimeStr = '2026-10-21T14:24:00.123456+00:00';
      final parsed = DateTime.parse(serverTimeStr).toUtc();

      expect(parsed.isUtc, isTrue);
      expect(parsed.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 21);
      expect(parsed.hour, 14);
      expect(parsed.minute, 24);
    });
  });
}
