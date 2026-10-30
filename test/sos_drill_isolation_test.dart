import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/core/widgets/mekaar_banner.dart';
import 'package:mekaar_chat/core/widgets/sos_button.dart';
import 'package:mekaar_chat/data/models/guardian_model.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/guardian_repository.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/guardian/providers/guardian_provider.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_list_screen.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/sos/screens/sos_drill_screen.dart';

class MockSOSRepository extends Fake implements SOSRepository {
  final SOSSession? _session;
  MockSOSRepository({SOSSession? session}) : _session = session;

  @override
  Future<SOSSession?> getActiveSOS() async => _session;

  @override
  Future<List<Map<String, dynamic>>> getActiveSessionsForMe() async => [];

  @override
  Future<List<String>> getMyActiveGuardians() async => [];
}

class FakeGuardianRepository extends Fake implements GuardianRepository {
  final List<Guardian> _guardians;
  FakeGuardianRepository([this._guardians = const []]);

  @override
  Future<List<Guardian>> getMyGuardians() async => _guardians;
}

/// Notifier penjaga yang melempar exception keras jika activateSOS dipanggil
class GuardedSOSNotifier extends SOSNotifier {
  GuardedSOSNotifier(super.repo, [SOSState? initial]) {
    if (initial != null) state = initial;
  }

  @override
  Future<void> activateSOS({
    bool gps = true,
    bool mic = false,
    bool video = false,
  }) async {
    throw StateError(
      'CRITICAL VIOLATION: activateSOS dipanggil selama simulasi latihan!',
    );
  }
}

class FakeGuardiansNotifier extends StateNotifier<List<Guardian>>
    implements GuardiansNotifier {
  FakeGuardiansNotifier(super.state);

  @override
  Future<void> refreshGuardians() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX-13: Arsitektur Isolasi & Zero Network Guard', () {
    test(
      'SosDrillScreen tidak mengimpor service jaringan/GPS/alarm dan tidak ada token activateSOS',
      () {
        final file = File('lib/features/sos/screens/sos_drill_screen.dart');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'File sos_drill_screen.dart harus ada',
        );

        final content = file.readAsStringSync();

        // Penjaga isolasi: larangan mutlak service luar
        final forbiddenImports = [
          'supabase_service.dart',
          'location_service.dart',
          'alarm_service.dart',
          'notification_service.dart',
          'push_notification_service.dart',
          'webrtc',
          'repositories/',
        ];

        for (final forbidden in forbiddenImports) {
          expect(
            content.contains(forbidden),
            isFalse,
            reason:
                'SosDrillScreen terdeteksi mengimpor service luar terlarang: $forbidden',
          );
        }

        // Penjaga pencegahan pemicu SOS nyata: tidak boleh ada pemanggilan activateSOS
        expect(
          content.contains('activateSOS'),
          isFalse,
          reason:
              'SosDrillScreen terdeteksi memanggil metode activateSOS nyata!',
        );
      },
    );
  });

  group('UX-13: Guard Terhadap Sesi SOS Nyata', () {
    testWidgets('SosDrillScreen menolak latihan jika SOS nyata sedang aktif', (
      tester,
    ) async {
      final fakeSession = SOSSession(
        id: 'session-active-1',
        userId: 'user-active-1',
        status: 'active',
        startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        gpsEnabled: true,
        micEnabled: false,
        videoEnabled: false,
      );
      final mockRepo = MockSOSRepository(session: fakeSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
            sosProvider.overrideWith(
              (ref) => GuardedSOSNotifier(
                mockRepo,
                SOSState(status: SOSStatus.active, activeSession: fakeSession),
              ),
            ),
          ],
          child: const MaterialApp(home: SosDrillScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SOS Nyata Sedang Aktif'), findsOneWidget);
      expect(
        find.text(
          'Mode latihan tidak dapat dibuka saat sesi darurat nyata sedang berjalan.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SOSButton), findsNothing);
      expect(find.text('Latih Refleks Darurat Anda'), findsNothing);
    });
  });

  group('UX-13: Alur Penuh Latihan SOS & Persistensi', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'Latihan SOS berjalan dari intro -> hold -> simulate -> summary dan menyimpan timestamp',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockRepo = MockSOSRepository();
        final testGuardian = Guardian(
          id: 'g-1',
          ownerId: 'u-1',
          guardianId: 'u-2',
          name: 'Siti Rahma',
          email: 'siti@example.com',
          permissions: {'gps': true, 'mic': true},
          storageOption: 'cloud',
          status: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sosProvider.overrideWith(
                (ref) => GuardedSOSNotifier(
                  mockRepo,
                  SOSState(status: SOSStatus.idle),
                ),
              ),
              guardianProvider.overrideWith(
                (ref) => FakeGuardiansNotifier([testGuardian]),
              ),
            ],
            child: const MaterialApp(home: SosDrillScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // ── Step 1: Intro ──
        expect(find.byKey(const ValueKey('step_intro')), findsOneWidget);
        expect(find.text('Latih Refleks Darurat Anda'), findsOneWidget);
        expect(find.text('100% Aman & Bebas Risiko'), findsOneWidget);

        // Banner simulasi persisten wajib tampil
        expect(find.byType(MekaarBanner), findsOneWidget);
        expect(find.textContaining('SIMULASI'), findsOneWidget);

        // Tekan 'Mulai Latihan'
        final startBtn = find.text('Mulai Latihan');
        expect(startBtn, findsOneWidget);
        await tester.tap(startBtn);
        await tester.pumpAndSettle();

        // ── Step 2: Hold ──
        expect(find.byKey(const ValueKey('step_hold')), findsOneWidget);
        expect(find.text('Tahan Tombol SOS'), findsOneWidget);
        expect(find.byType(MekaarBanner), findsOneWidget);
        expect(find.textContaining('SIMULASI'), findsOneWidget);

        final sosBtnFinder = find.byType(SOSButton);
        expect(sosBtnFinder, findsOneWidget);

        // Tahan tombol SOS selama 2 detik untuk mengonfirmasi aktivasi simulasi
        final gesture = await tester.startGesture(
          tester.getCenter(sosBtnFinder),
        );
        await tester.pump(
          const Duration(milliseconds: 100),
        ); // Tap down resolved
        await tester.pump(
          const Duration(milliseconds: 2100),
        ); // Penuh 2 detik tercapai
        await gesture.up();
        await tester.pumpAndSettle();

        // ── Step 3: Simulate ──
        expect(find.byKey(const ValueKey('step_simulate')), findsOneWidget);
        expect(find.text('Alur Pengiriman Simulasi'), findsOneWidget);
        expect(find.byType(MekaarBanner), findsOneWidget);
        expect(find.textContaining('SIMULASI'), findsOneWidget);

        // Lanjutkan timer simulasi bertahap
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Tampilan nama guardian pada tahapan
        expect(find.textContaining('Siti Rahma'), findsAtLeastNWidgets(1));
        expect(find.text('Pratinjau Notifikasi Wali'), findsOneWidget);

        // Lanjut ke Rangkuman
        final summaryBtn = find.text('Lanjut ke Rangkuman');
        expect(summaryBtn, findsOneWidget);
        await tester.tap(summaryBtn);
        await tester.pumpAndSettle();

        // ── Step 4: Summary ──
        expect(find.byKey(const ValueKey('step_summary')), findsOneWidget);
        expect(find.text('Latihan SOS Selesai!'), findsOneWidget);
        expect(find.byType(MekaarBanner), findsOneWidget);
        expect(find.textContaining('SIMULASI'), findsOneWidget);

        // Selesaikan latihan
        final finishBtn = find.text('Selesai');
        expect(finishBtn, findsOneWidget);
        await tester.tap(finishBtn);
        await tester.pumpAndSettle();

        // Verifikasi SharedPreferences lokal menyimpan timestamp
        final prefs = await SharedPreferences.getInstance();
        final completedAt = prefs.getString(SosDrillPrefs.completedAtKey);
        expect(completedAt, isNotNull);
        expect(DateTime.tryParse(completedAt!), isNotNull);
      },
    );

    testWidgets(
      'Tombol Ulangi di layar rangkuman mengembalikan alur ke step hold',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockRepo = MockSOSRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sosProvider.overrideWith(
                (ref) => GuardedSOSNotifier(
                  mockRepo,
                  SOSState(status: SOSStatus.idle),
                ),
              ),
              guardianProvider.overrideWith((ref) => FakeGuardiansNotifier([])),
            ],
            child: const MaterialApp(home: SosDrillScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Lompat ke hold
        await tester.tap(find.text('Mulai Latihan'));
        await tester.pumpAndSettle();

        // Tahan 2 detik
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SOSButton)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 2100));
        await gesture.up();
        await tester.pumpAndSettle();

        // Langsung ke summary
        await tester.tap(find.text('Lanjut ke Rangkuman'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('step_summary')), findsOneWidget);

        // Tekan 'Ulangi'
        await tester.tap(find.text('Ulangi'));
        await tester.pumpAndSettle();

        // Kembali ke step hold
        expect(find.byKey(const ValueKey('step_hold')), findsOneWidget);
        expect(find.byType(SOSButton), findsOneWidget);
      },
    );
  });

  group('UX-13: Verifikasi Titik Akses UI & Routing', () {
    test('SettingsScreen memuat tile navigasi Latihan SOS (Simulasi)', () {
      final file = File('lib/features/settings/screens/settings_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('Latihan SOS (Simulasi)'), isTrue);
      expect(content.contains('AppRoutes.sosDrill'), isTrue);
    });

    testWidgets(
      'AppRoutes mendaftarkan rute AppRoutes.sosDrill ke SosDrillScreen',
      (tester) async {
        final mockRepo = MockSOSRepository();
        final route = AppRoutes.generateRoute(
          const RouteSettings(name: AppRoutes.sosDrill),
        );
        expect(route, isNotNull);
        expect(route, isA<MekaarPageRoute>());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sosProvider.overrideWith(
                (ref) => GuardedSOSNotifier(
                  mockRepo,
                  SOSState(status: SOSStatus.idle),
                ),
              ),
              guardianProvider.overrideWith((ref) => FakeGuardiansNotifier([])),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  return (route as PageRouteBuilder).pageBuilder(
                    context,
                    const AlwaysStoppedAnimation(1.0),
                    const AlwaysStoppedAnimation(0.0),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(SosDrillScreen), findsOneWidget);
        expect(find.text('Latihan SOS (Simulasi)'), findsOneWidget);
      },
    );

    testWidgets(
      'GuardianListScreen menampilkan entry point Latihan SOS di empty state dan header',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              guardianProvider.overrideWith((ref) => FakeGuardiansNotifier([])),
              guardianLoadStatusProvider.overrideWith(
                (ref) => GuardianLoadStatus.data,
              ),
            ],
            child: const MaterialApp(home: GuardianListScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Header button
        expect(find.byTooltip('Latihan SOS (Simulasi)'), findsOneWidget);

        // Empty state secondary button
        expect(find.text('Coba Latihan SOS (Simulasi)'), findsOneWidget);
      },
    );
  });
}
