import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/core/storage/mekaar_secure_storage.dart';

void main() {
  group('Cloud Backup Prevention & Keystore Isolation Security Tests', () {
    test('AndroidManifest.xml mematikan seluruh pencadangan Android & ADB', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue,
          reason: 'AndroidManifest.xml harus ada');

      final content = manifestFile.readAsStringSync();

      // 1. allowBackup harus false untuk mematikan Google Drive Auto Backup & ADB
      expect(
        content.contains('android:allowBackup="false"'),
        isTrue,
        reason: 'android:allowBackup harus disetel ke "false"',
      );

      // 2. fullBackupContent harus false untuk mematikan backup legacy Android < 12
      expect(
        content.contains('android:fullBackupContent="false"'),
        isTrue,
        reason: 'android:fullBackupContent harus disetel ke "false"',
      );

      // 3. dataExtractionRules harus merujuk ke data_extraction_rules.xml (Android 12+)
      expect(
        content.contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        isTrue,
        reason:
            'android:dataExtractionRules harus merujuk ke @xml/data_extraction_rules',
      );
    });

    test('data_extraction_rules.xml mematikan cloud-backup & device-transfer', () {
      final rulesFile =
          File('android/app/src/main/res/xml/data_extraction_rules.xml');
      expect(rulesFile.existsSync(), isTrue,
          reason: 'data_extraction_rules.xml harus ada');

      final content = rulesFile.readAsStringSync();

      // Memastikan cloud-backup mengecualikan seluruh domain dan path (".")
      expect(content.contains('<cloud-backup>'), isTrue);
      expect(content.contains('<device-transfer>'), isTrue);
      expect(content.contains('domain="root"'), isTrue);
      expect(content.contains('domain="sharedpref"'), isTrue);
      expect(content.contains('domain="database"'), isTrue);
      expect(content.contains('path="."'), isTrue);
    });

    test('MekaarSecureStorage mengonfigurasi enkripsi Hardware Keystore & iOS device isolation', () {
      final androidMap = MekaarSecureStorage.androidOptions.toMap();
      final iosMap = MekaarSecureStorage.iosOptions.toMap();

      // 1. Android Keystore
      expect(
        androidMap['encryptedSharedPreferences'],
        equals('true'),
        reason:
            'Android harus menggunakan hardware-backed encryptedSharedPreferences',
      );

      // 2. iOS Keychain - first_unlock_this_device mencegah migrasi/backup ke iCloud Keychain & iTunes
      expect(
        iosMap['accessibility'],
        equals('first_unlock_this_device'),
        reason:
            'iOS Keychain harus diisolasi ke perangkat saat ini (first_unlock_this_device)',
      );

      // 3. iOS Keychain synchronizable harus false
      expect(
        iosMap['synchronizable'],
        equals('false'),
        reason: 'iOS Keychain tidak boleh disinkronkan ke iCloud',
      );

      // 4. Instance & Factory valid
      expect(MekaarSecureStorage.instance, isNotNull);
      final newInstance = MekaarSecureStorage.create();
      expect(newInstance, isNotNull);
    });
  });
}
