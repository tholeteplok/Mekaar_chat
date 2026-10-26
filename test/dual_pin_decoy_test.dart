import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';
import 'package:mekaar_chat/data/services/local_message_database.dart';

class FakeDualPinAuthRepository extends Fake implements AuthRepository {
  String primaryPin;
  String? duressPin;
  String? decoyPin;
  String lastSavedUnlockMode = 'master';

  FakeDualPinAuthRepository({
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
  Future<void> saveDuressUnlockStatus(bool status) async {
    lastSavedUnlockMode = status ? 'duress' : 'master';
  }

  @override
  Future<DateTime> getServerTime() async => DateTime.now();

  @override
  Future<void> savePinLockout(int attempts, DateTime? lockedUntil) async {}

  @override
  Future<void> setPIN(String pin) async {
    primaryPin = pin;
  }

  @override
  Future<void> setDuressPIN(String pin) async {
    duressPin = pin;
  }

  @override
  Future<void> setDecoyPIN(String pin) async {
    decoyPin = pin;
  }

  @override
  Future<bool> isDuressEnabled() async => duressPin != null && duressPin!.isNotEmpty;

  @override
  Future<bool> isDecoyEnabled() async => decoyPin != null && decoyPin!.isNotEmpty;

  @override
  Future<void> disableDuressPIN() async {
    duressPin = null;
  }

  @override
  Future<void> disableDecoyPIN() async {
    decoyPin = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Arsitektur 3-Slot PIN (Master, Guest/Decoy, Duress)', () {
    late ProviderContainer container;
    late FakeDualPinAuthRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeDualPinAuthRepository(
        primaryPin: '111111',
        decoyPin: '222222',
        duressPin: '999999',
      );
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Validasi Master PIN membuka AuthUnlockMode.master (Normal, Non-Decoy, Non-Duress)', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('111111');

      expect(result, isTrue);
      final state = container.read(authProvider);
      expect(state.unlockMode, equals(AuthUnlockMode.master));
      expect(state.isDecoyActive, isFalse);
      expect(state.lastUnlockWasDuress, isFalse);
      expect(fakeRepo.lastSavedUnlockMode, equals('master'));
    });

    test('2. Validasi Guest/Decoy PIN membuka AuthUnlockMode.decoy (Decoy Aktif, Tanpa SOS)', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('222222');

      expect(result, isTrue);
      final state = container.read(authProvider);
      expect(state.unlockMode, equals(AuthUnlockMode.decoy));
      expect(state.isDecoyActive, isTrue);
      expect(state.lastUnlockWasDuress, isFalse); // Jaminan: Tanpa SOS!
      expect(fakeRepo.lastSavedUnlockMode, equals('decoy'));
    });

    test('3. Validasi Duress PIN membuka AuthUnlockMode.duress (Decoy Aktif + Memicu Silent SOS)', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('999999');

      expect(result, isTrue);
      final state = container.read(authProvider);
      expect(state.unlockMode, equals(AuthUnlockMode.duress));
      expect(state.isDecoyActive, isTrue);
      expect(state.lastUnlockWasDuress, isTrue); // Memicu Silent SOS
      expect(fakeRepo.lastSavedUnlockMode, equals('duress'));
    });

    test('4. allowDecoy: false menolak Decoy PIN (mis. proteksi aksi sensitif di dalam sheet)', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('222222', allowDecoy: false);

      expect(result, isFalse);
    });

    test('5. allowDuress: false menolak Duress PIN (mis. saat de-eskalasi SOS)', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('999999', allowDuress: false);

      expect(result, isFalse);
    });

    test('6. Pencegahan bentrok PIN (Collision Prevention antar-slot PIN)', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Decoy PIN tidak boleh sama dengan Master PIN
      expect(
        () => authNotifier.setupDecoyPIN('111111'),
        throwsA(isA<Exception>()),
      );

      // Decoy PIN tidak boleh sama dengan Duress PIN
      expect(
        () => authNotifier.setupDecoyPIN('999999'),
        throwsA(isA<Exception>()),
      );

      // Duress PIN tidak boleh sama dengan Master PIN
      expect(
        () => authNotifier.setupDuressPIN('111111'),
        throwsA(isA<Exception>()),
      );

      // Duress PIN tidak boleh sama dengan Decoy PIN
      expect(
        () => authNotifier.setupDuressPIN('222222'),
        throwsA(isA<Exception>()),
      );
    });

    test('7. LocalMessageDatabase beralih mode decoy dan master dengan benar', () async {
      final db = LocalMessageDatabase.instance;

      await db.switchMode(isDecoy: true);
      expect(db.isDecoy, isTrue);

      await db.switchMode(isDecoy: false);
      expect(db.isDecoy, isFalse);
    });
  });
}
