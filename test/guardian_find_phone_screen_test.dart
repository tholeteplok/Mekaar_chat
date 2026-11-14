import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_find_phone_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockGuardian = Guardian(
    id: 'guardian_123',
    ownerId: 'owner_user_id',
    guardianId: 'target_peer_id',
    name: 'Budi Santoso',
    email: 'budi@example.com',
    permissions: {'gps': true, 'mic': true, 'video': true},
    storageOption: 'stream_only',
    status: 'active',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets(
    'GuardianFindPhoneScreen merender full screen app bar, banner, dan form kontrol pemulihan',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: GuardianFindPhoneScreen(
              guardian: mockGuardian,
              targetUserId: 'target_peer_id',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan TopBar merender judul
      expect(find.text('Bantu Temukan Ponsel'), findsOneWidget);

      // Memastikan Banner Edukasi Zero-2FA terpasang
      expect(find.byIcon(SolarIconsOutline.shieldCheck), findsOneWidget);
      expect(
        find.textContaining('Aksi pemulihan dikirim melalui kanal data berprioritas tinggi'),
        findsOneWidget,
      );

      // Memastikan Seksi Sirine Hardware Jarak Jauh
      expect(find.text('Bunyikan Sirine Jarak Jauh'), findsOneWidget);
      expect(find.text('Bunyikan Sirine Sekarang'), findsOneWidget);

      // Memastikan Seksi Kunci Layar & Kontak Pemulihan
      expect(find.text('Kunci Layar & Kontak Pemulihan'), findsOneWidget);
      expect(find.text('Kirim Kunci Layar & Kontak'), findsOneWidget);

      // Memastikan Seksi Titik Lokasi GPS
      expect(find.text('Titik Lokasi GPS Terkini'), findsOneWidget);
      expect(find.text('Minta Koordinat GPS Sekarang'), findsOneWidget);
    },
  );
}
