import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_chat/data/repositories/auth_repository.dart';
import 'package:mekaar_chat/features/auth/providers/auth_provider.dart';

class FakeAuthRepository extends Fake implements AuthRepository {
  final String primaryPin;
  final String duressPin;

  FakeAuthRepository({
    this.primaryPin = '111111',
    this.duressPin = '999999',
  });

  @override
  Future<bool> validatePIN(String pin) async => pin == primaryPin;

  @override
  Future<bool> validateDuressPIN(String pin) async => pin == duressPin;

  @override
  Future<void> clearPinLockout() async {}

  @override
  Future<void> saveDuressUnlockStatus(bool status) async {}

  @override
  Future<DateTime> getServerTime() async => DateTime.now();

  @override
  Future<void> savePinLockout(int attempts, DateTime? lockedUntil) async {}
}

void main() {
  group('P0-4: Strict Rejection Duress PIN saat Deaktivasi SOS', () {
    late ProviderContainer container;
    late FakeAuthRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAuthRepository(primaryPin: '123456', duressPin: '654321');
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('allowDuress: true menerima Duress PIN dan menandai lastUnlockWasDuress', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('654321', allowDuress: true);

      expect(result, isTrue);
      expect(container.read(authProvider).lastUnlockWasDuress, isTrue);
    });

    test('allowDuress: true menerima Primary PIN dan lastUnlockWasDuress bernilai false', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('123456', allowDuress: true);

      expect(result, isTrue);
      expect(container.read(authProvider).lastUnlockWasDuress, isFalse);
    });

    test('allowDuress: false (mode SOS) strictly menolak Duress PIN', () async {
      final authNotifier = container.read(authProvider.notifier);

      // Korban dipaksa memasukkan Duress PIN saat mematikan SOS
      final result = await authNotifier.validatePIN('654321', allowDuress: false);

      expect(result, isFalse, reason: 'Duress PIN dilarang mematikan sesi darurat SOS');
      expect(container.read(authProvider).lastUnlockWasDuress, isFalse);
    });

    test('allowDuress: false (mode SOS) tetap menerima Primary PIN asli', () async {
      final authNotifier = container.read(authProvider.notifier);

      final result = await authNotifier.validatePIN('123456', allowDuress: false);

      expect(result, isTrue, reason: 'Hanya PIN Utama asli yang dapat menonaktifkan SOS');
      expect(container.read(authProvider).lastUnlockWasDuress, isFalse);
    });
  });
}
