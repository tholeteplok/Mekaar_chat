import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/widgets/mekaar_sliding_segment_bar.dart';
import 'package:mekaar_chat/data/services/update_service.dart';
import 'package:mekaar_chat/features/settings/screens/about_mekaar_screen.dart';

class _FakeUpdateService implements UpdateService {
  @override
  Future<String> getCurrentVersion() async => '3.0.0';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
      ],
      child: const MaterialApp(
        home: AboutMekaarScreen(),
      ),
    );
  }

  group('AboutMekaarScreen Tests', () {
    testWidgets('Merender layar Tentang Mekaar dengan 3 menu konsolidasi utama',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Brand & Version
      expect(find.text('Mekaar'), findsOneWidget);
      expect(find.text('Bicara Bebas, Tetap Aman'), findsOneWidget);
      expect(find.text('Versi 3.0.0'), findsOneWidget);

      // 3 Menu Utama Terpadu (Tanpa duplikasi Filosofi & Fitur)
      expect(find.text('Arsitektur & Pilar Pertahanan'), findsOneWidget);
      expect(find.text('3 pilar keselamatan fisik & privasi data riil'),
          findsOneWidget);

      expect(find.text('Syarat Layanan & Privasi'), findsOneWidget);
      expect(find.text('Perizinan & Hak Akses'), findsOneWidget);
    });

    testWidgets(
        'Membuka bottom sheet Arsitektur & Pilar Pertahanan dan berpindah antar 3 pilar',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap menu 'Arsitektur & Pilar Pertahanan'
      await tester.tap(find.text('Arsitektur & Pilar Pertahanan'));
      await tester.pumpAndSettle();

      // Verifikasi bottom sheet terbuka dan segment bar terpasang
      expect(find.byType(MekaarSlidingSegmentBar), findsOneWidget);
      expect(find.text('Komunikasi'), findsOneWidget);
      expect(find.text('Fisik & SOS'), findsOneWidget);
      expect(find.text('Pertahanan'), findsOneWidget);

      // ── Tab 1: Komunikasi (Data in Motion) ──
      expect(find.text('Pilar 1: Keamanan Komunikasi'), findsOneWidget);
      expect(find.text('Aegis Shield E2EE'), findsOneWidget);
      expect(find.text('Sanitasi Metadata Storage'), findsOneWidget);
      expect(find.text('Notifikasi Senyap & Mandiri (Silent FCM)'),
          findsOneWidget);
      expect(find.text('Anti-IP Leak WebRTC Relay'), findsOneWidget);

      // ── Berpindah ke Tab 2: Fisik & SOS (Human Safety) ──
      await tester.tap(find.text('Fisik & SOS'));
      await tester.pumpAndSettle();

      expect(find.text('Pilar 2: Jaring Keselamatan Fisik'), findsOneWidget);
      expect(find.text('Focused SOS 72px'), findsOneWidget);
      expect(find.text('Guardian Network & Live Eskalasi'), findsOneWidget);
      expect(find.text('Berbagi Lokasi Berbasis Sesi'), findsOneWidget);
      expect(find.text('Ephemeral Salted Radar'), findsOneWidget);

      // ── Berpindah ke Tab 3: Pertahanan (Data at Rest & Duress) ──
      await tester.tap(find.text('Pertahanan'));
      await tester.pumpAndSettle();

      expect(find.text('Pilar 3: Pertahanan di Lapangan'), findsOneWidget);
      expect(
          find.text('Plausible Deniability (Duress PIN)'), findsOneWidget);
      expect(
          find.text('Private Contact Vault Multi-Slot'), findsOneWidget);
      expect(find.text('Pelindung Layar Bidirectional'), findsOneWidget);
      expect(
          find.text('Pemusnahan Jejak & Scheduled Wipe'), findsOneWidget);
    });
  });
}
