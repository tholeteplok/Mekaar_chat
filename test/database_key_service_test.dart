import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/database_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('DatabaseKeyService Cryptographic Tests', () {
    test('deriveVaultKey produces distinct keys for master vs duress with same PIN', () async {
      const pin = '123456';

      final masterKey = await DatabaseKeyService.instance.deriveVaultKey(
        pin,
        isDuress: false,
      );
      final duressKey = await DatabaseKeyService.instance.deriveVaultKey(
        pin,
        isDuress: true,
      );

      expect(masterKey, isNotEmpty);
      expect(duressKey, isNotEmpty);
      expect(masterKey.length, equals(64)); // 32 bytes hex encoded = 64 chars
      expect(duressKey.length, equals(64));
      // Master dan Duress WAJIB menghasilkan kunci yang berbeda untuk isolasi data total
      expect(masterKey, isNot(equals(duressKey)));
    });

    test('deriveVaultKey is deterministic for identical PIN and mode', () async {
      const pin = '654321';

      final key1 = await DatabaseKeyService.instance.deriveVaultKey(pin, isDuress: false);
      final key2 = await DatabaseKeyService.instance.deriveVaultKey(pin, isDuress: false);

      expect(key1, equals(key2));
    });

    test('activeVaultKey state management sets and clears runtime key', () {
      DatabaseKeyService.instance.setActiveVaultKey('mock-key-abc', isDuress: false);
      expect(DatabaseKeyService.instance.activeVaultKey, equals('mock-key-abc'));
      expect(DatabaseKeyService.instance.isVaultDuress, isFalse);

      DatabaseKeyService.instance.setActiveVaultKey('mock-decoy-xyz', isDuress: true);
      expect(DatabaseKeyService.instance.activeVaultKey, equals('mock-decoy-xyz'));
      expect(DatabaseKeyService.instance.isVaultDuress, isTrue);

      DatabaseKeyService.instance.lockVault();
      expect(DatabaseKeyService.instance.activeVaultKey, isNull);
      expect(DatabaseKeyService.instance.isVaultDuress, isFalse);
    });

    test('shredFile overwrites and deletes file and companion WAL/SHM files', () async {
      final tempDir = Directory.systemTemp.createTempSync('shred_test_');
      final dbFile = File('${tempDir.path}/test_legacy.db');
      final walFile = File('${tempDir.path}/test_legacy.db-wal');
      final shmFile = File('${tempDir.path}/test_legacy.db-shm');

      await dbFile.writeAsString('SENSITIVE_PLAINTEXT_CHAT_DATA_FOR_AUDIT');
      await walFile.writeAsString('SENSITIVE_WAL_TRANSACTION_LOG');
      await shmFile.writeAsString('SENSITIVE_SHM_SHARED_MEMORY');

      expect(await dbFile.exists(), isTrue);
      expect(await walFile.exists(), isTrue);
      expect(await shmFile.exists(), isTrue);

      await DatabaseKeyService.instance.shredFile(dbFile);

      expect(await dbFile.exists(), isFalse);
      expect(await walFile.exists(), isFalse);
      expect(await shmFile.exists(), isFalse);

      tempDir.deleteSync(recursive: true);
    });
  });
}
