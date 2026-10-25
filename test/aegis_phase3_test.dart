import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/webrtc_config.dart';
import 'package:mekaar_chat/data/models/sos_session_model.dart';
import 'package:mekaar_chat/data/repositories/sos_repository.dart';
import 'package:mekaar_chat/data/services/aegis_memory_guard_service.dart';
import 'package:mekaar_chat/data/services/aegis_safety_signature_service.dart';
import 'package:mekaar_chat/features/guardian/screens/guardian_tracking_screen.dart';
import 'package:mekaar_chat/features/guardian/screens/sos_viewer_screen.dart';
import 'package:mekaar_chat/features/settings/providers/privacy_provider.dart';
import 'package:mekaar_chat/features/sos/providers/sos_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPhase3SOSRepository extends Fake implements SOSRepository {
  final SOSSession? _session;
  final List<Map<String, dynamic>> _guardedSessions;
  final Map<String, dynamic>? _ping;

  MockPhase3SOSRepository({
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

  group('WebRtcConfig Anti-IP Leak Tests', () {
    test('buildIceConfiguration default uses standard peer-to-peer / stun candidates', () {
      final config = WebRtcConfig.buildIceConfiguration();
      expect(config.containsKey('iceServers'), isTrue);
      expect(config['sdpSemantics'], equals('unified-plan'));
      expect(config.containsKey('iceTransportPolicy'), isFalse);
    });

    test('buildIceConfiguration with relayOnly: true enforces relay transport policy', () {
      final config = WebRtcConfig.buildIceConfiguration(relayOnly: true);
      expect(config['iceTransportPolicy'], equals('relay'));
      expect(config['sdpSemantics'], equals('unified-plan'));
    });
  });

  group('RelayCallsOnlyNotifier Tests', () {
    test('initial state defaults to false and toggles correctly with SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = RelayCallsOnlyNotifier(prefs);
      expect(notifier.state, isFalse);

      await notifier.toggle();
      expect(notifier.state, isTrue);
      expect(prefs.getBool(RelayCallsOnlyNotifier.key), isTrue);

      await notifier.setEnabled(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool(RelayCallsOnlyNotifier.key), isFalse);
    });
  });

  group('AegisSafetySignatureService Tests', () {
    final service = AegisSafetySignatureService.instance;

    test('buildCanonicalPayload constructs correct canonical format', () {
      final testDate = DateTime.utc(2026, 10, 24, 14, 0, 0);
      final payload = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'user-alpha',
        timestamp: testDate,
        latitude: -6.2087634,
        longitude: 106.845599,
        emergencyType: 'medical_emergency',
      );

      expect(
        payload,
        equals('MEKAAR_SOS_V1:user-alpha:2026-10-24T14:00:00.000Z:-6.208763:106.845599:medical_emergency'),
      );
    });

    test('generates keypair, signs SOS packet, and verifies successfully', () async {
      final keyPair = await service.generateKeyPair();
      expect(keyPair.keySlotId, isNotNull);
      expect(keyPair.publicKeyB64.isNotEmpty, isTrue);

      final payload = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-123',
        timestamp: DateTime.utc(2026, 10, 24, 15, 30, 0),
        latitude: -7.257472,
        longitude: 112.752088,
        emergencyType: 'panic_button',
      );

      final signature = await service.signPayload(
        canonicalPayload: payload,
        keySlotId: keyPair.keySlotId,
      );

      expect(signature.isNotEmpty, isTrue);

      // Verifikasi sah
      final isValid = await service.verifySignature(
        canonicalPayload: payload,
        signatureB64: signature,
        publicKeyB64: keyPair.publicKeyB64,
      );

      expect(isValid, isTrue);
    });

    test('tampering with payload or coordinates invalidates signature', () async {
      final keyPair = await service.generateKeyPair();

      final originalPayload = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-456',
        timestamp: DateTime.utc(2026, 10, 24, 16, 0, 0),
        latitude: -6.175392,
        longitude: 106.827153,
        emergencyType: 'stalking',
      );

      final signature = await service.signPayload(
        canonicalPayload: originalPayload,
        keySlotId: keyPair.keySlotId,
      );

      // Penyerang mencoba memalsukan koordinat di paket yang ditransmisikan
      final tamperedPayload = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-456',
        timestamp: DateTime.utc(2026, 10, 24, 16, 0, 0),
        latitude: -6.175999, // Dimanipulasi
        longitude: 106.827153,
        emergencyType: 'stalking',
      );

      final isTamperedValid = await service.verifySignature(
        canonicalPayload: tamperedPayload,
        signatureB64: signature,
        publicKeyB64: keyPair.publicKeyB64,
      );

      expect(isTamperedValid, isFalse);
    });

    test('wrong public key or corrupted signature fails verification', () async {
      final keyPair1 = await service.generateKeyPair();
      final keyPair2 = await service.generateKeyPair();

      final payload = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-789',
        timestamp: DateTime.utc(2026, 10, 24, 17, 0, 0),
        latitude: -6.917464,
        longitude: 107.619123,
        emergencyType: 'harassment',
      );

      final signature = await service.signPayload(
        canonicalPayload: payload,
        keySlotId: keyPair1.keySlotId,
      );

      // Verifikasi menggunakan public key milik orang lain
      final wrongKeyValid = await service.verifySignature(
        canonicalPayload: payload,
        signatureB64: signature,
        publicKeyB64: keyPair2.publicKeyB64,
      );
      expect(wrongKeyValid, isFalse);

      // Verifikasi dengan signature rusak
      final corruptValid = await service.verifySignature(
        canonicalPayload: payload,
        signatureB64: 'bm90LWEtdmFsaWQtc2lnbmF0dXJlLWJhc2U2NA==',
        publicKeyB64: keyPair1.publicKeyB64,
      );
      expect(corruptValid, isFalse);
    });

    test('zeroizeKey removes private key from memory guard slot', () async {
      final keyPair = await service.generateKeyPair();
      final slotId = keyPair.keySlotId;

      await AegisMemoryGuardService.instance.zeroizeKey(slotId);

      // Setelah di-zeroize, pemanggilan sign harus melempar error
      final payload = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-000',
        timestamp: DateTime.now().toUtc(),
        latitude: -6.0,
        longitude: 106.0,
        emergencyType: 'sos',
      );

      expect(
        () async => await service.signPayload(
          canonicalPayload: payload,
          keySlotId: slotId,
        ),
        throwsA(anything),
      );
    });
  });

  group('SOSViewerScreen Aegis Safety Signature Tests', () {
    testWidgets('Menampilkan badge Terverifikasi Ed25519 saat signature valid', (tester) async {
      final keyPair = await AegisSafetySignatureService.instance.generateKeyPair();
      final now = DateTime.utc(2026, 10, 25, 12, 0, 0);
      final canonical = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-valid',
        timestamp: now,
        latitude: -6.200000,
        longitude: 106.800000,
        emergencyType: 'sos',
      );
      final sig = await AegisSafetySignatureService.instance.signPayload(
        canonicalPayload: canonical,
        keySlotId: keyPair.keySlotId,
      );

      final mockRepo = MockPhase3SOSRepository(
        guardedSessions: [
          {
            'id': 'session-sig-1',
            'user_id': 'victim-valid',
            'user_name': 'Korban Valid',
          },
        ],
        ping: {
          'latitude': -6.200000,
          'longitude': 106.800000,
          'timestamp': now.toIso8601String(),
          'accuracy': 10.0,
          'signature': sig,
          'public_key': keyPair.publicKeyB64,
          'canonical_payload': canonical,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: SOSViewerScreen(
              sessionId: 'session-sig-1',
              userId: 'victim-valid',
              userName: 'Korban Valid',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🛡️ Terverifikasi Ed25519'), findsOneWidget);
      expect(find.text('Ed25519 Terverifikasi'), findsOneWidget);
    });

    testWidgets('Menampilkan badge Indikasi Spoofing saat signature tidak cocok', (tester) async {
      final keyPair = await AegisSafetySignatureService.instance.generateKeyPair();
      final now = DateTime.utc(2026, 10, 25, 12, 0, 0);
      final originalCanonical = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-tampered',
        timestamp: now,
        latitude: -6.200000,
        longitude: 106.800000,
        emergencyType: 'sos',
      );
      final sig = await AegisSafetySignatureService.instance.signPayload(
        canonicalPayload: originalCanonical,
        keySlotId: keyPair.keySlotId,
      );

      // Skenario manipulasi: koordinat ditamper di network/server
      final tamperedCanonical = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'victim-tampered',
        timestamp: now,
        latitude: -6.999999, // Dimanipulasi
        longitude: 106.800000,
        emergencyType: 'sos',
      );

      final mockRepo = MockPhase3SOSRepository(
        guardedSessions: [
          {
            'id': 'session-sig-2',
            'user_id': 'victim-tampered',
            'user_name': 'Korban Spoofed',
          },
        ],
        ping: {
          'latitude': -6.999999,
          'longitude': 106.800000,
          'timestamp': now.toIso8601String(),
          'accuracy': 10.0,
          'signature': sig,
          'public_key': keyPair.publicKeyB64,
          'canonical_payload': tamperedCanonical,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: SOSViewerScreen(
              sessionId: 'session-sig-2',
              userId: 'victim-tampered',
              userName: 'Korban Spoofed',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('⚠️ Indikasi Spoofing'), findsOneWidget);
      expect(find.text('Peringatan: Tanda Tangan Tidak Sah'), findsOneWidget);
    });

    testWidgets('Menampilkan badge Telemetri Standar saat ping tidak memiliki signature', (tester) async {
      final mockRepo = MockPhase3SOSRepository(
        guardedSessions: [
          {
            'id': 'session-legacy',
            'user_id': 'victim-legacy',
            'user_name': 'Korban Legacy',
          },
        ],
        ping: {
          'latitude': -6.123456,
          'longitude': 106.654321,
          'timestamp': DateTime.now().toIso8601String(),
          'accuracy': 20.0,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: SOSViewerScreen(
              sessionId: 'session-legacy',
              userId: 'victim-legacy',
              userName: 'Korban Legacy',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ℹ️ Telemetri Standar'), findsOneWidget);
    });
  });

  group('GuardianTrackingScreen Aegis Safety Signature Tests', () {
    testWidgets('Menampilkan badge Terverifikasi Ed25519 pada kartu sesi yang sah', (tester) async {
      final keyPair = await AegisSafetySignatureService.instance.generateKeyPair();
      final now = DateTime.utc(2026, 10, 25, 12, 0, 0);
      final canonical = AegisSafetySignatureService.buildCanonicalPayload(
        senderId: 'owner-1',
        timestamp: now,
        latitude: -6.200000,
        longitude: 106.800000,
        emergencyType: 'sos',
      );
      final sig = await AegisSafetySignatureService.instance.signPayload(
        canonicalPayload: canonical,
        keySlotId: keyPair.keySlotId,
      );

      final mockRepo = MockPhase3SOSRepository(
        guardedSessions: [
          {
            'id': 'sess-track-1',
            'user_id': 'owner-1',
            'user_name': 'Owner Sah',
            'user_email': 'owner@test.id',
          },
        ],
        ping: {
          'latitude': -6.200000,
          'longitude': 106.800000,
          'timestamp': now.toIso8601String(),
          'accuracy': 5.0,
          'signature': sig,
          'public_key': keyPair.publicKeyB64,
          'canonical_payload': canonical,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: GuardianTrackingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('🛡️ Terverifikasi Ed25519'), findsOneWidget);
      expect(find.text('Ed25519 Terverifikasi'), findsOneWidget);
    });
  });
}
