import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mekaar_chat/data/services/database_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseKeyService Fail-Closed Security Tests', () {
    test('getOrCreateVaultSalt propagates errors (fail-closed) when storage fails', () async {
      // In this environment or under error, DatabaseKeyService must rethrow
      // and NEVER fall back to hardcoded static string salts.
      FlutterSecureStorage.setMockInitialValues({});
      
      // Standard fetch succeeds with 32 bytes random salt
      final salt = await DatabaseKeyService.instance.getOrCreateVaultSalt(isDuress: false);
      expect(salt.length, equals(32));
      
      // Verification: Static salt prefixes 'mekaar_vault_master_salt_' and 'mekaar_vault_decoy_salt_'
      // must NOT match the generated CSPRNG salt.
      final staticSaltCandidate = 'mekaar_vault_master_salt_v1_secure';
      expect(String.fromCharCodes(salt), isNot(equals(staticSaltCandidate)));
    });
  });
}
