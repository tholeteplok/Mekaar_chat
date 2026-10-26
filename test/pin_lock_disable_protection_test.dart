import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';

class FakeAuthRepoForPinProtection extends Fake implements AuthRepository {
  String primaryPin;
  String? duressPin;
  String? decoyPin;
  String lastSavedUnlockMode = 'master';

  FakeAuthRepoForPinProtection({
    this.primaryPin = '111111',
    this.duressPin = '999999',
    this.decoyPin = '888888',
  });

  @override
  Future<bool> validatePIN(String pin) async => pin == primaryPin;

  @override
  Future<bool> validateDuressPIN(String pin) async => pin == duressPin;

  @override
  Future<bool> validateDecoyPIN(String pin) async => pin == decoyPin;

  @override
  Future<void> clearPinLockout() async {}

  @override
  Future<void> saveUnlockMode(String mode) async {
    lastSavedUnlockMode = mode;
  }

  @override
  Future<DateTime> getServerTime() async => DateTime.now();

  @override
  Future<void> savePinLockout(int attempts, DateTime? lockedUntil) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinLockEnabledNotifier Defense-in-Depth Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'is_pin_lock_enabled': true});
    });

    test('toggle(false, isDecoySession: false) pada sesi Master berhasil menonaktifkan PIN', () async {
      final notifier = PinLockEnabledNotifier();
      await notifier.initialized;
      expect(notifier.state, isTrue);

      await notifier.toggle(false, isDecoySession: false);
      expect(notifier.state, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PinLockEnabledNotifier.preferenceKey), isFalse);
    });

    test('toggle(false, isDecoySession: true) pada sesi Decoy/Duress DITOLAK KERAS dan melempar StateError', () async {
      final notifier = PinLockEnabledNotifier();
      await notifier.initialized;
      expect(notifier.state, isTrue);

      expect(
        () => notifier.toggle(false, isDecoySession: true),
        throwsA(isA<StateError>()),
      );

      // State di RAM dan di disk WAJIB tetap bernilai true
      expect(notifier.state, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PinLockEnabledNotifier.preferenceKey), isTrue);
    });

    test('toggle(true) dapat mengaktifkan kembali kunci PIN', () async {
      SharedPreferences.setMockInitialValues({'is_pin_lock_enabled': false});
      final notifier = PinLockEnabledNotifier();
      await notifier.initialized;
      expect(notifier.state, isFalse);

      await notifier.toggle(true, isDecoySession: false);
      expect(notifier.state, isTrue);
    });
  });

  group('AuthNotifier Decoy/Duress State Integrity on PIN Failure Tests', () {
    late FakeAuthRepoForPinProtection fakeRepo;
    late AuthNotifier authNotifier;

    setUp(() {
      fakeRepo = FakeAuthRepoForPinProtection();
      authNotifier = AuthNotifier(fakeRepo);
    });

    test('Salah input PIN saat dalam sesi Decoy TIDAK me-reset unlockMode ke master', () async {
      // 1. Masuk via Decoy PIN
      final decoyResult = await authNotifier.validatePIN('888888');
      expect(decoyResult, isTrue);
      expect(authNotifier.state.unlockMode, equals(AuthUnlockMode.decoy));
      expect(authNotifier.state.isDecoyActive, isTrue);

      // 2. Simulasi percobaan verifikasi PIN yang salah di dalam aplikasi
      final failedResult = await authNotifier.validatePIN('000000', allowDecoy: false, allowDuress: false);
      expect(failedResult, isFalse);

      // 3. Verifikasi: unlockMode WAJIB tetap decoy, BUKAN di-overwrite ke master!
      expect(authNotifier.state.unlockMode, equals(AuthUnlockMode.decoy));
      expect(authNotifier.state.isDecoyActive, isTrue);
    });

    test('Salah input PIN saat dalam sesi Duress TIDAK me-reset unlockMode ke master', () async {
      // 1. Masuk via Duress PIN
      final duressResult = await authNotifier.validatePIN('999999');
      expect(duressResult, isTrue);
      expect(authNotifier.state.unlockMode, equals(AuthUnlockMode.duress));
      expect(authNotifier.state.isDecoyActive, isTrue);

      // 2. Simulasi percobaan verifikasi PIN yang salah
      final failedResult = await authNotifier.validatePIN('000000', allowDecoy: false, allowDuress: false);
      expect(failedResult, isFalse);

      // 3. Verifikasi: unlockMode WAJIB tetap duress!
      expect(authNotifier.state.unlockMode, equals(AuthUnlockMode.duress));
      expect(authNotifier.state.isDecoyActive, isTrue);
    });

    test('allowDecoy: false dan allowDuress: false MENOLAK PIN Tamu & Duress (Hanya PIN Master Sah)', () async {
      // PIN Tamu ditolak saat allowDecoy: false
      final decoyTry = await authNotifier.validatePIN('888888', allowDecoy: false, allowDuress: false);
      expect(decoyTry, isFalse);

      // PIN Duress ditolak saat allowDuress: false
      final duressTry = await authNotifier.validatePIN('999999', allowDecoy: false, allowDuress: false);
      expect(duressTry, isFalse);

      // PIN Master diterima
      final masterTry = await authNotifier.validatePIN('111111', allowDecoy: false, allowDuress: false);
      expect(masterTry, isTrue);
      expect(authNotifier.state.unlockMode, equals(AuthUnlockMode.master));
    });
  });
}
