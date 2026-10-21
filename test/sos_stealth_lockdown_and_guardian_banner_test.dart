import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/providers/time_tick_provider.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/guardian/widgets/guardian_sos_alert_banner.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/sos/screens/sos_active_screen.dart';

class MockSOSRepository extends Fake implements SOSRepository {
  final SOSSession? _session;
  final List<Map<String, dynamic>> _guardedSessions;

  MockSOSRepository({
    SOSSession? session,
    List<Map<String, dynamic>> guardedSessions = const [],
  })  : _session = session,
        _guardedSessions = guardedSessions;

  @override
  Future<SOSSession?> getActiveSOS() async => _session;

  @override
  Future<List<Map<String, dynamic>>> getActiveSessionsForMe() async =>
      _guardedSessions;

  @override
  Future<List<String>> getMyActiveGuardians() async => ['guardian-1'];
}

class FakeSOSNotifier extends SOSNotifier {
  FakeSOSNotifier(super.repo, [SOSState? initial]) {
    if (initial != null) state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuardianSOSAlertBanner Widget Tests', () {
    testWidgets('Tidak menampilkan banner jika tidak ada orang yang dijaga dalam SOS',
        (tester) async {
      final mockRepo = MockSOSRepository(guardedSessions: []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeTickProvider.overrideWith((ref) => Stream.value(DateTime.now())),
            sosRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GuardianSOSAlertBanner(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.textContaining('DARURAT:'), findsNothing);
      expect(find.text('Lacak'), findsNothing);
    });

    testWidgets(
        'Menampilkan banner darurat merah saat orang yang dijaga dalam status SOS aktif',
        (tester) async {
      final mockRepo = MockSOSRepository(
        guardedSessions: [
          {
            'id': 'sos-session-999',
            'user_id': 'victim-user-123',
            'user_name': 'Mika Rahmawati',
            'user_email': 'mika@example.com',
            'status': 'active',
          }
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeTickProvider.overrideWith((ref) => Stream.value(DateTime.now())),
            sosRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GuardianSOSAlertBanner(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verifikasi Teks Banner
      expect(find.textContaining('Mika Rahmawati butuh bantuan!'), findsOneWidget);
      expect(find.text('Sesi SOS sedang aktif • Ketuk untuk lacak'), findsOneWidget);
      expect(find.text('Lacak'), findsOneWidget);
    });
  });

  group('SOSActiveScreen Stealth Lockdown & Silent Dispatch Tests', () {
    testWidgets('Memastikan PopScope terkunci (canPop: false) dan ada tombol pesan senyap',
        (tester) async {
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

      final mockRepo = MockSOSRepository(session: fakeSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeTickProvider.overrideWith((ref) => Stream.value(DateTime.now())),
            sosRepositoryProvider.overrideWithValue(mockRepo),
            sosProvider.overrideWith(
              (ref) => FakeSOSNotifier(
                mockRepo,
                SOSState(
                  status: SOSStatus.active,
                  activeSession: fakeSession,
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

      // 1. Verifikasi PopScope terkunci
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
      expect(popScopeWidget.canPop, isFalse,
          reason: 'Aplikasi harus mengunci tombol kembali saat darurat');

      // 2. Verifikasi Indikator Mode Darurat Terkunci di Header
      expect(find.text('MODE DARURAT TERKUNCI'), findsOneWidget);

      // 3. Verifikasi Tombol Kirim Pesan Senyap ke Guardian
      final silentBtnFinder = find.text('Kirim Pesan Senyap ke Guardian');
      expect(silentBtnFinder, findsOneWidget);

      // 4. Verifikasi Tombol Nonaktifkan SOS (Putih Solid, BUKAN MERAH)
      final endBtnFinder = find.text('Nonaktifkan SOS (Perlu PIN)');
      expect(endBtnFinder, findsOneWidget);

      // Ketuk tombol pesan senyap untuk membuka bottom sheet
      await tester.tap(silentBtnFinder);
      await tester.pumpAndSettle();

      // 5. Verifikasi 4 Template Cepat Eksklusif Tersedia
      expect(find.text('Jangan telepon saya! Saya sedang sembunyi'), findsOneWidget);
      expect(find.text('Pelaku membawa senjata'), findsOneWidget);
      expect(find.text('Tolong segera hubungi polisi / bantuan ke lokasi saya'),
          findsOneWidget);
      expect(find.text('Saya dalam bahaya akut, ikuti pergerakan GPS saya'),
          findsOneWidget);

      // 6. Verifikasi TIDAK ADA TextField bebas (Fail-Secure / Anti-Chat Palsu)
      expect(find.byType(TextField), findsNothing,
          reason:
              'Tidak boleh ada input teks bebas agar pelaku tidak dapat memalsukan pesan');

      // Tutup sheet
      Navigator.pop(tester.element(find.text('Jangan telepon saya! Saya sedang sembunyi')));
      await tester.pumpAndSettle();
    });
  });
}
