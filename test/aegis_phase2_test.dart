import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekaar_chat/data/services/aegis_memory_guard_service.dart';
import 'package:mekaar_chat/data/services/aegis_stream_cipher_service.dart';

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

        // Ukuran 150 KB (> 2 chunks 64KB)
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

        // Modifikasi 1 byte di payload enkripsi
        final encData = await encryptedFile.readAsBytes();
        encData[encData.length - 5] ^= 0xFF;
        await encryptedFile.writeAsBytes(encData);

        // Dekripsi wajib gagal (throw Exception / AuthenticationError)
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
    });
  });
}
