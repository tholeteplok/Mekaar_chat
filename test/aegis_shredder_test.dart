import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/aegis_shredder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AegisShredderService Unit Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mekaar_shred_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('shredFile returns false when target file does not exist', () async {
      final nonExistentPath = '${tempDir.path}/non_existent_file_xyz.bin';
      final result = await AegisShredderService.instance.shredFile(nonExistentPath);
      expect(result, isFalse);
    });

    test('shredFile permanently shreds empty file', () async {
      final file = File('${tempDir.path}/empty.bin');
      await file.writeAsBytes(const []);
      expect(await file.exists(), isTrue);

      final result = await AegisShredderService.instance.shredFile(file.path);
      expect(result, isTrue);
      expect(await file.exists(), isFalse);
    });

    test('shredFile permanently shreds and deletes populated 128KB payload file', () async {
      final file = File('${tempDir.path}/secret_128k.bin');
      final secretBytes = Uint8List(128 * 1024);
      for (int i = 0; i < secretBytes.length; i++) {
        secretBytes[i] = i % 256;
      }
      await file.writeAsBytes(secretBytes, flush: true);

      expect(await file.exists(), isTrue);
      expect(await file.length(), equals(128 * 1024));

      final result = await AegisShredderService.instance.shredFile(file.path);
      expect(result, isTrue);
      expect(await file.exists(), isFalse);
    });

    test('shredDirectoryContents recursively shreds all files and cleans up', () async {
      final f1 = File('${tempDir.path}/sub1.bin');
      final f2 = File('${tempDir.path}/sub2.bin');
      await f1.writeAsString('sensitif 1');
      await f2.writeAsString('sensitif 2');

      final subDir = Directory('${tempDir.path}/nested');
      await subDir.create();
      final f3 = File('${subDir.path}/sub3.bin');
      await f3.writeAsString('sensitif 3');

      final shreddedCount =
          await AegisShredderService.instance.shredDirectoryContents(tempDir.path);

      expect(shreddedCount, equals(3));
      expect(await f1.exists(), isFalse);
      expect(await f2.exists(), isFalse);
      expect(await f3.exists(), isFalse);
    });

    test('shredFile wipes and unlinks cancelled audio recording mock file', () async {
      final voiceFile = File('${tempDir.path}/cancelled_record.m4a');
      await voiceFile.writeAsString('voice raw audio bytes header and samples');
      expect(await voiceFile.exists(), isTrue);

      final result = await AegisShredderService.instance.shredFile(voiceFile.path);
      expect(result, isTrue);
      expect(await voiceFile.exists(), isFalse);
    });

    test('shredFile wipes and unlinks view-once temporary image cache', () async {
      final imgFile = File('${tempDir.path}/view_once_temp.jpg');
      await imgFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
      expect(await imgFile.exists(), isTrue);

      final result = await AegisShredderService.instance.shredFile(imgFile.path);
      expect(result, isTrue);
      expect(await imgFile.exists(), isFalse);
    });

    test('shredFile wipes and unlinks deleted vault item', () async {
      final vaultDoc = File('${tempDir.path}/vault_confidential.pdf');
      await vaultDoc.writeAsString('%PDF-1.4 sensitive financial statement');
      expect(await vaultDoc.exists(), isTrue);

      final result = await AegisShredderService.instance.shredFile(vaultDoc.path);
      expect(result, isTrue);
      expect(await vaultDoc.exists(), isFalse);
    });
  });
}
