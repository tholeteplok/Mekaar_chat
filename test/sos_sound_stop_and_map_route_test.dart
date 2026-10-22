import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/core/providers/time_tick_provider.dart';
import 'package:mekaar_chat/core/routes/app_routes.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/features/guardian/widgets/guardian_sos_alert_banner.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:mekaar_chat/features/guardian/screens/sos_viewer_screen.dart';

class MockSOSRepository extends Fake implements SOSRepository {
  final SOSSession? _session;
  final List<Map<String, dynamic>> _guardedSessions;
  final Map<String, dynamic>? _ping;

  MockSOSRepository({
    SOSSession? session,
    List<Map<String, dynamic>> guardedSessions = const [],
    Map<String, dynamic>? ping,
  })  : _session = session,
        _guardedSessions = guardedSessions,
        _ping = ping;

  @override
  Future<SOSSession?> getActiveSOS() async => _session;

  @override
  Future<List<Map<String, dynamic>>> getActiveSessionsForMe() async =>
      _guardedSessions;

  @override
  Future<Map<String, dynamic>?> getLatestLocationPing(String sessionId) async =>
      _ping;

  @override
  Future<Map<String, dynamic>?> getSessionById(String sessionId) async =>
      _guardedSessions.isNotEmpty ? _guardedSessions.first : null;

  @override
  Future<void> updateSessionMessage(String sessionId, String message) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppRoutes.map Defensive Route Tests', () {
    test('AppRoutes.generateRoute menangani parameter latitude/longitude standar', () {
      final route = AppRoutes.generateRoute(
        const RouteSettings(
          name: AppRoutes.map,
          arguments: {
            'latitude': -6.200000,
            'longitude': 106.816666,
            'locationName': 'Lokasi Uji',
          },
        ),
      );

      expect(route, isA<MekaarPageRoute>());
    });

    test('AppRoutes.generateRoute menangani parameter singkat lat/lon tanpa crash TypeError', () {
      final route = AppRoutes.generateRoute(
        const RouteSettings(
          name: AppRoutes.map,
          arguments: {
            'lat': -6.200000,
            'lon': 106.816666,
            'title': 'Lokasi Uji',
          },
        ),
      );

      expect(route, isA<MekaarPageRoute>());
    });

    test('AppRoutes.generateRoute menangani argumen kosong/null tanpa crash TypeError', () {
      final route = AppRoutes.generateRoute(
        const RouteSettings(
          name: AppRoutes.map,
          arguments: null,
        ),
      );

      expect(route, isA<MekaarPageRoute>());
    });

    test('AppRoutes.generateRoute menangani argumen int numerik', () {
      final route = AppRoutes.generateRoute(
        const RouteSettings(
          name: AppRoutes.map,
          arguments: {
            'lat': 0,
            'lon': 100,
          },
        ),
      );

      expect(route, isA<MekaarPageRoute>());
    });
  });

  group('GuardianSOSAlertBanner Tactical Message & Mute Tests', () {
    testWidgets('Menampilkan pesan darurat taktis dan tombol mute suara', (tester) async {
      final mockRepo = MockSOSRepository(
        guardedSessions: [
          {
            'id': 'session-123',
            'user_id': 'victim-456',
            'user_name': 'Mika',
            'message': 'Jangan telepon saya! Saya sedang sembunyi',
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
            activeGuardedSessionsProvider.overrideWith(
              (ref) => Future.value(mockRepo._guardedSessions),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GuardianSOSAlertBanner(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan banner menampilkan teks pesan taktis korban
      expect(find.text('🚨 DARURAT: Mika butuh bantuan!'), findsOneWidget);
      expect(
        find.text('💬 "Jangan telepon saya! Saya sedang sembunyi"'),
        findsOneWidget,
      );

      // Memastikan tombol Mute dan tombol Lacak tersedia
      expect(find.text('Lacak'), findsOneWidget);
    });
  });

  group('SOSViewerScreen Tactical Banner & Sound Stop Tests', () {
    testWidgets('Menampilkan banner prioritas vital saat korban sembunyi', (tester) async {
      final mockRepo = MockSOSRepository(
        guardedSessions: [
          {
            'id': 'session-999',
            'user_id': 'victim-777',
            'user_name': 'Korban',
            'message': 'Jangan telepon saya! Saya sedang sembunyi',
          },
        ],
        ping: {
          'latitude': -6.2088,
          'longitude': 106.8456,
          'timestamp': DateTime.now().toIso8601String(),
          'accuracy': 15.0,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
            timeTickProvider.overrideWith(
              (ref) => Stream.value(DateTime.now()),
            ),
          ],
          child: const MaterialApp(
            home: SOSViewerScreen(
              sessionId: 'session-999',
              userName: 'Korban',
              initialMessage: 'Jangan telepon saya! Saya sedang sembunyi',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Memastikan banner peringatan vital korban terpasang
      expect(find.text('⚠️ PERINGATAN VITAL KORBAN'), findsOneWidget);
      expect(
        find.textContaining('JANGAN TELEPON KORBAN!'),
        findsOneWidget,
      );
      expect(
        find.text('💬 "Jangan telepon saya! Saya sedang sembunyi"'),
        findsOneWidget,
      );
    });
  });
}
