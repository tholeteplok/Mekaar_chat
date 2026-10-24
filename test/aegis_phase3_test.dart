import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/constants/webrtc_config.dart';
import 'package:mekaar_chat/data/services/aegis_safety_signature_service.dart';
import 'package:mekaar_chat/features/settings/providers/privacy_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
}
