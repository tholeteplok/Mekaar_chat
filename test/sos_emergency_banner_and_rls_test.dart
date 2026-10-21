import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/constants/colors.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/sos/widgets/emergency_active_banner.dart';

class MockSOSRepository extends Fake implements SOSRepository {
  @override
  Future<SOSSession?> getActiveSOS() async => null;
}

class FakeSOSNotifier extends SOSNotifier {
  FakeSOSNotifier([SOSState? initial]) : super(MockSOSRepository()) {
    if (initial != null) state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Migration 95 RLS Verification Tests', () {
    test('File migrasi 95 tersedia dan memuat kebijakan RLS untuk Guardian', () {
      final file = File('supabase/migrations/95_fix_sos_sessions_guardian_rls.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 95 must exist');

      final content = file.readAsStringSync();
      expect(
        content.contains('Guardians can view assigned active SOS sessions'),
        isTrue,
        reason: 'Policy name for guardians must exist',
      );
      expect(
        content.contains('EXISTS'),
        isTrue,
        reason: 'Policy must use EXISTS clause on guardians table',
      );
      expect(
        content.contains('g.owner_id = sos_sessions.user_id'),
        isTrue,
        reason: 'Policy must link owner_id with sos_sessions.user_id',
      );
      expect(
        content.contains('g.guardian_id = auth.uid()'),
        isTrue,
        reason: 'Policy must link guardian_id with authenticated user',
      );
      expect(
        content.contains("g.status = 'active'"),
        isTrue,
        reason: 'Policy must require guardian status to be active',
      );
    });
  });

  group('EmergencyActiveBanner Widget Tests', () {
    testWidgets('Tidak menampilkan banner saat status SOS idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(SOSState(status: SOSStatus.idle)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EmergencyActiveBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Mode Darurat SOS Aktif'), findsNothing);
      expect(find.text('SOS Tertunda Offline'), findsNothing);
    });

    testWidgets('Menampilkan banner saat status SOS aktif dengan tombol BUKAN MERAH', (tester) async {
      final fakeSession = SOSSession(
        id: 'test-session-123',
        userId: 'victim-456',
        status: 'active',
        startedAt: DateTime.now(),
        createdAt: DateTime.now(),
        gpsEnabled: true,
        micEnabled: true,
        videoEnabled: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                SOSState(
                  status: SOSStatus.active,
                  activeSession: fakeSession,
                  isGpsStreaming: true,
                  isAudioStreaming: true,
                  isVideoStreaming: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EmergencyActiveBanner(),
            ),
          ),
        ),
      );

      // Verifikasi Teks Header & Subtitle
      expect(find.text('Mode Darurat SOS Aktif'), findsOneWidget);
      expect(find.text('GPS Aktif • Audio Merekam'), findsOneWidget);

      // Verifikasi Tombol Buka & Akhiri
      expect(find.text('Buka'), findsOneWidget);
      expect(find.text('Akhiri'), findsOneWidget);

      // Verifikasi bahwa tombol Akhiri TIDAK BERWARNA MERAH (Background Putih Solid)
      final akhiriTextFinder = find.text('Akhiri');
      expect(akhiriTextFinder, findsOneWidget);

      // Cari Container pembungkus tombol Akhiri
      final containerFinder = find.ancestor(
        of: akhiriTextFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final containerWidget = tester.widget<Container>(containerFinder.first);
      final decoration = containerWidget.decoration as BoxDecoration?;
      expect(decoration?.color, equals(Colors.white));
      expect(decoration?.color != MekaarColors.sosRed, isTrue);
    });

    testWidgets('Menampilkan banner saat status SOS queuedOffline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                SOSState(
                  status: SOSStatus.queuedOffline,
                  message: 'SOS tersimpan di perangkat',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EmergencyActiveBanner(),
            ),
          ),
        ),
      );

      expect(find.text('SOS Tertunda Offline'), findsOneWidget);
      expect(find.text('Menunggu sinyal untuk dikirim ke server'), findsOneWidget);
      expect(find.text('Buka'), findsOneWidget);
      expect(find.text('Akhiri'), findsOneWidget);
    });
  });
}
