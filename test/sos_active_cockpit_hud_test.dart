import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/constants/dimensions.dart';
import 'package:mekaar_chat/core/widgets/sos_button.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/guardian_repository.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/sos/screens/sos_active_screen.dart';

class MockSOSRepository extends Fake implements SOSRepository {
  final SOSSession? _session;

  MockSOSRepository({SOSSession? session}) : _session = session;

  @override
  Future<SOSSession?> getActiveSOS() async => _session;

  @override
  Future<List<Map<String, dynamic>>> getActiveSessionsForMe() async => [];

  @override
  Future<List<String>> getMyActiveGuardians() async => ['guardian-1'];
}

class FakeGuardianRepository extends Fake implements GuardianRepository {
  @override
  Future<List<Guardian>> getMyGuardians() async => [];
}

class FakeSOSNotifier extends SOSNotifier {
  FakeSOSNotifier(super.repo, [SOSState? initial]) {
    if (initial != null) state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1-2 & P2: SOSButton Token & Size Alignment Tests', () {
    testWidgets('SOSButton default size mengikuti MekaarSizes.sos = 72.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SOSButton(),
          ),
        ),
      );

      final buttonFinder = find.byType(SOSButton);
      expect(buttonFinder, findsOneWidget);

      final buttonWidget = tester.widget<SOSButton>(buttonFinder);
      expect(buttonWidget.size, MekaarSizes.sos);
      expect(buttonWidget.size, 72.0);
    });
  });

  group('P0-3: SOSActiveScreen Cockpit Telemetry HUD Tests', () {
    testWidgets('Menampilkan Grid 2x2 Telemetry Chips (GPS, Audio, Guardian, Koneksi) dan Timer Live', (tester) async {
      final fakeSession = SOSSession(
        id: 'session-hud-1',
        userId: 'user-hud-1',
        status: 'active',
        startedAt: DateTime.now().subtract(const Duration(minutes: 3, seconds: 25)),
        createdAt: DateTime.now().subtract(const Duration(minutes: 3, seconds: 25)),
        gpsEnabled: true,
        micEnabled: true,
        videoEnabled: false,
      );

      final mockRepo = MockSOSRepository(session: fakeSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
            guardianRepositoryProvider.overrideWithValue(FakeGuardianRepository()),
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                mockRepo,
                SOSState(
                  status: SOSStatus.active,
                  activeSession: fakeSession,
                  isGpsStreaming: true,
                  isAudioStreaming: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: SOSActiveScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verifikasi Timer Durasi Darurat Live
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.textContaining('03:2'), findsOneWidget);

      // 2. Verifikasi 4 Telemetry Chips Cockpit
      expect(find.text('GPS LIVE'), findsOneWidget);
      expect(find.text('AUDIO LIVE'), findsOneWidget);
      expect(find.text('0 GUARDIAN'), findsOneWidget);
      expect(find.text('TERHUBUNG'), findsOneWidget);

      // 3. Verifikasi tombol nonaktifkan dengan PIN tetap ada
      expect(find.text('Nonaktifkan SOS (Perlu PIN)'), findsOneWidget);
    });

    testWidgets('Menampilkan status peringatan GPS DITOLAK saat izin lokasi tidak diberikan', (tester) async {
      final fakeSession = SOSSession(
        id: 'session-hud-2',
        userId: 'user-hud-2',
        status: 'active',
        startedAt: DateTime.now(),
        createdAt: DateTime.now(),
        gpsEnabled: false,
        micEnabled: true,
        videoEnabled: false,
      );

      final mockRepo = MockSOSRepository(session: fakeSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
            guardianRepositoryProvider.overrideWithValue(FakeGuardianRepository()),
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                mockRepo,
                SOSState(
                  status: SOSStatus.active,
                  activeSession: fakeSession,
                  locationPermissionDenied: true,
                  isGpsStreaming: false,
                  isAudioStreaming: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: SOSActiveScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi Chip GPS menampilkan GPS DITOLAK
      expect(find.text('GPS DITOLAK'), findsOneWidget);
      expect(find.text('Izin ditolak'), findsOneWidget);
    });
  });
}
