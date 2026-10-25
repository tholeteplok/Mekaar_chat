import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/models/vault_item.dart';
import 'package:mekaar_chat/data/services/aegis_memory_guard_service.dart';
import 'package:mekaar_chat/data/services/aegis_stream_cipher_service.dart';
import 'package:mekaar_chat/data/services/local_vault_database.dart';
import 'package:mekaar_chat/features/chat/providers/vault_provider.dart';

class FakeVaultDatabase implements LocalVaultDatabase {
  final Map<String, VaultItem> _items = {};

  @override
  Future<void> insertItem(VaultItem item) async {
    _items[item.id] = item;
  }

  @override
  Future<VaultItem?> getItemById(String id) async => _items[id];

  @override
  Future<List<VaultItem>> getItems({VaultFileType? filter, String? query}) async {
    return _items.values.toList();
  }

  @override
  Future<int> deleteItem(String id) async {
    return _items.remove(id) != null ? 1 : 0;
  }

  @override
  Future<int> countItems({VaultFileType? filter}) async => _items.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aegis Phase 2: Memory Guard & Streaming Media Cipher Unit Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mekaar_phase2_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    group('AegisMemoryGuardService', () {
      test('storeKey, hasKey, and zeroizeKey lifecycle', () async {
        final dummyKey = Uint8List(32)..fillRange(0, 32, 0x42);
        final slotId = await AegisMemoryGuardService.instance.storeKey(dummyKey);

        expect(slotId > BigInt.zero, isTrue);
        expect(await AegisMemoryGuardService.instance.hasKey(slotId), isTrue);

        final zeroized = await AegisMemoryGuardService.instance.zeroizeKey(slotId);
        expect(zeroized, isTrue);
        expect(await AegisMemoryGuardService.instance.hasKey(slotId), isFalse);
      });

      test('storeKey rejects invalid key lengths', () async {
        final shortKey = Uint8List(16); // Bukan 32 byte
        expect(
          () => AegisMemoryGuardService.instance.storeKey(shortKey),
          throwsArgumentError,
        );
      });

      test('zeroizeAllKeys wipes all stored slots', () async {
        final k1 = await AegisMemoryGuardService.instance.storeKey(Uint8List(32)..fillRange(0, 32, 1));
        final k2 = await AegisMemoryGuardService.instance.storeKey(Uint8List(32)..fillRange(0, 32, 2));

        expect(await AegisMemoryGuardService.instance.hasKey(k1), isTrue);
        expect(await AegisMemoryGuardService.instance.hasKey(k2), isTrue);

        final wipedCount = await AegisMemoryGuardService.instance.zeroizeAllKeys();
        expect(wipedCount >= 2, isTrue);

        expect(await AegisMemoryGuardService.instance.hasKey(k1), isFalse);
        expect(await AegisMemoryGuardService.instance.hasKey(k2), isFalse);
      });

      test('deriveVaultKey generates valid key slot via Argon2id / KDF', () async {
        final salt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
        final slotId = await AegisMemoryGuardService.instance.deriveVaultKey(
          passcode: '654321',
          salt: salt,
        );

        expect(slotId > BigInt.zero, isTrue);
        expect(await AegisMemoryGuardService.instance.hasKey(slotId), isTrue);

        final zeroized = await AegisMemoryGuardService.instance.zeroizeKey(slotId);
        expect(zeroized, isTrue);
        expect(await AegisMemoryGuardService.instance.hasKey(slotId), isFalse);
      });
    });

    group('AegisStreamCipherService', () {
      test('encrypt and decrypt small file stream with exact recovery', () async {
        final originalFile = File('${tempDir.path}/small_note.txt');
        final encryptedFile = File('${tempDir.path}/small_note.enc');
        final decryptedFile = File('${tempDir.path}/small_note.dec');

        const originalText = 'Ini adalah pesan suara rahasia berdurasi 5 detik!';
        await originalFile.writeAsString(originalText);

        final rawKey = Uint8List(32)..fillRange(0, 32, 0x77);
        final keySlotId = await AegisMemoryGuardService.instance.storeKey(rawKey);

        final encBytes = await AegisStreamCipherService.instance.encryptFileStream(
          srcPath: originalFile.path,
          dstPath: encryptedFile.path,
          keySlotId: keySlotId,
        );
        expect(encBytes > BigInt.from(originalText.length), isTrue);
        expect(await encryptedFile.exists(), isTrue);

        final decBytes = await AegisStreamCipherService.instance.decryptFileStream(
          srcPath: encryptedFile.path,
          dstPath: decryptedFile.path,
          keySlotId: keySlotId,
        );
        expect(decBytes, equals(BigInt.from(originalText.length)));

        final recoveredText = await decryptedFile.readAsString();
        expect(recoveredText, equals(originalText));

        await AegisMemoryGuardService.instance.zeroizeKey(keySlotId);
      });

      test('encrypt and decrypt multi-chunk stream (> 128KB payload)', () async {
        final originalFile = File('${tempDir.path}/multi_chunk.bin');
        final encryptedFile = File('${tempDir.path}/multi_chunk.enc');
        final decryptedFile = File('${tempDir.path}/multi_chunk.dec');

        final payloadSize = 150 * 1024;
        final payload = Uint8List(payloadSize);
        for (int i = 0; i < payload.length; i++) {
          payload[i] = (i % 251);
        }
        await originalFile.writeAsBytes(payload);

        final rawKey = Uint8List(32)..fillRange(0, 32, 0x33);
        final keySlotId = await AegisMemoryGuardService.instance.storeKey(rawKey);

        await AegisStreamCipherService.instance.encryptFileStream(
          srcPath: originalFile.path,
          dstPath: encryptedFile.path,
          keySlotId: keySlotId,
        );

        await AegisStreamCipherService.instance.decryptFileStream(
          srcPath: encryptedFile.path,
          dstPath: decryptedFile.path,
          keySlotId: keySlotId,
        );

        final recoveredBytes = await decryptedFile.readAsBytes();
        expect(recoveredBytes.length, equals(payloadSize));
        expect(recoveredBytes, equals(payload));

        await AegisMemoryGuardService.instance.zeroizeKey(keySlotId);
      });

      test('tampered ciphertext fails MAC verification and rejects decryption', () async {
        final originalFile = File('${tempDir.path}/tamper.bin');
        final encryptedFile = File('${tempDir.path}/tamper.enc');
        final decryptedFile = File('${tempDir.path}/tamper.dec');

        await originalFile.writeAsString('Data penting yang tidak boleh diubah');

        final rawKey = Uint8List(32)..fillRange(0, 32, 0x99);
        final keySlotId = await AegisMemoryGuardService.instance.storeKey(rawKey);

        await AegisStreamCipherService.instance.encryptFileStream(
          srcPath: originalFile.path,
          dstPath: encryptedFile.path,
          keySlotId: keySlotId,
        );

        final encData = await encryptedFile.readAsBytes();
        encData[encData.length - 5] ^= 0xFF;
        await encryptedFile.writeAsBytes(encData);

        expect(
          () => AegisStreamCipherService.instance.decryptFileStream(
            srcPath: encryptedFile.path,
            dstPath: decryptedFile.path,
            keySlotId: keySlotId,
          ),
          throwsA(anything),
        );

        await AegisMemoryGuardService.instance.zeroizeKey(keySlotId);
      });

      test('decryptToTempFile decrypts to sandbox path and cleans up', () async {
        final originalFile = File('${tempDir.path}/test_image.png');
        final encryptedFile = File('${tempDir.path}/test_image.png.aegis');
        await originalFile.writeAsString('PNG_IMAGE_BINARY_DATA_DUMMY_123');

        final rawKey = Uint8List(32)..fillRange(0, 32, 0x88);
        final keySlotId = await AegisMemoryGuardService.instance.storeKey(rawKey);

        await AegisStreamCipherService.instance.encryptFileStream(
          srcPath: originalFile.path,
          dstPath: encryptedFile.path,
          keySlotId: keySlotId,
        );

        final tempDecrypted = await AegisStreamCipherService.instance.decryptToTempFile(
          encryptedPath: encryptedFile.path,
          keySlotId: keySlotId,
          fileExtension: 'png',
        );

        expect(await tempDecrypted.exists(), isTrue);
        expect(await tempDecrypted.readAsString(), equals('PNG_IMAGE_BINARY_DATA_DUMMY_123'));
        expect(tempDecrypted.path.endsWith('.png'), isTrue);

        await AegisMemoryGuardService.instance.zeroizeKey(keySlotId);
        if (await tempDecrypted.exists()) {
          await tempDecrypted.delete();
        }
      });
    });

    group('Aegis Vault Streaming Integration', () {
      test('saveMediaToVault encrypts file to .aegis and getDecryptedMedia recovers original bytes', () async {
        final fakeDb = FakeVaultDatabase();
        final repo = VaultRepository(fakeDb, vaultDir: Directory('${tempDir.path}/vault_files'));

        final rawSource = File('${tempDir.path}/my_document.pdf');
        const documentText = 'PDF_SECRET_DATA_CONFIDENTIAL_123';
        await rawSource.writeAsString(documentText);

        final rawKey = Uint8List(32)..fillRange(0, 32, 0x55);
        final keySlotId = await AegisMemoryGuardService.instance.storeKey(rawKey);

        final item = await repo.saveMediaToVault(
          sourceFile: rawSource,
          originalMessageId: 'msg_vault_101',
          keySlotId: keySlotId,
          deleteSource: true,
        );

        expect(item.localPath.endsWith('.aegis'), isTrue);
        expect(await rawSource.exists(), isFalse); // Berkas sumber mentah musnah secara forensik

        // Periksa berkas fisik di disk: pastikan magic header adalah MKST
        final savedFile = File(item.localPath);
        expect(await savedFile.exists(), isTrue);
        final fileBytes = await savedFile.readAsBytes();
        expect(fileBytes.sublist(0, 4), equals([0x4D, 0x4B, 0x53, 0x54])); // 'MKST'

        // Dekripsi via getDecryptedMedia
        final recoveredFile = await repo.getDecryptedMedia(item, keySlotId: keySlotId);
        expect(await recoveredFile.exists(), isTrue);
        expect(await recoveredFile.readAsString(), equals(documentText));

        // Musnahkan kunci dari memori
        await AegisMemoryGuardService.instance.zeroizeKey(keySlotId);

        // Dekripsi setelah key di-zeroize wajib gagal
        expect(
          () => repo.getDecryptedMedia(item, keySlotId: keySlotId),
          throwsA(anything),
        );

        if (await recoveredFile.exists()) {
          await recoveredFile.delete();
        }
      });
    });
  });
}
